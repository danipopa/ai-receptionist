class HealthController < ApplicationController
  def ai_engine
    service = AiEngineService.new
    status = service.health_check
    
    if status
      render json: { status: 'healthy', service: 'ai_engine' }
    else
      render json: { status: 'unhealthy', service: 'ai_engine' }, status: :service_unavailable
    end
  end

  def freeswitch
    service = FreeswitchService.new
    status = service.health_check
    
    if status
      render json: { status: 'healthy', service: 'freeswitch' }
    else
      render json: { status: 'unhealthy', service: 'freeswitch' }, status: :service_unavailable
    end
  end

  def all_services
    ai_engine = AiEngineService.new.health_check
    freeswitch = FreeswitchService.new.health_check
    
    services = {
      ai_engine: ai_engine ? 'healthy' : 'unhealthy',
      freeswitch: freeswitch ? 'healthy' : 'unhealthy',
      backend: 'healthy'
    }
    
    overall_status = services.values.all? { |status| status == 'healthy' } ? 'healthy' : 'degraded'
    
    render json: {
      status: overall_status,
      services: services,
      timestamp: Time.current.iso8601
    }
  end
end