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
  end

  def notify_new_call(call)
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

  def process_audio(call, audio_data)
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

  def transcribe_audio(audio_data, language = 'en-US')
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

  def synthesize_speech(text, voice = 'alloy')
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

  def end_session(call)
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

  def health_check
    response = self.class.get('/health', @options)
    response.success? && response.parsed_response['status'] == 'healthy'
  rescue => e
    Rails.logger.error "AI Engine health check failed: #{e.message}"
    false
  end
end