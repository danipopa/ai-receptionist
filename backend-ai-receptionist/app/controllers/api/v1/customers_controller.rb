class Api::V1::CustomersController < ApplicationController
  before_action :set_customer, only: [:show, :update, :destroy]
  
  def index
    @customers = Customer.includes(:phone_numbers).order(:name)
    
    # Simple pagination without kaminari for now
    page = params[:page]&.to_i || 1
    per_page = 20
    offset = (page - 1) * per_page
    
    @customers = @customers.limit(per_page).offset(offset)
    
    render json: {
      data: @customers.map { |customer| customer_json(customer) },
      pagination: {
        current_page: page,
        total_pages: (Customer.count / per_page.to_f).ceil,
        total_count: Customer.count
      }
    }
  end
  
  def show
    render json: { data: customer_json(@customer, include_details: true) }
  end
  
  def create
    @customer = Customer.new(customer_params)
    
    if @customer.save
      render json: { data: customer_json(@customer) }, status: :created
    else
      render json: { 
        errors: @customer.errors.full_messages,
        message: 'Failed to create customer'
      }, status: :unprocessable_entity
    end
  end
  
  def update
    if @customer.update(customer_params)
      render json: { data: customer_json(@customer) }
    else
      render json: { 
        errors: @customer.errors.full_messages,
        message: 'Failed to update customer'
      }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @customer.update(active: false)
    head :no_content
  end
  
  private
  
  def set_customer
    @customer = Customer.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { message: 'Customer not found' }, status: :not_found
  end
  
  def customer_params
    params.require(:customer).permit(:name, :email, :company, :phone, :address, :notes)
  end
  
  def customer_json(customer, include_details: false)
    json = {
      id: customer.id,
      name: customer.name,
      email: customer.email,
      company: customer.company,
      phone: customer.phone,
      address: customer.address,
      notes: customer.notes,
      phone_numbers_count: customer.phone_numbers.count,
      created_at: customer.created_at,
      updated_at: customer.updated_at
    }
    
    if include_details
      json[:phone_numbers] = customer.phone_numbers.map { |pn| phone_number_json(pn) }
    end
    
    json
  end
  
  def phone_number_json(phone_number)
    {
      id: phone_number.id,
      number: phone_number.number,
      formatted_number: phone_number.formatted_number,
      display_name: phone_number.display_name,
      description: phone_number.description,
      is_primary: phone_number.is_primary,
      faqs_count: phone_number.faqs.count,
      call_transcripts_count: phone_number.call_transcripts.count
    }
  end
end