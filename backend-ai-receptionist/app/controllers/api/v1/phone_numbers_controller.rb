class Api::V1::PhoneNumbersController < ApplicationController
  before_action :set_phone_number, only: [:show, :update, :destroy]
  before_action :set_customer, only: [:index, :create]
  
  def index
    @phone_numbers = @customer.phone_numbers.includes(:faqs, :call_transcripts)
    render json: {
      data: @phone_numbers.map { |pn| phone_number_json(pn, include_details: true) }
    }
  end
  
  def show
    render json: { data: phone_number_json(@phone_number, include_details: true) }
  end
  
  def create
    @phone_number = @customer.phone_numbers.build(phone_number_params)
    
    if @phone_number.save
      render json: { data: phone_number_json(@phone_number) }, status: :created
    else
      render json: { errors: @phone_number.errors }, status: :unprocessable_entity
    end
  end
  
  def update
    if @phone_number.update(phone_number_params)
      render json: { data: phone_number_json(@phone_number) }
    else
      render json: { errors: @phone_number.errors }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @phone_number.update(active: false)
    head :no_content
  end
  
  private
  
  def set_phone_number
    @phone_number = PhoneNumber.find(params[:id])
  end
  
  def set_customer
    @customer = Customer.find(params[:customer_id]) if params[:customer_id]
  end
  
  def phone_number_params
    params.require(:phone_number).permit(:number, :label, :description, :active, settings: {})
  end
  
  def phone_number_json(phone_number, include_details: false)
    json = {
      id: phone_number.id,
      number: phone_number.number,
      formatted_number: phone_number.formatted_number,
      display_name: phone_number.display_name,
      description: phone_number.description,
      is_primary: phone_number.is_primary,
      customer_id: phone_number.customer_id,
      customer_name: phone_number.customer.name,
      created_at: phone_number.created_at,
      updated_at: phone_number.updated_at
    }
    
    if include_details
      json[:faqs] = phone_number.faqs.map { |faq| faq_json(faq) }
      json[:recent_calls] = phone_number.call_transcripts.recent.limit(5).map { |call| call_json(call) }
    end
    
    json
  end
  
  def faq_json(faq)
    {
      id: faq.id,
      title: faq.title,
      content: faq.content,
      pdf_url: faq.pdf_url,
      website_url: faq.website_url,
      display_content: faq.display_content
    }
  end
  
  def call_json(call)
    {
      id: call.id,
      caller_phone: call.caller_phone,
      status: call.status,
      duration: call.formatted_duration,
      started_at: call.started_at,
      ended_at: call.ended_at
    }
  end
end