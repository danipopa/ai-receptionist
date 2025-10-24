class Api::V1::Freeswitch::FreeswitchController < ApplicationController
  skip_before_action :authenticate_api_key, only: [:directory, :dialplan, :configuration]
  
  # FreeSWITCH XML Directory Lookup
  # POST /api/v1/freeswitch/directory
  def directory
    xml_response = FreeswitchDirectoryService.handle_directory_request(params)
    
    render xml: xml_response, content_type: 'application/xml'
  end
  
  # FreeSWITCH XML Dialplan Lookup
  # POST /api/v1/freeswitch/dialplan
  def dialplan
    logger.info("FreeswitchController: Received dialplan request with params: #{params.inspect}")
    xml_response = FreeswitchDirectoryService.handle_dialplan_request(params)
    
    render xml: xml_response, content_type: 'application/xml'
  end
  
  # FreeSWITCH XML Configuration Lookup
  # POST /api/v1/freeswitch/configuration
  def configuration
    xml_response = FreeswitchDirectoryService.handle_configuration_request(params)

    if xml_response.nil?
      head :not_found and return
    end
    
    render xml: xml_response, content_type: 'application/xml'
  end
  
  # Get customer SIP credentials (authenticated endpoint)
  # GET /api/v1/freeswitch/customers/:id/sip_credentials
  def sip_credentials
    customer = Customer.find(params[:id])
    
    render json: {
      sip_username: customer.sip_username,
      sip_domain: customer.sip_domain,
      sip_uri: customer.sip_uri,
      max_concurrent_calls: customer.max_concurrent_calls,
      sip_enabled: customer.sip_enabled
    }
  end
  
  # Update customer SIP settings
  # PATCH /api/v1/freeswitch/customers/:id/sip_credentials  
  def update_sip_credentials
    customer = Customer.find(params[:id])
    
    if customer.update(sip_params)
      render json: {
        message: 'SIP credentials updated successfully',
        sip_username: customer.sip_username,
        sip_domain: customer.sip_domain
      }
    else
      render json: {
        error: 'Failed to update SIP credentials',
        errors: customer.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  # Generate new SIP password for customer
  # POST /api/v1/freeswitch/customers/:id/regenerate_sip_password
  def regenerate_sip_password
    customer = Customer.find(params[:id])
    customer.update!(sip_password: SecureRandom.alphanumeric(16))
    
    render json: {
      message: 'SIP password regenerated successfully',
      sip_password: customer.sip_password
    }
  end
  
  private
  
  def sip_params
    params.require(:customer).permit(:sip_username, :sip_domain, :sip_enabled, :max_concurrent_calls)
  end
  
end