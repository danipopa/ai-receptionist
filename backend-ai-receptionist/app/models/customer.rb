class Customer < ApplicationRecord
  has_many :phone_numbers, dependent: :destroy
  has_many :call_transcripts, through: :phone_numbers
  
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :sip_username, presence: true, uniqueness: true, format: { with: /\A[a-zA-Z0-9_-]+\z/ }
  validates :sip_password, presence: true, length: { minimum: 8 }
  validates :max_concurrent_calls, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 50 }
  
  before_validation :generate_sip_credentials, on: :create
  
  scope :sip_enabled, -> { where(sip_enabled: true) }
  
  def sip_uri
    "sip:#{sip_username}@#{sip_domain}"
  end
  
  def sip_contact
    "#{name} <#{sip_uri}>"
  end
  
  # Generate FreeSWITCH directory entry for this customer
  def to_freeswitch_directory_xml
    <<~XML
      <user id="#{sip_username}">
        <params>
          <param name="password" value="#{sip_password}"/>
          <param name="dial-string" value="{^^:sip_invite_domain=${dialed_domain}:presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(*/${dialed_user}@${dialed_domain})}"/>
          <param name="max-registrations" value="#{max_concurrent_calls}"/>
        </params>
        <variables>
          <variable name="customer_id" value="#{id}"/>
          <variable name="customer_name" value="#{name}"/>
          <variable name="toll_allow" value="domestic,international,local"/>
          <variable name="accountcode" value="#{sip_username}"/>
          <variable name="user_context" value="ai_receptionist"/>
          <variable name="effective_caller_id_name" value="#{name}"/>
          <variable name="effective_caller_id_number" value="#{phone_numbers.first&.number}"/>
        </variables>
      </user>
    XML
  end
  
  private
  
  def generate_sip_credentials
    return if sip_username.present?
    
    # Generate unique SIP username based on company name
    base_username = name.downcase.gsub(/[^a-zA-Z0-9]/, '').first(10)
    self.sip_username = generate_unique_username(base_username)
    
    # Generate secure random password
    self.sip_password = SecureRandom.alphanumeric(16)
  end
  
  def generate_unique_username(base)
    username = base
    counter = 1
    
    while Customer.exists?(sip_username: username)
      username = "#{base}#{counter}"
      counter += 1
    end
    
    username
  end
end