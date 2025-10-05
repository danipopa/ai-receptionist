class ApplicationController < ActionController::API
  class AuthenticationError < StandardError; end
  
  before_action :authenticate_api_key, unless: :skip_authentication?
  
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from AuthenticationError, with: :handle_authentication_error
  
  private
  
  def skip_authentication?
    # Skip authentication for health check actions
    action_name.in?(['health', 'ready']) || 
    (controller_name == 'health' && action_name.in?(['index', 'ai_engine', 'freeswitch', 'all_services']))
  end
  
  def authenticate_api_key
    api_key = extract_api_key
    
    unless api_key_valid?(api_key)
      raise AuthenticationError, 'Invalid or missing API key'
    end
  end
  
  def extract_api_key
    # Check Authorization header (Bearer token)
    if request.headers['Authorization'].present?
      auth_header = request.headers['Authorization']
      return auth_header.sub(/^Bearer\s/, '') if auth_header.start_with?('Bearer ')
    end
    
    # Check X-API-Key header
    request.headers['X-API-Key']
  end
  
  def api_key_valid?(api_key)
    return false if api_key.blank?
    
    # For now, check against environment variable
    # In production, you might want to store API keys in database
    valid_api_keys = [
      ENV['API_KEY'],
      ENV['PRIMARY_API_KEY'],
      ENV['SECONDARY_API_KEY']
    ].compact
    
    valid_api_keys.include?(api_key)
  end
  
  def handle_authentication_error(exception)
    render json: { 
      message: 'Authentication failed',
      error: exception.message 
    }, status: :unauthorized
  end
  
  def handle_not_found(exception)
    render json: { 
      message: 'Record not found',
      error: exception.message 
    }, status: :not_found
  end
  
  def handle_validation_error(exception)
    render json: { 
      message: 'Validation failed',
      errors: exception.record.errors.full_messages 
    }, status: :unprocessable_entity
  end
  
  def handle_standard_error(exception)
    Rails.logger.error "#{exception.class}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    render json: { 
      message: 'An error occurred',
      error: Rails.env.development? ? exception.message : 'Internal server error'
    }, status: :internal_server_error
  end
end
