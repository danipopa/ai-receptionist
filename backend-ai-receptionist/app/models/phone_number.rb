class PhoneNumber < ApplicationRecord
  belongs_to :customer
  has_many :call_transcripts, dependent: :destroy
  has_many :faqs, dependent: :destroy
  
  validates :number, presence: true, uniqueness: true
  validates :customer, presence: true
  
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
end