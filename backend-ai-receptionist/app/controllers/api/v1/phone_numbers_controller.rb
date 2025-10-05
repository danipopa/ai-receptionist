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
      render json: { 
        data: phone_number_json(@phone_number),
        message: 'Phone number created successfully'
      }, status: :created
    else
      render json: { 
        errors: @phone_number.errors.full_messages,
        message: 'Failed to create phone number'
      }, status: :unprocessable_entity
    end
  end
  
  def update
    if @phone_number.update(phone_number_params)
      render json: { 
        data: phone_number_json(@phone_number),
        message: 'Phone number updated successfully'
      }
    else
      render json: { 
        errors: @phone_number.errors.full_messages,
        message: 'Failed to update phone number'
      }, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @phone_number.destroy
      render json: { message: 'Phone number deleted successfully' }
    else
      render json: { 
        errors: ['Failed to delete phone number'],
        message: 'Deletion failed'
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_phone_number
    @phone_number = PhoneNumber.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { message: 'Phone number not found' }, status: :not_found
  end
  
  def set_customer
    @customer = Customer.find(params[:customer_id]) if params[:customer_id]
  rescue ActiveRecord::RecordNotFound
    render json: { message: 'Customer not found' }, status: :not_found
  end
  
  def phone_number_params
    # Handle different parameter structures from frontend
    if params[:number].present?
      # Frontend sends: { "number": { "phone_number": "+1234", "description": "...", "active": true } }
      # OR the entire phone number object including readonly fields
      number_params = params.require(:number)
      
      # Extract only the updatable fields, ignore readonly fields like id, created_at, etc.
      extracted_params = {}
      
      # Map phone_number field to number
      if number_params[:phone_number].present?
        extracted_params[:number] = number_params[:phone_number]
      elsif number_params[:number].present?
        extracted_params[:number] = number_params[:number]
      end
      
      # Map other fields
      extracted_params[:display_name] = number_params[:display_name] if number_params[:display_name].present?
      extracted_params[:description] = number_params[:description] if number_params[:description].present?
      
      # Handle is_primary/active mapping
      if number_params[:is_primary].present?
        extracted_params[:is_primary] = number_params[:is_primary]
      elsif number_params[:active].present?
        extracted_params[:is_primary] = number_params[:active]
      end
      
      extracted_params
    else
      # Standard structure: { "phone_number": { "number": "+1234", "display_name": "...", "is_primary": false } }
      params.require(:phone_number).permit(:number, :display_name, :description, :is_primary)
    end
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
      website_scan_status: faq.website_scan_status,
      website_scanned_at: faq.website_scanned_at,
      needs_scan: faq.needs_website_scan?,
      display_content: faq.display_content,
      created_at: faq.created_at,
      updated_at: faq.updated_at
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