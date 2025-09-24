class ApplicationController < ActionController::API
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  
  private
  
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
