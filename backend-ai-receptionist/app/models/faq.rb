class Faq < ApplicationRecord
  belongs_to :phone_number
  
  validates :title, presence: true
  validates :content, presence: true
  
  # Website scanning statuses
  enum :website_scan_status, {
    not_scanned: 'not_scanned',
    scanning: 'scanning', 
    scanned: 'scanned',
    scan_failed: 'scan_failed'
  }, default: 'not_scanned'
  
  scope :with_website_urls, -> { where.not(website_url: [nil, '']) }
  scope :needs_scanning, -> { with_website_urls.where(website_scan_status: ['not_scanned', 'scan_failed']) }
  scope :recently_scanned, -> { where('website_scanned_at > ?', 1.week.ago) }
  
  def display_content
    if website_url.present?
      "URL: #{website_url}"
    elsif pdf_url.present?
      "PDF: #{pdf_url}"
    else
      content.truncate(100)
    end
  end
  
  # Check if website content needs to be scanned/rescanned
  def needs_website_scan?
    website_url.present? && 
    (website_scan_status.in?(['not_scanned', 'scan_failed']) || 
     website_scanned_at.nil? || 
     website_scanned_at < 1.week.ago)
  end
  
  # Scan website content and update FAQ
  def scan_website_content!
    return false unless website_url.present?
    
    update!(website_scan_status: 'scanning')
    
    scanner = WebsiteScannerService.new
    success = scanner.update_faq_with_website_content(self)
    
    if success
      update!(
        website_scan_status: 'scanned',
        website_scanned_at: Time.current,
        website_content_hash: Digest::MD5.hexdigest(content || '')
      )
    else
      update!(website_scan_status: 'scan_failed')
    end
    
    success
  rescue => e
    Rails.logger.error "Failed to scan website for FAQ #{id}: #{e.message}"
    update!(website_scan_status: 'scan_failed')
    false
  end
  
  # Check if website content has changed (by comparing content hash)
  def website_content_changed?
    return false unless content.present? && website_content_hash.present?
    
    current_hash = Digest::MD5.hexdigest(content)
    current_hash != website_content_hash
  end
end