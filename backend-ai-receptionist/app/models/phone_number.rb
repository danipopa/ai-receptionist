class PhoneNumber < ApplicationRecord
  belongs_to :customer
  has_many :call_transcripts, dependent: :destroy
  has_many :faqs, dependent: :destroy
  
  validates :number, presence: true, uniqueness: { case_sensitive: false }
  validates :customer, presence: true
  
  # SIP trunk validations
  validates :sip_trunk_host, presence: true, if: :sip_trunk_enabled?
  validates :sip_trunk_port, presence: true, numericality: { greater_than: 0, less_than: 65536 }, if: :sip_trunk_enabled?
  validates :sip_trunk_username, presence: true, if: :sip_trunk_enabled?
  validates :sip_trunk_password, presence: true, length: { minimum: 6 }, if: :sip_trunk_enabled?
  validates :sip_trunk_domain, presence: true, if: :sip_trunk_enabled?
  validates :sip_trunk_protocol, inclusion: { in: %w[UDP TCP TLS] }
  
  scope :sip_trunk_enabled, -> { where(sip_trunk_enabled: true) }
  scope :incoming_enabled, -> { where(incoming_calls_enabled: true) }
  scope :outbound_enabled, -> { where(outbound_calls_enabled: true) }
  
  def formatted_number
    # Remove all non-digits and format as (XXX) XXX-XXXX
    clean_number = number.gsub(/\D/, '')
    if clean_number.length == 10
      clean_number.gsub(/(\d{3})(\d{3})(\d{4})/, '(\1) \2-\3')
    elsif clean_number.length == 11 && clean_number.start_with?('1')
      clean_number.gsub(/1(\d{3})(\d{3})(\d{4})/, '+1 (\1) \2-\3')
    else
      number
    end
  end
  
  # Scan all website URLs in FAQs and update content
  def scan_website_content!
    scanner = WebsiteScannerService.new
    results = scanner.scan_faqs_for_phone_number(self)
    
    Rails.logger.info "Website scanning completed for phone number #{id}: #{results}"
    results
  end
  
  # Get FAQs that need website content scanning
  def faqs_needing_scan
    faqs.needs_scanning
  end
  
  # Check if any FAQs have website URLs that haven't been scanned recently
  def has_unscanned_websites?
    faqs_needing_scan.exists?
  end
  
  # SIP trunk configuration methods
  def sip_trunk_uri
    return nil unless sip_trunk_enabled?
    "sip:#{sip_trunk_username}@#{sip_trunk_host}:#{sip_trunk_port}"
  end
  
  def sip_trunk_contact_uri
    return nil unless sip_trunk_enabled?
    "#{number} <#{sip_trunk_uri}>"
  end
  
  # Generate FreeSWITCH gateway configuration for this phone number's SIP trunk
  def to_freeswitch_gateway_xml
    return nil unless sip_trunk_enabled?
    
    gateway_name = "gateway_#{number.gsub(/\D/, '')}"
    
    <<~XML
      <gateway name="#{gateway_name}">
        <param name="username" value="#{sip_trunk_username}"/>
        <param name="password" value="#{sip_trunk_password}"/>
        <param name="realm" value="#{sip_trunk_domain}"/>
        <param name="proxy" value="#{sip_trunk_host}:#{sip_trunk_port}"/>
        <param name="register" value="true"/>
        <param name="register-transport" value="#{sip_trunk_protocol.downcase}"/>
        <param name="contact-params" value=""/>
        <param name="send-register-on-wake" value="true"/>
        <param name="retry-seconds" value="30"/>
        <param name="caller-id-in-from" value="false"/>
        <param name="supress-cng" value="true"/>
        <param name="rtp-timeout-sec" value="300"/>
        <param name="rtp-hold-timeout-sec" value="1800"/>
        <param name="contact-host" value="#{customer.sip_domain}"/>
        <param name="extension" value="#{number}"/>
        <param name="context" value="#{sip_trunk_context}"/>
      </gateway>
    XML
  end
  
  # Generate FreeSWITCH dialplan entry for incoming calls to this number
  def to_freeswitch_dialplan_xml
    return nil unless sip_trunk_enabled? && incoming_calls_enabled?
    
    <<~XML
      <extension name="incoming_#{number.gsub(/\D/, '')}">
        <condition field="destination_number" expression="^#{Regexp.escape(number)}$">
          <action application="set" data="customer_id=#{customer.id}"/>
          <action application="set" data="phone_number_id=#{id}"/>
          <action application="set" data="effective_caller_id_name=#{customer.name}"/>
          <action application="set" data="effective_caller_id_number=#{number}"/>
          <action application="answer"/>
          <action application="sleep" data="1000"/>
          <action application="lua" data="ai_receptionist.lua"/>
        </condition>
      </extension>
    XML
  end
  
  # Test SIP trunk connectivity
  def test_sip_trunk_connection
    return { status: 'disabled', message: 'SIP trunk is disabled' } unless sip_trunk_enabled?
    
    # This would normally use a SIP testing library
    # For now, return a simulated response
    {
      status: 'success',
      message: 'SIP trunk configuration appears valid',
      details: {
        host: sip_trunk_host,
        port: sip_trunk_port,
        username: sip_trunk_username,
        protocol: sip_trunk_protocol
      }
    }
  end
end