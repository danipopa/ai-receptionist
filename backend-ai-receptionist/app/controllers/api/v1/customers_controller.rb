class Api::V1::CustomersController < ApplicationController
  before_action :set_customer, only: [:show, :update, :destroy, :phone_numbers, :create_phone_number, 
                                      :website_settings, :update_website_settings, :faq_settings, :update_faq_settings]
  
  def index
    @customers = Customer.includes(:phone_numbers).or  def customer_params
    params.require(:customer).permit(:name, :email, :phone, :company, :address, :notes)
  end
  
  def sip_configuration_params
    params.require(:customer).permit(:sip_enabled, :max_concurrent_calls)
  end
  
  def sip_trunk_params
    params.require(:phone_number).permit(
      :sip_trunk_enabled, :sip_trunk_host, :sip_trunk_port, 
      :sip_trunk_username, :sip_trunk_password, :sip_trunk_domain,
      :sip_trunk_protocol, :sip_trunk_context, :incoming_calls_enabled, 
      :outbound_calls_enabled
    )
  end(:name)
    
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
  
  # GET /customers/{id}/numbers - Get phone numbers for customer
  def phone_numbers
    phone_numbers = @customer.phone_numbers.order(:created_at)
    render json: {
      data: phone_numbers.map { |pn| phone_number_json(pn, include_faqs: true) }
    }
  end
  
  # POST /customers/{id}/numbers - Add phone number to customer
  def create_phone_number
    @phone_number = @customer.phone_numbers.build(phone_number_params)
    
    if @phone_number.save
      render json: { 
        data: phone_number_json(@phone_number, include_faqs: true),
        message: 'Phone number added successfully'
      }, status: :created
    else
      render json: { 
        errors: @phone_number.errors.full_messages,
        message: 'Failed to add phone number'
      }, status: :unprocessable_entity
    end
  end
  
  # GET /customers/{id}/website - Get website settings
  def website_settings
    phone_numbers_with_websites = @customer.phone_numbers.includes(:faqs)
                                          .joins(:faqs)
                                          .where.not(faqs: { website_url: [nil, ''] })
                                          .distinct
    
    website_faqs = Faq.joins(:phone_number)
                     .where(phone_number: { customer: @customer })
                     .where.not(website_url: [nil, ''])
                     .includes(:phone_number)
    
    render json: {
      data: {
        customer_id: @customer.id,
        phone_numbers: phone_numbers_with_websites.map do |pn|
          {
            id: pn.id,
            number: pn.formatted_number,
            display_name: pn.display_name,
            website_faqs: pn.faqs.where.not(website_url: [nil, '']).map { |faq| website_faq_json(faq) }
          }
        end,
        total_website_faqs: website_faqs.count,
        last_scan_summary: get_last_scan_summary(@customer)
      }
    }
  end
  
  # PUT /customers/{id}/website - Update website settings
  def update_website_settings
    success_count = 0
    error_count = 0
    errors = []
    
    if params[:website_faqs].present?
      params[:website_faqs].each do |faq_data|
        faq = Faq.find_by(id: faq_data[:id])
        
        if faq && faq.phone_number.customer == @customer
          if faq.update(website_faq_params(faq_data))
            success_count += 1
            # Trigger website scan if URL changed
            if faq.saved_change_to_website_url? && faq.website_url.present?
              faq.scan_website_content!
            end
          else
            error_count += 1
            errors << "FAQ #{faq.id}: #{faq.errors.full_messages.join(', ')}"
          end
        else
          error_count += 1
          errors << "FAQ #{faq_data[:id]}: Not found or access denied"
        end
      end
    end
    
    if error_count == 0
      render json: {
        message: "Successfully updated #{success_count} website FAQ(s)",
        data: { updated_count: success_count }
      }
    else
      render json: {
        message: "Updated #{success_count} FAQ(s), #{error_count} error(s)",
        errors: errors,
        data: { updated_count: success_count, error_count: error_count }
      }, status: :unprocessable_entity
    end
  end
  
  # GET /customers/{id}/faq - Get FAQ settings
  def faq_settings
    phone_numbers = @customer.phone_numbers.includes(:faqs).order(:created_at)
    
    render json: {
      data: {
        customer_id: @customer.id,
        phone_numbers: phone_numbers.map do |pn|
          {
            id: pn.id,
            number: pn.formatted_number,
            display_name: pn.display_name,
            description: pn.description,
            faqs: pn.faqs.order(:created_at).map { |faq| faq_json(faq) }
          }
        end,
        total_faqs: @customer.phone_numbers.joins(:faqs).count,
        website_scan_summary: get_website_scan_summary(@customer)
      }
    }
  end
  
  # PUT /customers/{id}/faq - Update FAQ settings
  def update_faq_settings
    success_count = 0
    error_count = 0
    errors = []
    
    if params[:faqs].present?
      params[:faqs].each do |faq_data|
        if faq_data[:id].present?
          # Update existing FAQ
          faq = Faq.joins(:phone_number).find_by(id: faq_data[:id], phone_number: { customer: @customer })
          
          if faq
            if faq.update(faq_params(faq_data))
              success_count += 1
              # Trigger website scan if needed
              if faq.website_url.present? && faq.needs_website_scan?
                faq.scan_website_content!
              end
            else
              error_count += 1
              errors << "FAQ #{faq.id}: #{faq.errors.full_messages.join(', ')}"
            end
          else
            error_count += 1
            errors << "FAQ #{faq_data[:id]}: Not found or access denied"
          end
        else
          # Create new FAQ
          phone_number = @customer.phone_numbers.find_by(id: faq_data[:phone_number_id])
          
          if phone_number
            faq = phone_number.faqs.build(faq_params(faq_data))
            
            if faq.save
              success_count += 1
              # Trigger website scan if needed
              if faq.website_url.present?
                faq.scan_website_content!
              end
            else
              error_count += 1
              errors << "New FAQ: #{faq.errors.full_messages.join(', ')}"
            end
          else
            error_count += 1
            errors << "Phone number #{faq_data[:phone_number_id]}: Not found"
          end
        end
      end
    end
    
    if error_count == 0
      render json: {
        message: "Successfully processed #{success_count} FAQ(s)",
        data: { updated_count: success_count }
      }
    else
      render json: {
        message: "Processed #{success_count} FAQ(s), #{error_count} error(s)",
        errors: errors,
        data: { updated_count: success_count, error_count: error_count }
      }, status: :unprocessable_entity
    end
  end
  
  # GET /customers/{id}/sip_configuration - Get customer SIP settings
  def sip_configuration
    render json: {
      data: {
        customer_id: @customer.id,
        customer_name: @customer.name,
        sip_enabled: @customer.sip_enabled,
        sip_username: @customer.sip_username,
        sip_domain: @customer.sip_domain,
        sip_uri: @customer.sip_uri,
        max_concurrent_calls: @customer.max_concurrent_calls,
        phone_numbers: @customer.phone_numbers.map do |pn|
          {
            id: pn.id,
            number: pn.number,
            formatted_number: pn.formatted_number,
            sip_trunk_enabled: pn.sip_trunk_enabled,
            sip_trunk_host: pn.sip_trunk_host,
            sip_trunk_port: pn.sip_trunk_port,
            sip_trunk_username: pn.sip_trunk_username,
            sip_trunk_domain: pn.sip_trunk_domain,
            sip_trunk_protocol: pn.sip_trunk_protocol,
            sip_trunk_context: pn.sip_trunk_context,
            incoming_calls_enabled: pn.incoming_calls_enabled,
            outbound_calls_enabled: pn.outbound_calls_enabled,
            sip_trunk_uri: pn.sip_trunk_uri
          }
        end
      }
    }
  end
  
  # PATCH /customers/{id}/sip_configuration - Update customer SIP settings
  def update_sip_configuration
    if @customer.update(sip_configuration_params)
      render json: {
        message: 'SIP configuration updated successfully',
        data: {
          sip_enabled: @customer.sip_enabled,
          sip_username: @customer.sip_username,
          sip_domain: @customer.sip_domain,
          max_concurrent_calls: @customer.max_concurrent_calls
        }
      }
    else
      render json: {
        errors: @customer.errors.full_messages,
        message: 'Failed to update SIP configuration'
      }, status: :unprocessable_entity
    end
  end
  
  # POST /customers/{id}/phone_numbers/{phone_number_id}/configure_sip_trunk
  def configure_sip_trunk
    phone_number = @customer.phone_numbers.find(params[:phone_number_id])
    
    if phone_number.update(sip_trunk_params)
      render json: {
        message: 'SIP trunk configured successfully',
        data: {
          phone_number: phone_number.number,
          sip_trunk_enabled: phone_number.sip_trunk_enabled,
          sip_trunk_uri: phone_number.sip_trunk_uri,
          gateway_xml: phone_number.to_freeswitch_gateway_xml,
          dialplan_xml: phone_number.to_freeswitch_dialplan_xml
        }
      }
    else
      render json: {
        errors: phone_number.errors.full_messages,
        message: 'Failed to configure SIP trunk'
      }, status: :unprocessable_entity
    end
  end
  
  # POST /customers/{id}/phone_numbers/{phone_number_id}/test_sip_trunk
  def test_sip_trunk
    phone_number = @customer.phone_numbers.find(params[:phone_number_id])
    test_result = phone_number.test_sip_trunk_connection
    
    render json: {
      message: 'SIP trunk test completed',
      test_result: test_result
    }
  end
  
  # GET /customers/{id}/freeswitch_config - Generate FreeSWITCH configuration for customer
  def freeswitch_config
    sip_enabled_numbers = @customer.phone_numbers.sip_trunk_enabled
    
    gateway_configs = sip_enabled_numbers.map(&:to_freeswitch_gateway_xml).compact
    dialplan_configs = sip_enabled_numbers.map(&:to_freeswitch_dialplan_xml).compact
    
    render json: {
      customer_id: @customer.id,
      customer_name: @customer.name,
      directory_xml: @customer.to_freeswitch_directory_xml,
      gateway_configs: gateway_configs,
      dialplan_configs: dialplan_configs,
      sip_enabled_numbers: sip_enabled_numbers.count
    }
  end

  private  def set_customer
    @customer = Customer.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { message: 'Customer not found' }, status: :not_found
  end
  
  def customer_params
    params.require(:customer).permit(:name, :email, :company, :phone, :address, :notes)
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
  
  def faq_params(faq_data = params)
    faq_data.permit(:title, :content, :website_url, :pdf_url)
  end
  
  def website_faq_params(faq_data)
    faq_data.permit(:title, :content, :website_url)
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
  
  def phone_number_json(phone_number, include_faqs: false)
    json = {
      id: phone_number.id,
      number: phone_number.number,
      formatted_number: phone_number.formatted_number,
      display_name: phone_number.display_name,
      description: phone_number.description,
      is_primary: phone_number.is_primary,
      faqs_count: phone_number.faqs.count,
      call_transcripts_count: phone_number.call_transcripts.count,
      created_at: phone_number.created_at,
      updated_at: phone_number.updated_at
    }
    
    if include_faqs
      json[:faqs] = phone_number.faqs.order(:created_at).map { |faq| faq_json(faq) }
    end
    
    json
  end
  
  def faq_json(faq)
    {
      id: faq.id,
      title: faq.title,
      content: faq.content,
      website_url: faq.website_url,
      pdf_url: faq.pdf_url,
      website_scan_status: faq.website_scan_status,
      website_scanned_at: faq.website_scanned_at,
      needs_scan: faq.needs_website_scan?,
      created_at: faq.created_at,
      updated_at: faq.updated_at
    }
  end
  
  def website_faq_json(faq)
    {
      id: faq.id,
      title: faq.title,
      website_url: faq.website_url,
      scan_status: faq.website_scan_status,
      scanned_at: faq.website_scanned_at,
      content_length: faq.content&.length || 0,
      needs_scan: faq.needs_website_scan?
    }
  end
  
  def get_last_scan_summary(customer)
    faqs_with_websites = Faq.joins(:phone_number)
                           .where(phone_number: { customer: customer })
                           .where.not(website_url: [nil, ''])
    
    {
      total_website_faqs: faqs_with_websites.count,
      scanned: faqs_with_websites.where(website_scan_status: 'scanned').count,
      failed: faqs_with_websites.where(website_scan_status: 'scan_failed').count,
      pending: faqs_with_websites.where(website_scan_status: ['not_scanned', 'scanning']).count,
      last_scan_at: faqs_with_websites.maximum(:website_scanned_at)
    }
  end
  
  def get_website_scan_summary(customer)
    faqs_with_websites = Faq.joins(:phone_number)
                           .where(phone_number: { customer: customer })
                           .where.not(website_url: [nil, ''])
    
    total_faqs = Faq.joins(:phone_number).where(phone_number: { customer: customer }).count
    
    {
      total_faqs: total_faqs,
      website_faqs: faqs_with_websites.count,
      scan_status: {
        scanned: faqs_with_websites.where(website_scan_status: 'scanned').count,
        failed: faqs_with_websites.where(website_scan_status: 'scan_failed').count,
        pending: faqs_with_websites.where(website_scan_status: ['not_scanned', 'scanning']).count
      }
    }
  end
end