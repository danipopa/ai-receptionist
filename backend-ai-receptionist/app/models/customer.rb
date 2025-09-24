class Customer < ApplicationRecord
  has_many :phone_numbers, dependent: :destroy
  has_many :call_transcripts, through: :phone_numbers
  
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end