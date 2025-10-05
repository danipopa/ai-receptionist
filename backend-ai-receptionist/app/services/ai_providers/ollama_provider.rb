require 'base64'
require 'tempfile'

class AiProviders::OllamaProvider < AiProviders::BaseProvider
  def initialize(config = {})
    super(config)
    @base_url = config[:base_url] || ENV['OLLAMA_URL'] || 'http://localhost:11434'
    @text_model = config[:text_model] || 'llama2'
    @speech_model = config[:speech_model] || 'whisper'  # Ollama supports Whisper models
    
    setup_client
  end

  def notify_new_call(call)
    # Generate a simple session ID for tracking
    session_id = "ollama_#{call.id}_#{Time.current.to_i}"
    call.update(ai_session_id: session_id)
    
    log_info "Created Ollama session: #{session_id}"
    
    {
      'session_id' => session_id,
      'provider' => 'ollama',
      'models' => {
        'text' => @text_model,
        'speech' => @speech_model
      }
    }
  rescue => e
    log_error "Failed to create session", e
    nil
  end

  def process_audio(call, audio_data)
    return nil unless call.ai_session_id

    # First transcribe the audio
    transcript_result = transcribe_audio(audio_data)
    return nil unless transcript_result&.dig('transcript')

    transcript = transcript_result['transcript']
    
    # Store the user message
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
    # Decode base64 audio data
    audio_binary = Base64.decode64(audio_data)
    
    # Create temporary file for audio
    temp_file = Tempfile.new(['audio', '.wav'])
    temp_file.binmode
    temp_file.write(audio_binary)
    temp_file.rewind

    # Use Ollama API for speech recognition (if Whisper model is available)
    audio_base64 = Base64.encode64(audio_binary)
    
    response = @client.post("#{@base_url}/api/generate") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        model: @speech_model,
        prompt: "Transcribe this audio:",
        images: [audio_base64],  # Some models accept audio as images
        stream: false
      }.to_json
    end

    temp_file.close
    temp_file.unlink

    if response.success?
      result = JSON.parse(response.body)
      transcript = result['response']&.strip || ''
      
      log_info "Transcribed audio: #{transcript[0..100]}..."
      
      {
        'transcript' => transcript,
        'language' => language,
        'confidence' => 0.9
      }
    else
      log_error "Transcription failed: #{response.status} - #{response.body}"
      # Fallback: return empty transcript to allow text-only interaction
      {
        'transcript' => '',
        'language' => language,
        'confidence' => 0.0
      }
    end
  rescue => e
    log_error "Transcription error", e
    # Fallback: return empty transcript
    {
      'transcript' => '',
      'language' => language,
      'confidence' => 0.0
    }
  end

  def synthesize_speech(text, voice = 'alloy')
    # Ollama doesn't typically support TTS, so we'll return a placeholder
    # In a real implementation, you might integrate with a separate TTS service
    log_info "Speech synthesis requested for: #{text[0..50]}... (not supported by Ollama)"
    
    {
      'audio_data' => nil,
      'format' => 'text',
      'voice' => voice,
      'message' => 'Speech synthesis not supported by Ollama provider'
    }
  rescue => e
    log_error "Speech synthesis error", e
    nil
  end

  def health_check
    response = @client.get("#{@base_url}/api/tags")
    
    if response.success?
      result = JSON.parse(response.body)
      # Check if our text model is available
      models = result['models'] || []
      models.any? { |model| model['name']&.include?(@text_model) }
    else
      false
    end
  rescue => e
    log_error "Health check failed", e
    false
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
    # Build system message and conversation history
    system_message = messages.find { |msg| msg[:role] == 'system' }&.dig(:content) || ''
    conversation_messages = messages.select { |msg| msg[:role] != 'system' }
    
    # Build conversation context
    conversation = conversation_messages.map { |msg| 
      role = msg[:role] == 'user' ? 'Human' : 'Assistant'
      "#{role}: #{msg[:content]}"
    }.join("\n")
    
    # Create the full prompt
    prompt = if system_message.present?
      "#{system_message}\n\nConversation:\n#{conversation}\n\nAssistant:"
    else
      "#{conversation}\n\nAssistant:"
    end

    response = @client.post("#{@base_url}/api/generate") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        model: @text_model,
        prompt: prompt,
        stream: false,
        options: {
          temperature: 0.7,
          top_p: 0.9,
          max_tokens: 150
        }
      }.to_json
    end

    if response.success?
      result = JSON.parse(response.body)
      text_response = result['response']&.strip || ''
      
      # Clean up the response
      text_response = text_response.gsub(/^(Assistant|Human):\s*/i, '')
      
      log_info "Generated response: #{text_response[0..100]}..."
      text_response
    else
      log_error "Text generation failed: #{response.status} - #{response.body}"
      "I apologize, but I'm having trouble processing your request right now. Please try again."
    end
  rescue => e
    log_error "Text generation error", e
    "I apologize, but I'm experiencing technical difficulties. Please try again."
  end

  def ensure_model_available(model_name)
    # Check if model is already pulled
    response = @client.get("#{@base_url}/api/tags")
    
    if response.success?
      result = JSON.parse(response.body)
      models = result['models'] || []
      return true if models.any? { |model| model['name']&.include?(model_name) }
    end
    
    # If model is not available, attempt to pull it
    log_info "Pulling model #{model_name}..."
    
    pull_response = @client.post("#{@base_url}/api/pull") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = { name: model_name }.to_json
    end
    
    pull_response.success?
  rescue => e
    log_error "Failed to ensure model availability", e
    false
  end
end