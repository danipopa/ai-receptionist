class Api::V1::HealthController < ApplicationController
  skip_before_action :authenticate_api_key
  
  def index
    begin
      # Test database connection
      ActiveRecord::Base.connection.execute("SELECT 1")
      render json: { 
        status: 'healthy', 
        database: 'connected',
        services: {
          backend: 'healthy',
          database: 'connected'
        },
        timestamp: Time.current 
      }, status: :ok
    rescue => e
      render json: { 
        status: 'unhealthy', 
        database: 'disconnected', 
        error: e.message, 
        timestamp: Time.current 
      }, status: :service_unavailable
    end
  end
end