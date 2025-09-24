class Faq < ApplicationRecord
  belongs_to :phone_number
  
  validates :title, presence: true
  validates :content, presence: true
  
  def display_content
    if website_url.present?
      "URL: #{website_url}"
    elsif pdf_url.present?
      "PDF: #{pdf_url}"
    else
      content.truncate(100)
    end
  end
end