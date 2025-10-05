namespace :website do
  desc "Scan all FAQ websites and update content"
  task scan_all: :environment do
    puts "Starting website scan for all FAQs..."
    
    scanner = WebsiteScannerService.new
    total_faqs = 0
    total_scanned = 0
    total_errors = 0
    
    PhoneNumber.includes(:faqs).find_each do |phone_number|
      puts "Scanning FAQs for phone number: #{phone_number.formatted_number}"
      
      results = scanner.scan_faqs_for_phone_number(phone_number)
      total_faqs += results[:total_faqs]
      total_scanned += results[:scanned]
      total_errors += results[:errors]
      
      if results[:updated].any?
        puts "  Updated FAQ IDs: #{results[:updated].join(', ')}"
      end
      
      if results[:errors] > 0
        puts "  Errors: #{results[:errors]}"
      end
    end
    
    puts "\nWebsite scanning completed!"
    puts "Total FAQs with websites: #{total_faqs}"
    puts "Successfully scanned: #{total_scanned}"
    puts "Errors: #{total_errors}"
  end
  
  desc "Scan websites for a specific phone number"
  task :scan_phone_number, [:phone_number_id] => :environment do |task, args|
    phone_number_id = args[:phone_number_id]
    
    unless phone_number_id
      puts "Usage: rake website:scan_phone_number[phone_number_id]"
      exit 1
    end
    
    phone_number = PhoneNumber.find_by(id: phone_number_id)
    unless phone_number
      puts "Phone number with ID #{phone_number_id} not found"
      exit 1
    end
    
    puts "Scanning websites for phone number: #{phone_number.formatted_number}"
    
    scanner = WebsiteScannerService.new
    results = scanner.scan_faqs_for_phone_number(phone_number)
    
    puts "Results:"
    puts "  Total FAQs with websites: #{results[:total_faqs]}"
    puts "  Successfully scanned: #{results[:scanned]}"
    puts "  Errors: #{results[:errors]}"
    puts "  Updated FAQ IDs: #{results[:updated].join(', ')}" if results[:updated].any?
  end
  
  desc "Scan a single FAQ website"
  task :scan_faq, [:faq_id] => :environment do |task, args|
    faq_id = args[:faq_id]
    
    unless faq_id
      puts "Usage: rake website:scan_faq[faq_id]"
      exit 1
    end
    
    faq = Faq.find_by(id: faq_id)
    unless faq
      puts "FAQ with ID #{faq_id} not found"
      exit 1
    end
    
    unless faq.website_url.present?
      puts "FAQ #{faq_id} doesn't have a website URL"
      exit 1
    end
    
    puts "Scanning website for FAQ: #{faq.title}"
    puts "URL: #{faq.website_url}"
    
    if faq.scan_website_content!
      puts "✅ Successfully scanned and updated FAQ content"
      puts "Content length: #{faq.content&.length || 0} characters"
    else
      puts "❌ Failed to scan website content"
    end
  end
  
  desc "List FAQs that need website scanning"
  task list_unscanned: :environment do
    faqs = Faq.needs_scanning.includes(:phone_number)
    
    if faqs.empty?
      puts "No FAQs need website scanning"
      return
    end
    
    puts "FAQs that need website scanning:"
    puts "ID | Title | Website URL | Phone Number | Status"
    puts "-" * 80
    
    faqs.each do |faq|
      puts "#{faq.id.to_s.ljust(3)} | #{faq.title&.truncate(20)&.ljust(20)} | #{faq.website_url&.truncate(30)&.ljust(30)} | #{faq.phone_number.formatted_number.ljust(15)} | #{faq.website_scan_status}"
    end
    
    puts "\nTotal: #{faqs.count} FAQs"
  end
end