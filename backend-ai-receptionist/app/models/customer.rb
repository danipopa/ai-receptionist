class Customer < ApplicationRecord
  has_many :phone_numbers, dependent: :destroy
  has_many :call_transcripts, through: :phone_numbers
  
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  
  # Generate customer identifier for FreeSWITCH context
  def ai_receptionist_id
    "customer_#{id}"
  end
  
  # Generate FreeSWITCH context variables for this customer
  def to_freeswitch_context_vars
    {
      customer_id: id,
      customer_name: name,
      customer_email: email,
      primary_phone: phone_numbers.first&.number
    }
  end
end