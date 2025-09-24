class FreeswitchService
  include HTTParty
  
  base_uri Rails.application.credentials.dig(:freeswitch, :base_url) || ENV['FREESWITCH_URL'] || 'http://localhost:8080'
  
  def initialize
    @options = {
      headers: {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
      },
      timeout: 30
    }
  end

  def setup_call(call)
    response = self.class.post('/call/setup', @options.merge(
      body: {
        call_id: call.external_call_id,
        phone_number: call.phone_number,
        ai_engine_url: ai_engine_url,
        backend_url: backend_url
      }.to_json
    ))

    if response.success?
      Rails.logger.info "FreeSWITCH call setup successful for #{call.external_call_id}"
      response.parsed_response
    else
      Rails.logger.error "FreeSWITCH setup failed: #{response.code} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "FreeSWITCH service error: #{e.message}"
    nil
  end

  def transfer_call(call_id, destination)
    response = self.class.post('/call/transfer', @options.merge(
      body: {
        call_id: call_id,
        destination: destination
      }.to_json
    ))

    if response.success?
      Rails.logger.info "Call transfer initiated: #{call_id} -> #{destination}"
      response.parsed_response
    else
      Rails.logger.error "Call transfer failed: #{response.code} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "FreeSWITCH transfer error: #{e.message}"
    nil
  end

  def end_call(call_id)
    response = self.class.post('/call/end', @options.merge(
      body: {
        call_id: call_id
      }.to_json
    ))

    if response.success?
      Rails.logger.info "Call ended: #{call_id}"
      response.parsed_response
    else
      Rails.logger.error "Call end failed: #{response.code} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "FreeSWITCH end call error: #{e.message}"
    nil
  end

  def get_call_status(call_id)
    response = self.class.get("/call/status/#{call_id}", @options)

    if response.success?
      response.parsed_response
    else
      Rails.logger.error "Failed to get call status: #{response.code} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "FreeSWITCH status error: #{e.message}"
    nil
  end

  def health_check
    response = self.class.get('/health', @options)
    response.success?
  rescue => e
    Rails.logger.error "FreeSWITCH health check failed: #{e.message}"
    false
  end

  private

  def ai_engine_url
    Rails.application.credentials.dig(:ai_engine, :base_url) || ENV['AI_ENGINE_URL'] || 'http://localhost:8081'
  end

  def backend_url
    Rails.application.credentials.dig(:backend, :base_url) || ENV['BACKEND_URL'] || 'http://localhost:3000'
  end
end