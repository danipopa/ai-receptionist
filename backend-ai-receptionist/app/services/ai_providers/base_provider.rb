class AiProviders::BaseProvider
  class NotImplementedError < StandardError; end

  # Initialize the provider with configuration options
  def initialize(config = {})
    @config = config
    @timeout = config[:timeout] || 30
  end

  # Create a new AI session for a call
  # @param call [Call] the call object
  # @return [Hash] session data with session_id
  def notify_new_call(call)
    raise NotImplementedError, "#{self.class} must implement #notify_new_call"
  end

  # Process audio data and return transcript and AI response
  # @param call [Call] the call object
  # @param audio_data [String] base64 encoded audio data
  # @return [Hash] result with transcript and text_response
  def process_audio(call, audio_data)
    raise NotImplementedError, "#{self.class} must implement #process_audio"
  end

  # Transcribe audio to text
  # @param audio_data [String] base64 encoded audio data
  # @param language [String] language code (default: 'en-US')
  # @return [Hash] result with transcript
  def transcribe_audio(audio_data, language = 'en-US')
    raise NotImplementedError, "#{self.class} must implement #transcribe_audio"
  end

  # Generate speech from text
  # @param text [String] text to synthesize
  # @param voice [String] voice to use
  # @return [Hash] result with audio data
  def synthesize_speech(text, voice = 'alloy')
    raise NotImplementedError, "#{self.class} must implement #synthesize_speech"
  end

  # End the AI session
  # @param call [Call] the call object
  # @return [Boolean] success status
  def end_session(call)
    # Default implementation - can be overridden by providers that need cleanup
    call.update(ai_session_id: nil) if call.ai_session_id
    true
  end

  # Health check for the provider
  # @return [Boolean] health status
  def health_check
    raise NotImplementedError, "#{self.class} must implement #health_check"
  end

  protected

  # Generate a conversation context for AI models
  def build_conversation_context(call)
    messages = []
    
    # Add system prompt
    messages << {
      role: 'system',
      content: build_system_prompt(call)
    }

    # Add conversation history
    call.call_messages.order(:created_at).each do |message|
      role = message.sender == 'user' ? 'user' : 'assistant'
      messages << {
        role: role,
        content: message.content
      }
    end

    messages
  end

  def build_system_prompt(call)
    customer = call.customer
    phone_number = call.phone_number_record

    prompt = "You are an AI receptionist for #{phone_number&.business_name || 'our business'}. "
    prompt += "You are helpful, professional, and knowledgeable about the business. "
    
    if customer&.name.present?
      prompt += "The caller's name is #{customer.name}. "
    end

    if phone_number&.business_hours.present?
      prompt += "Business hours are: #{phone_number.business_hours}. "
    end

    if phone_number&.business_description.present?
      prompt += "About the business: #{phone_number.business_description}. "
    end

    # Add FAQ context if available
    if phone_number
      faqs = phone_number.faqs.limit(10)
      if faqs.any?
        prompt += "\n\nFrequently Asked Questions and Answers:\n"
        faqs.each do |faq|
          prompt += "Q: #{faq.question}\nA: #{faq.answer}\n\n"
        end
        prompt += "Use this FAQ information to answer customer questions when relevant. "
      end
    end

    # Add customer context if available
    if customer
      prompt += "\nCustomer Information:\n"
      prompt += "- Name: #{customer.name}\n" if customer.name.present?
      prompt += "- Email: #{customer.email}\n" if customer.email.present?
      prompt += "- Company: #{customer.company}\n" if customer.company.present?
      prompt += "- Phone: #{customer.phone}\n" if customer.phone.present?
      
      # Add previous call history context
      recent_calls = Call.where(customer: customer)
                        .where.not(id: call.respond_to?(:id) ? call.id : nil)
                        .order(created_at: :desc)
                        .limit(3)
      
      if recent_calls.any?
        prompt += "\nRecent interaction history with this customer:\n"
        recent_calls.each do |recent_call|
          if recent_call.summary.present?
            prompt += "- #{recent_call.created_at.strftime('%Y-%m-%d')}: #{recent_call.summary}\n"
          end
        end
      end
    end

    prompt += "\n\nInstructions:\n"
    prompt += "- Keep responses concise and helpful (2-3 sentences max)\n"
    prompt += "- Be professional and friendly\n"
    prompt += "- Use the FAQ information when answering questions\n"
    prompt += "- If you don't know something specific, say so and offer to take a message or connect them to someone who can help\n"
    prompt += "- For appointment requests, ask for their preferred date and time\n"
    prompt += "- Always try to be helpful and move the conversation forward constructively\n"
    
    prompt
  end

  def log_error(message, exception = nil)
    Rails.logger.error "#{self.class.name}: #{message}"
    Rails.logger.error "Exception: #{exception.message}" if exception
    Rails.logger.error exception.backtrace.join("\n") if exception&.backtrace
  end

  def log_info(message)
    Rails.logger.info "#{self.class.name}: #{message}"
  end
end