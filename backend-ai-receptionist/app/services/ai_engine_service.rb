class AiEngineService
  include HTTParty
  
  base_uri Rails.application.credentials.dig(:ai_engine, :base_url) || ENV['AI_ENGINE_URL'] || 'http://localhost:8081'
  
  def initialize
    @options = {
      headers: {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      },
      timeout: 30
    }
    
    # Initialize AI provider based on configuration
    @provider = initialize_ai_provider
  end

  def notify_new_call(call)
    if @provider
      @provider.notify_new_call(call)
    else
      # Fallback to original implementation
      original_notify_new_call(call)
    end
  end

  def process_audio(call, audio_data)
    if @provider
      @provider.process_audio(call, audio_data)
    else
      # Fallback to original implementation
      original_process_audio(call, audio_data)
    end
  end

  def transcribe_audio(audio_data, language = 'en-US')
    if @provider
      @provider.transcribe_audio(audio_data, language)
    else
      # Fallback to original implementation
      original_transcribe_audio(audio_data, language)
    end
  end

  def synthesize_speech(text, voice = 'alloy')
    if @provider
      @provider.synthesize_speech(text, voice)
    else
      # Fallback to original implementation
      original_synthesize_speech(text, voice)
    end
  end

  def end_session(call)
    if @provider
      @provider.end_session(call)
    else
      # Fallback to original implementation
      original_end_session(call)
    end
  end

  def health_check
    if @provider
      @provider.health_check
    else
      # Fallback to original implementation
      original_health_check
    end
  end

  private

  def initialize_ai_provider
    provider_type = ENV['AI_PROVIDER'] || 'original'
    
    case provider_type.downcase
    when 'huggingface', 'hf'
      AiProviders::HuggingFaceProvider.new(
        api_key: ENV['HUGGINGFACE_API_KEY'],
        text_model: ENV['HF_TEXT_MODEL'] || 'microsoft/DialoGPT-medium',
        speech_model: ENV['HF_SPEECH_MODEL'] || 'openai/whisper-large-v3',
        tts_model: ENV['HF_TTS_MODEL'] || 'microsoft/speecht5_tts'
      )
    when 'ollama'
      AiProviders::OllamaProvider.new(
        base_url: ENV['OLLAMA_URL'] || 'http://localhost:11434',
        text_model: ENV['OLLAMA_TEXT_MODEL'] || 'llama2',
        speech_model: ENV['OLLAMA_SPEECH_MODEL'] || 'whisper'
      )
    when 'kubernetes-ollama', 'k8s-ollama'
      AiProviders::KubernetesOllamaProvider.new(
        base_url: ENV['OLLAMA_URL'] || 'http://ollama-service.ai-services.svc.cluster.local:11434',
        text_model: ENV['OLLAMA_TEXT_MODEL'] || 'llama2:7b',
        speech_model: ENV['OLLAMA_SPEECH_MODEL'] || 'whisper'
      )
    when 'gemini'
      AiProviders::GeminiProvider.new(
        api_key: ENV['GOOGLE_API_KEY'],
        model: ENV['GEMINI_MODEL'] || 'gemini-pro'
      )
    when 'original'
      nil  # Use original implementation
    else
      Rails.logger.warn "Unknown AI provider: #{provider_type}. Falling back to original implementation."
      nil
    end
  rescue => e
    Rails.logger.error "Failed to initialize AI provider #{provider_type}: #{e.message}"
    nil
  end

  # Original implementation methods (preserved for backward compatibility)
  def original_notify_new_call(call)
    response = self.class.post('/session/create', @options.merge(
      body: {
        call_id: call.external_call_id,
        phone_number: call.phone_number,
        context: 'receptionist',
        language: 'en-US'
      }.to_json
    ))

    if response.success?
      session_data = response.parsed_response
      call.update(ai_session_id: session_data['session_id'])
      Rails.logger.info "AI Engine session created: #{session_data['session_id']}"
      session_data
    else
      Rails.logger.error "Failed to create AI Engine session: #{response.code} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "AI Engine service error: #{e.message}"
    nil
  end

  def original_process_audio(call, audio_data)
    return nil unless call.ai_session_id

    response = self.class.post('/process', @options.merge(
      body: {
        session_id: call.ai_session_id,
        audio_data: audio_data,
        format: 'wav'
      }.to_json
    ))

    if response.success?
      result = response.parsed_response
      
      # Store messages in database
      if result['transcript'].present?
        call.add_message('user', result['transcript'])
      end
      
      if result['text_response'].present?
        call.add_message('assistant', result['text_response'])
      end

      result
    else
      Rails.logger.error "AI processing failed: #{response.code} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "AI Engine processing error: #{e.message}"
    nil
  end

  def original_transcribe_audio(audio_data, language = 'en-US')
    response = self.class.post('/transcribe', @options.merge(
      body: {
        audio_data: audio_data,
        language: language
      }.to_json
    ))

    if response.success?
      response.parsed_response
    else
      Rails.logger.error "Transcription failed: #{response.code} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "Transcription error: #{e.message}"
    nil
  end

  def original_synthesize_speech(text, voice = 'alloy')
    response = self.class.post('/synthesize', @options.merge(
      body: {
        text: text,
        voice: voice,
        format: 'mp3'
      }.to_json
    ))

    if response.success?
      response.parsed_response
    else
      Rails.logger.error "Speech synthesis failed: #{response.code} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "Speech synthesis error: #{e.message}"
    nil
  end

  def original_end_session(call)
    return nil unless call.ai_session_id

    response = self.class.delete("/session/#{call.ai_session_id}", @options)

    if response.success?
      call.update(ai_session_id: nil)
      Rails.logger.info "AI Engine session ended: #{call.ai_session_id}"
      true
    else
      Rails.logger.error "Failed to end AI session: #{response.code} - #{response.body}"
      false
    end
  rescue => e
    Rails.logger.error "AI Engine session cleanup error: #{e.message}"
    false
  end

  def original_health_check
    response = self.class.get('/health', @options)
    response.success? && response.parsed_response['status'] == 'healthy'
  rescue => e
    Rails.logger.error "AI Engine health check failed: #{e.message}"
    false
  end
end