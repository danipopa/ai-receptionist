class AiProviders::KubernetesOllamaProvider < AiProviders::BaseProvider
  def initialize(config = {})
    super(config)
    @base_url = config[:base_url] || ENV['OLLAMA_URL'] || 'http://ollama-service.ai-services.svc.cluster.local:11434'
    @text_model = config[:text_model] || ENV['OLLAMA_TEXT_MODEL'] || 'llama2:7b'
    @speech_model = config[:speech_model] || ENV['OLLAMA_SPEECH_MODEL'] || 'whisper'
    
    setup_client
  end

  def notify_new_call(call)
    session_id = "k8s_ollama_#{call.id}_#{Time.current.to_i}"
    call.update(ai_session_id: session_id)
    
    log_info "Created Kubernetes Ollama session: #{session_id}"
    
    {
      'session_id' => session_id,
      'provider' => 'kubernetes-ollama',
      'service_url' => @base_url,
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

    # First transcribe the audio if available
    transcript_result = transcribe_audio(audio_data)
    transcript = transcript_result&.dig('transcript') || ''
    
    # Store the user message if we have a transcript
    if transcript.present?
      call.add_message('user', transcript)
    end

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
    # Note: Ollama's Whisper support varies by deployment
    # This attempts transcription but gracefully falls back
    begin
      response = @client.post("#{@base_url}/api/generate") do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          model: @speech_model,
          prompt: "Transcribe the following audio to text:",
          stream: false,
          options: {
            num_predict: 100
          }
        }.to_json
      end

      if response.success?
        result = JSON.parse(response.body)
        transcript = result['response']&.strip || ''
        
        log_info "Audio transcription completed: #{transcript[0..50]}..."
        
        {
          'transcript' => transcript,
          'language' => language,
          'confidence' => 0.8
        }
      else
        log_info "Audio transcription not available, continuing with text-only"
        {
          'transcript' => '',
          'language' => language,
          'confidence' => 0.0
        }
      end
    rescue => e
      log_info "Audio transcription failed, continuing with text-only: #{e.message}"
      {
        'transcript' => '',
        'language' => language,
        'confidence' => 0.0
      }
    end
  end

  def synthesize_speech(text, voice = 'alloy')
    # Ollama doesn't support TTS, return indication
    log_info "TTS requested but not supported by Ollama: #{text[0..50]}..."
    
    {
      'audio_data' => nil,
      'format' => 'text',
      'voice' => voice,
      'text_fallback' => text,
      'message' => 'Text-to-speech not supported, using text response'
    }
  end

  def health_check
    response = @client.get("#{@base_url}/api/tags")
    
    if response.success?
      result = JSON.parse(response.body)
      models = result['models'] || []
      text_model_available = models.any? { |model| model['name']&.include?(@text_model.split(':').first) }
      
      log_info "Health check: #{models.length} models available, text model (#{@text_model}) available: #{text_model_available}"
      text_model_available
    else
      log_error "Health check failed: #{response.status}"
      false
    end
  rescue => e
    log_error "Health check error", e
    false
  end

  private

  def setup_client
    @client = Faraday.new do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = @timeout
      faraday.options.read_timeout = @timeout
    end
  end

  def generate_text_response(messages)
    # Build conversation context for Ollama
    system_message = messages.find { |msg| msg[:role] == 'system' }&.dig(:content) || ''
    conversation_messages = messages.select { |msg| msg[:role] != 'system' }
    
    # Build conversation string
    conversation = conversation_messages.map { |msg| 
      role = msg[:role] == 'user' ? 'User' : 'Assistant'
      "#{role}: #{msg[:content]}"
    }.join("\n")
    
    # Create the full prompt
    prompt = if system_message.present?
      "#{system_message}\n\nConversation:\n#{conversation}\n\nAssistant:"
    else
      "You are a helpful AI receptionist. Respond professionally and concisely.\n\nConversation:\n#{conversation}\n\nAssistant:"
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
          num_predict: 150,
          stop: ["User:", "Assistant:"]
        }
      }.to_json
    end

    if response.success?
      result = JSON.parse(response.body)
      text_response = result['response']&.strip || ''
      
      # Clean up the response
      text_response = text_response.gsub(/^(Assistant|User):\s*/i, '').strip
      
      # Ensure we have a response
      if text_response.empty?
        text_response = "I understand. How can I help you further?"
      end
      
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
end