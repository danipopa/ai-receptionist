require 'openai'
require 'base64'
require 'tempfile'

class AiProviders::HuggingFaceProvider < AiProviders::BaseProvider
  def initialize(config = {})
    super(config)
    @api_key = config[:api_key] || ENV['HUGGINGFACE_API_KEY']
    @base_url = config[:base_url] || 'https://api-inference.huggingface.co'
    @text_model = config[:text_model] || 'microsoft/DialoGPT-medium'
    @speech_model = config[:speech_model] || 'openai/whisper-large-v3'
    @tts_model = config[:tts_model] || 'microsoft/speecht5_tts'
    
    raise ArgumentError, "Hugging Face API key is required" unless @api_key
    
    setup_client
  end

  def notify_new_call(call)
    # Generate a simple session ID for tracking
    session_id = "hf_#{call.id}_#{Time.current.to_i}"
    call.update(ai_session_id: session_id)
    
    log_info "Created Hugging Face session: #{session_id}"
    
    {
      'session_id' => session_id,
      'provider' => 'huggingface',
      'models' => {
        'text' => @text_model,
        'speech' => @speech_model,
        'tts' => @tts_model
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

    # Use Hugging Face Inference API for speech recognition
    response = @client.post("#{@base_url}/models/#{@speech_model}") do |req|
      req.headers['Authorization'] = "Bearer #{@api_key}"
      req.headers['Content-Type'] = 'audio/wav'
      req.body = audio_binary
    end

    temp_file.close
    temp_file.unlink

    if response.success?
      result = JSON.parse(response.body)
      transcript = result['text'] || result.dig(0, 'text') || ''
      
      log_info "Transcribed audio: #{transcript[0..100]}..."
      
      {
        'transcript' => transcript,
        'language' => language,
        'confidence' => result['confidence'] || 0.9
      }
    else
      log_error "Transcription failed: #{response.status} - #{response.body}"
      nil
    end
  rescue => e
    log_error "Transcription error", e
    nil
  end

  def synthesize_speech(text, voice = 'alloy')
    # Use Hugging Face Text-to-Speech model
    response = @client.post("#{@base_url}/models/#{@tts_model}") do |req|
      req.headers['Authorization'] = "Bearer #{@api_key}"
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        inputs: text,
        parameters: {
          voice: voice
        }
      }.to_json
    end

    if response.success?
      # Response should be audio data
      audio_data = Base64.encode64(response.body)
      
      log_info "Synthesized speech for: #{text[0..50]}..."
      
      {
        'audio_data' => audio_data,
        'format' => 'wav',
        'voice' => voice
      }
    else
      log_error "Speech synthesis failed: #{response.status} - #{response.body}"
      nil
    end
  rescue => e
    log_error "Speech synthesis error", e
    nil
  end

  def health_check
    response = @client.get("#{@base_url}/models/#{@text_model}") do |req|
      req.headers['Authorization'] = "Bearer #{@api_key}"
    end
    
    response.success?
  rescue => e
    log_error "Health check failed", e
    false
  end

  private

  def setup_client
    @client = Faraday.new do |faraday|
      faraday.request :multipart
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = @timeout
    end
  end

  def generate_text_response(messages)
    # Convert messages to a single conversation string for simpler models
    conversation = messages.map { |msg| "#{msg[:role]}: #{msg[:content]}" }.join("\n")
    
    response = @client.post("#{@base_url}/models/#{@text_model}") do |req|
      req.headers['Authorization'] = "Bearer #{@api_key}"
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        inputs: conversation,
        parameters: {
          max_new_tokens: 150,
          temperature: 0.7,
          do_sample: true,
          return_full_text: false
        }
      }.to_json
    end

    if response.success?
      result = JSON.parse(response.body)
      
      # Handle different response formats
      text_response = if result.is_a?(Array) && result.first
                       result.first['generated_text'] || result.first['text']
                     elsif result.is_a?(Hash)
                       result['generated_text'] || result['text']
                     else
                       result.to_s
                     end

      # Clean up the response
      text_response = text_response.to_s.strip
      text_response = text_response.gsub(/^assistant:\s*/i, '') # Remove assistant prefix if present
      
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