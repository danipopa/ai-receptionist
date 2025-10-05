require 'faraday'
require 'json'
require 'base64'

class AiProviders::GeminiProvider < AiProviders::BaseProvider
  def initialize(config = {})
    super(config)
    @api_key = config[:api_key] || ENV['GOOGLE_API_KEY']
    @model = config[:model] || 'gemini-pro'
    @base_url = 'https://generativelanguage.googleapis.com/v1beta'
    
    raise ArgumentError, "Google API key is required" unless @api_key
    
    setup_client
  end

  def notify_new_call(call)
    # Generate a simple session ID for tracking
    session_id = "gemini_#{call.id}_#{Time.current.to_i}"
    call.update(ai_session_id: session_id)
    
    log_info "Created Gemini session: #{session_id}"
    
    {
      'session_id' => session_id,
      'provider' => 'gemini',
      'model' => @model
    }
  rescue => e
    log_error "Failed to create session", e
    nil
  end

  def process_audio(call, audio_data)
    return nil unless call.ai_session_id

    # Note: Gemini doesn't directly support audio transcription
    # You would need to use Google Cloud Speech-to-Text separately
    transcript = '[Audio transcription requires Google Cloud Speech-to-Text integration]'
    
    # Store the placeholder transcript
    call.add_message('user', transcript) if transcript.present?

    # Generate AI response using conversation context
    messages = build_conversation_context(call)
    ai_response = generate_text_response(messages)
    
    if ai_response
      # Store the AI response
      call.add_message('assistant', ai_response)
      
      return {
        'transcript' => transcript,
        'text_response' => ai_response,
        'session_id' => call.ai_session_id
      }
    end

    nil
  rescue => e
    log_error "Failed to process audio", e
    nil
  end

  def transcribe_audio(audio_data, language = 'en-US')
    # Placeholder - would need Google Cloud Speech-to-Text
    log_info "Audio transcription requested (Google Cloud Speech-to-Text integration needed)"
    
    {
      'transcript' => '[Audio transcription requires Google Cloud Speech-to-Text setup]',
      'language' => language,
      'confidence' => 0.0
    }
  rescue => e
    log_error "Transcription error", e
    {
      'transcript' => '',
      'language' => language,
      'confidence' => 0.0
    }
  end

  def synthesize_speech(text, voice = 'alloy')
    # Placeholder - would need Google Cloud Text-to-Speech
    log_info "Speech synthesis requested: #{text[0..50]}... (Google Cloud Text-to-Speech integration needed)"
    
    {
      'audio_data' => nil,
      'format' => 'text',
      'voice' => voice,
      'message' => 'Speech synthesis requires Google Cloud Text-to-Speech setup'
    }
  rescue => e
    log_error "Speech synthesis error", e
    nil
  end

  def health_check
    # Test the Gemini API with a simple request
    begin
      response = @client.post("#{@base_url}/models/#{@model}:generateContent") do |req|
        req.headers['Content-Type'] = 'application/json'
        req.params['key'] = @api_key
        req.body = {
          contents: [{
            parts: [{ text: 'Health check' }]
          }]
        }.to_json
      end
      
      response.success?
    rescue => e
      log_error "Health check failed", e
      false
    end
  end

  private

  def setup_client
    @client = Faraday.new do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = @timeout
    end
  end

  def generate_text_response(messages)
    # Convert our message format to Gemini's format
    gemini_contents = []
    
    # Combine system message with first user message if present
    system_message = messages.find { |msg| msg[:role] == 'system' }&.dig(:content)
    user_messages = messages.select { |msg| msg[:role] == 'user' }
    assistant_messages = messages.select { |msg| msg[:role] == 'assistant' }
    
    # Build conversation for Gemini
    conversation_messages = []
    messages.each do |message|
      next if message[:role] == 'system'
      
      role = message[:role] == 'user' ? 'user' : 'model'
      
      conversation_messages << {
        role: role,
        parts: [{ text: message[:content] }]
      }
    end
    
    # Add system instruction to the first user message if present
    if system_message.present? && conversation_messages.any?
      first_user_msg = conversation_messages.find { |msg| msg[:role] == 'user' }
      if first_user_msg
        enhanced_content = "#{system_message}\n\nUser message: #{first_user_msg[:parts][0][:text]}"
        first_user_msg[:parts][0][:text] = enhanced_content
      end
    end

    # Make the API call
    response = @client.post("#{@base_url}/models/#{@model}:generateContent") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.params['key'] = @api_key
      req.body = {
        contents: conversation_messages,
        generationConfig: {
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
          maxOutputTokens: 150
        }
      }.to_json
    end
    
    if response.success?
      result = JSON.parse(response.body)
      
      if result['candidates']&.any? && result['candidates'][0]['content']
        text_response = result['candidates'][0]['content']['parts'][0]['text']&.strip
        log_info "Generated response: #{text_response[0..100]}..."
        text_response
      else
        log_error "No response generated from Gemini: #{result}"
        "I apologize, but I'm having trouble generating a response right now."
      end
    else
      log_error "Gemini API error: #{response.status} - #{response.body}"
      "I apologize, but I'm experiencing technical difficulties with the AI service."
    end
  rescue => e
    log_error "Text generation error", e
    "I apologize, but I'm experiencing technical difficulties. Please try again."
  end
end