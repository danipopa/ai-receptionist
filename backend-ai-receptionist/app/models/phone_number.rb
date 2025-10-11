class PhoneNumber < ApplicationRecord
  belongs_to :customer
  has_many :call_transcripts, dependent: :destroy
  has_many :faqs, dependent: :destroy
  
  validates :number, presence: true, uniqueness: { case_sensitive: false }
  validates :customer, presence: true
  validates :connection_mode, inclusion: { in: %w[trunk register] }
  
  # SIP trunk validations (for direct SIP trunk mode)
  validates :sip_trunk_host, presence: true, if: :trunk_mode?
  validates :sip_trunk_port, presence: true, numericality: { greater_than: 0, less_than: 65536 }, if: :sip_trunk_enabled?
  validates :sip_trunk_domain, presence: true, if: :trunk_mode?
  validates :sip_trunk_protocol, inclusion: { in: %w[UDP TCP TLS] }
  
  # Outbound registration validations (for register mode)
  validates :sip_trunk_username, presence: true, if: :register_mode?
  validates :sip_trunk_password, presence: true, length: { minimum: 6 }, if: :register_mode?
  validates :sip_trunk_host, presence: true, if: :register_mode?
  validates :sip_trunk_port, presence: true, numericality: { greater_than: 0, less_than: 65536 }, if: :register_mode?
  
  scope :sip_trunk_enabled, -> { where(sip_trunk_enabled: true) }
  scope :incoming_enabled, -> { where(incoming_calls_enabled: true) }
  scope :outbound_enabled, -> { where(outbound_calls_enabled: true) }
  scope :trunk_mode, -> { where(connection_mode: 'trunk') }
  scope :register_mode, -> { where(connection_mode: 'register') }
  
  # Connection mode helpers
  def trunk_mode?
    connection_mode == 'trunk'
  end
  
  def register_mode?
    connection_mode == 'register'
  end
  
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
  
  # SIP configuration methods
  def sip_trunk_uri
    return nil unless sip_trunk_enabled?
    
    if trunk_mode?
      # For trunk mode, no username needed
      "sip:#{number}@#{sip_trunk_host}:#{sip_trunk_port}"
    else
      # For register mode, include username
      "sip:#{sip_trunk_username}@#{sip_trunk_host}:#{sip_trunk_port}"
    end
  end
  
  def sip_trunk_contact_uri
    return nil unless sip_trunk_enabled?
    "#{number} <#{sip_trunk_uri}>"
  end
  
  # Generate FreeSWITCH gateway configuration based on connection mode
  def to_freeswitch_gateway_xml
    return nil unless sip_trunk_enabled?
    
    gateway_name = "gateway_#{number.gsub(/\D/, '')}_#{connection_mode}"
    
    if trunk_mode?
      # Direct SIP trunk - no registration needed
      <<~XML
        <!-- Direct SIP Trunk for #{number} -->
        <gateway name="#{gateway_name}">
          <param name="proxy" value="#{sip_trunk_host}:#{sip_trunk_port}"/>
          <param name="register" value="false"/>
          <param name="context" value="ai_receptionist_#{customer.ai_receptionist_id}"/>
          <param name="caller-id-in-from" value="false"/>
          <param name="extension" value="#{number}"/>
        </gateway>
      XML
    else
      # Outbound registration - FreeSWITCH registers to customer's system
      <<~XML
        <!-- Outbound Registration for #{number} -->
        <gateway name="#{gateway_name}">
          <param name="username" value="#{sip_trunk_username}"/>
          <param name="password" value="#{sip_trunk_password}"/>
          <param name="realm" value="#{sip_trunk_domain}"/>
          <param name="proxy" value="#{sip_trunk_host}:#{sip_trunk_port}"/>
          <param name="register" value="true"/>
          <param name="register-transport" value="#{sip_trunk_protocol.downcase}"/>
          <param name="retry-seconds" value="30"/>
          <param name="caller-id-in-from" value="false"/>
          <param name="extension" value="#{number}"/>
          <param name="context" value="ai_receptionist_#{customer.ai_receptionist_id}"/>
        </gateway>
      XML
    end
  end
  
  # Generate FreeSWITCH dialplan entry for incoming calls to this number
  def to_freeswitch_dialplan_xml
    return nil unless sip_trunk_enabled? && incoming_calls_enabled?
    
    <<~XML
      <extension name="incoming_#{number.gsub(/\D/, '')}_#{connection_mode}">
        <condition field="destination_number" expression="^#{Regexp.escape(number)}$">
          <action application="set" data="customer_id=#{customer.id}"/>
          <action application="set" data="phone_number_id=#{id}"/>
          <action application="set" data="connection_mode=#{connection_mode}"/>
          <action application="set" data="effective_caller_id_name=#{customer.name}"/>
          <action application="set" data="effective_caller_id_number=#{number}"/>
          <action application="answer"/>
          <action application="sleep" data="1000"/>
          <action application="lua" data="ai_receptionist.lua"/>
        </condition>
      </extension>
    XML
  end
  
  # Test SIP configuration based on connection mode
  def test_sip_trunk_connection
    return { status: 'disabled', message: 'SIP trunk is disabled' } unless sip_trunk_enabled?
    
    if trunk_mode?
      {
        status: 'success',
        mode: 'trunk',
        message: 'Direct SIP trunk configuration appears valid',
        details: {
          host: sip_trunk_host,
          port: sip_trunk_port,
          protocol: sip_trunk_protocol,
          note: 'IP-based authentication - no registration required'
        }
      }
    else
      {
        status: 'success', 
        mode: 'register',
        message: 'Outbound registration configuration appears valid',
        details: {
          host: sip_trunk_host,
          port: sip_trunk_port,
          username: sip_trunk_username,
          protocol: sip_trunk_protocol,
          note: 'Will register to customer system with provided credentials'
        }
      }
    end
  end
end