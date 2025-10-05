class AddWebsiteScanningToFaqs < ActiveRecord::Migration[8.0]
  def change
    add_column :faqs, :website_scanned_at, :datetime
    add_column :faqs, :website_scan_status, :string
    add_column :faqs, :website_content_hash, :string
  end
end
