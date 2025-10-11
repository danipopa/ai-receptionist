class Api::V1::CustomersController < ApplicationController
  before_action :set_customer, only: [:show, :update, :destroy, :phone_numbers, :create_phone_number, :website_settings, :update_website_settings, :faq_settings, :update_faq_settings]
  
  def index
    @customers = Customer.all
    render json: { data: @customers }
  end
  
  def show
    render json: { data: @customer }
  end
  
  def create
    @customer = Customer.new(customer_params)
    if @customer.save
      render json: { data: @customer }, status: :created
    else
      render json: { errors: @customer.errors }, status: :unprocessable_entity
    end
  end
  
  def update
    if @customer.update(customer_params)
      render json: { data: @customer }
    else
      render json: { errors: @customer.errors }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @customer.destroy
    head :no_content
  end

  # Phone numbers management
  def phone_numbers
    @phone_numbers = @customer.phone_numbers
    render json: { data: @phone_numbers }
  end

  def create_phone_number
    @phone_number = @customer.phone_numbers.build(phone_number_params)
    if @phone_number.save
      render json: { data: @phone_number }, status: :created
    else
      render json: { errors: @phone_number.errors }, status: :unprocessable_entity
    end
  end

  # Website settings management
  def website_settings
    # For now, use notes field to store website settings as JSON
    settings = if @customer.notes.present?
      begin
        JSON.parse(@customer.notes)
      rescue JSON::ParserError
        {}
      end
    else
      {}
    end
    
    website_data = {
      url: settings['website_url'],
      description: settings['website_description'], 
      enabled: settings['website_enabled'] || false
    }
    
    render json: { data: website_data }
  end

  def update_website_settings
    website_params = params.require(:website).permit(:url, :description, :enabled)
    
    # Store website settings in notes field as JSON
    current_notes = if @customer.notes.present?
      begin
        JSON.parse(@customer.notes)
      rescue JSON::ParserError
        {}
      end
    else
      {}
    end
    
    current_notes['website_url'] = website_params[:url]
    current_notes['website_description'] = website_params[:description]
    current_notes['website_enabled'] = website_params[:enabled]
    
    @customer.notes = current_notes.to_json
    
    if @customer.save
      render json: { data: { 
        url: current_notes['website_url'],
        description: current_notes['website_description'],
        enabled: current_notes['website_enabled']
      }}
    else
      render json: { errors: @customer.errors }, status: :unprocessable_entity
    end
  end

  # FAQ settings management
  def faq_settings
    # For now, use notes field to store FAQ settings as JSON
    settings = if @customer.notes.present?
      begin
        JSON.parse(@customer.notes)
      rescue JSON::ParserError
        {}
      end
    else
      {}
    end
    
    faq_data = {
      enabled: settings['faq_enabled'] || false,
      questions: settings['faq_questions'] || [],
      style: settings['faq_style'] || 'default'
    }
    
    render json: { data: faq_data }
  end

  def update_faq_settings
    faq_params = params.require(:faq).permit(:enabled, :style, questions: [])
    
    # Store FAQ settings in notes field as JSON
    current_notes = if @customer.notes.present?
      begin
        JSON.parse(@customer.notes)
      rescue JSON::ParserError
        {}
      end
    else
      {}
    end
    
    current_notes['faq_enabled'] = faq_params[:enabled]
    current_notes['faq_questions'] = faq_params[:questions] || []
    current_notes['faq_style'] = faq_params[:style]
    
    @customer.notes = current_notes.to_json
    
    if @customer.save
      render json: { data: {
        enabled: current_notes['faq_enabled'],
        questions: current_notes['faq_questions'],
        style: current_notes['faq_style']
      }}
    else
      render json: { errors: @customer.errors }, status: :unprocessable_entity
    end
  end

  private
  
  def set_customer
    @customer = Customer.find(params[:id])
  end
  
  def customer_params
    params.require(:customer).permit(:name, :email, :phone, :company, :address, :notes)
  end

  def phone_number_params
    params.require(:phone_number).permit(
      :number,
      :description,
      :is_primary,
      :sip_trunk_enabled,
      :connection_mode,
      :sip_trunk_host,
      :sip_trunk_port,
      :sip_trunk_username,
      :sip_trunk_password,
      :sip_trunk_domain,
      :sip_trunk_protocol,
      :sip_trunk_context,
      :incoming_calls_enabled,
      :outbound_calls_enabled
    )
  end
end
