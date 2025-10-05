require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'uri'

class WebsiteScannerService
  include HTTParty
  
  USER_AGENT = 'AI-Receptionist-Bot/1.0 (Content Scanner for Customer Service)'
  
  def initialize
    @timeout = 10
    @max_content_length = 50_000 # 50KB limit for extracted content
  end

  # Scan a website URL and extract relevant content for AI context
  # @param url [String] the website URL to scan
  # @param context_hint [String] optional hint about what type of content to focus on
  # @return [Hash] extracted content with metadata
  def scan_website(url, context_hint: nil)
    return { error: 'Invalid URL' } unless valid_url?(url)
    
    begin
      response = fetch_with_retry(url)
      return { error: response[:error] } if response[:error]
      
      content = extract_content(response[:body], url, context_hint)
      
      {
        url: url,
        title: content[:title],
        description: content[:description],
        main_content: content[:main_content],
        business_info: content[:business_info],
        contact_info: content[:contact_info],
        faq_sections: content[:faq_sections],
        metadata: {
          scanned_at: Time.current,
          content_length: content[:main_content]&.length || 0,
          status: 'success'
        }
      }
    rescue => e
      Rails.logger.error "Website scanning failed for #{url}: #{e.message}"
      { error: "Scanning failed: #{e.message}" }
    end
  end

  # Update FAQ with website content
  # @param faq [Faq] the FAQ record to update
  # @return [Boolean] success status
  def update_faq_with_website_content(faq)
    return false unless faq.website_url.present?
    
    result = scan_website(faq.website_url, context_hint: faq.title)
    
    if result[:error]
      Rails.logger.warn "Failed to scan website for FAQ #{faq.id}: #{result[:error]}"
      return false
    end
    
    # Extract relevant content and update FAQ
    extracted_content = build_faq_content(result, faq.title)
    
    faq.update(
      content: extracted_content,
      title: faq.title.present? ? faq.title : result[:title]&.truncate(255)
    )
    
    Rails.logger.info "Updated FAQ #{faq.id} with content from #{faq.website_url}"
    true
  end

  # Scan all website URLs for a phone number's FAQs
  # @param phone_number [PhoneNumber] the phone number record
  # @return [Hash] summary of scanning results
  def scan_faqs_for_phone_number(phone_number)
    results = {
      total_faqs: 0,
      scanned: 0,
      errors: 0,
      updated: []
    }
    
    phone_number.faqs.where.not(website_url: [nil, '']).find_each do |faq|
      results[:total_faqs] += 1
      
      if update_faq_with_website_content(faq)
        results[:scanned] += 1
        results[:updated] << faq.id
      else
        results[:errors] += 1
      end
    end
    
    results
  end

  private

  def valid_url?(url)
    uri = URI.parse(url)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end

  def fetch_with_retry(url, retries = 2)
    uri = URI.parse(url)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = @timeout
    http.read_timeout = @timeout
    
    request = Net::HTTP::Get.new(uri.request_uri)
    request['User-Agent'] = USER_AGENT
    request['Accept'] = 'text/html,application/xhtml+xml'
    
    response = http.request(request)
    
    case response
    when Net::HTTPSuccess
      { body: response.body, status: response.code }
    when Net::HTTPRedirection
      if retries > 0 && response['location']
        fetch_with_retry(response['location'], retries - 1)
      else
        { error: 'Too many redirects' }
      end
    else
      { error: "HTTP #{response.code}: #{response.message}" }
    end
  rescue Net::TimeoutError
    { error: 'Request timeout' }
  rescue => e
    { error: e.message }
  end

  def extract_content(html, url, context_hint = nil)
    doc = Nokogiri::HTML(html)
    
    # Remove script and style elements
    doc.css('script, style, nav, footer, aside, .advertisement, .ads').remove
    
    content = {
      title: extract_title(doc),
      description: extract_description(doc),
      main_content: extract_main_content(doc),
      business_info: extract_business_info(doc),
      contact_info: extract_contact_info(doc),
      faq_sections: extract_faq_sections(doc)
    }
    
    # Focus on context if hint provided
    if context_hint.present?
      content[:main_content] = focus_content_by_hint(content[:main_content], context_hint)
    end
    
    content
  end

  def extract_title(doc)
    doc.at_css('title')&.text&.strip || 
    doc.at_css('h1')&.text&.strip&.truncate(100)
  end

  def extract_description(doc)
    doc.at_css('meta[name="description"]')&.[]('content')&.strip ||
    doc.at_css('meta[property="og:description"]')&.[]('content')&.strip ||
    doc.css('p').first&.text&.strip&.truncate(300)
  end

  def extract_main_content(doc)
    # Try to find main content areas
    content_selectors = [
      'main', '[role="main"]', '.main-content', '.content', 
      'article', '.article', '#content', '.post-content'
    ]
    
    main_content = nil
    content_selectors.each do |selector|
      element = doc.at_css(selector)
      if element
        main_content = clean_text(element.text)
        break
      end
    end
    
    # Fallback to body content if no main content found
    main_content ||= clean_text(doc.at_css('body')&.text || '')
    
    main_content.truncate(@max_content_length)
  end

  def extract_business_info(doc)
    business_keywords = ['about', 'company', 'business', 'services', 'what we do']
    
    sections = doc.css('section, div, article').select do |section|
      section_text = section.text.downcase
      business_keywords.any? { |keyword| section_text.include?(keyword) }
    end
    
    business_content = sections.map { |section| clean_text(section.text) }
                              .join(' ')
                              .truncate(1000)
    
    business_content.present? ? business_content : nil
  end

  def extract_contact_info(doc)
    contact_info = {}
    
    # Email patterns
    emails = doc.text.scan(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/)
    contact_info[:emails] = emails.uniq.first(3) if emails.any?
    
    # Phone patterns
    phones = doc.text.scan(/(\+?1?[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})/)
    contact_info[:phones] = phones.map { |match| match.join('') }.uniq.first(3) if phones.any?
    
    # Address patterns (basic)
    address_elements = doc.css('[itemprop="address"], .address, .contact-address')
    if address_elements.any?
      contact_info[:address] = clean_text(address_elements.first.text).truncate(200)
    end
    
    contact_info.any? ? contact_info : nil
  end

  def extract_faq_sections(doc)
    faq_selectors = [
      '.faq', '.faqs', '.frequently-asked-questions',
      '[id*="faq"]', '[class*="faq"]'
    ]
    
    faq_content = []
    
    faq_selectors.each do |selector|
      doc.css(selector).each do |faq_section|
        # Look for question-answer pairs
        questions = faq_section.css('h1, h2, h3, h4, h5, h6, .question, .q, dt')
        questions.each do |question|
          q_text = clean_text(question.text)
          next if q_text.length < 5
          
          # Find the answer (next sibling or within same container)
          answer_element = question.next_element || 
                          question.parent.css('p, .answer, .a, dd').first
          
          if answer_element
            a_text = clean_text(answer_element.text)
            if a_text.length > 5
              faq_content << {
                question: q_text.truncate(200),
                answer: a_text.truncate(500)
              }
            end
          end
        end
      end
    end
    
    faq_content.any? ? faq_content.first(10) : nil
  end

  def focus_content_by_hint(content, hint)
    return content if hint.blank? || content.blank?
    
    # Split content into paragraphs and score by relevance to hint
    paragraphs = content.split(/\n\s*\n/).reject(&:blank?)
    hint_words = hint.downcase.split(/\W+/)
    
    scored_paragraphs = paragraphs.map do |paragraph|
      score = hint_words.sum { |word| paragraph.downcase.scan(word).length }
      { paragraph: paragraph, score: score }
    end
    
    # Return top-scoring paragraphs
    relevant_paragraphs = scored_paragraphs
                         .sort_by { |p| -p[:score] }
                         .first(5)
                         .map { |p| p[:paragraph] }
    
    relevant_paragraphs.join("\n\n").truncate(@max_content_length)
  end

  def build_faq_content(scan_result, original_title)
    content_parts = []
    
    # Add title and description
    if scan_result[:title].present?
      content_parts << "Title: #{scan_result[:title]}"
    end
    
    if scan_result[:description].present?
      content_parts << "Description: #{scan_result[:description]}"
    end
    
    # Add business info if relevant
    if scan_result[:business_info].present?
      content_parts << "Business Information: #{scan_result[:business_info]}"
    end
    
    # Add main content
    if scan_result[:main_content].present?
      content_parts << "Content: #{scan_result[:main_content]}"
    end
    
    # Add contact info
    if scan_result[:contact_info].present?
      contact_parts = []
      scan_result[:contact_info].each do |key, value|
        contact_parts << "#{key.to_s.humanize}: #{Array(value).join(', ')}"
      end
      content_parts << "Contact Information: #{contact_parts.join('; ')}"
    end
    
    # Add FAQ sections if found
    if scan_result[:faq_sections].present?
      faq_text = scan_result[:faq_sections].map do |faq|
        "Q: #{faq[:question]}\nA: #{faq[:answer]}"
      end.join("\n\n")
      content_parts << "FAQ Section: #{faq_text}"
    end
    
    content_parts.join("\n\n").truncate(10_000)
  end

  def clean_text(text)
    return '' if text.blank?
    
    text.gsub(/\s+/, ' ')           # Normalize whitespace
        .gsub(/[^\x00-\x7F]/, '')   # Remove non-ASCII chars
        .strip
  end
end