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
end