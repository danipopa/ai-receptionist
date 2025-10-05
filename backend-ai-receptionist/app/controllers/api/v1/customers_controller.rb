class Api::V1::CustomersController < ApplicationControllerclass Api::V1::CustomersController < ApplicationController

  before_action :set_customer, only: [:show, :update, :destroy, :phone_numbers, :create_phone_number,   before_action :set_customer, only: [:show, :update, :destroy, :phone_numbers, :create_phone_number, 

                                      :website_settings, :update_website_settings, :faq_settings, :update_faq_settings,                                      :website_settings, :update_website_settings, :faq_settings, :update_faq_settings,

                                      :sip_configuration, :update_sip_configuration, :configure_sip_trunk,                                       :sip_configuration, :update_sip_configuration, :configure_sip_trunk, 

                                      :test_sip_trunk, :freeswitch_config]                                      :test_sip_trunk, :freeswitch_config]

    

  def index  def index

    @customers = Customer.includes(:phone_numbers).order(:name)    @customers = Customer.includes(:phone_numbers).order(:name)

        

    # Simple pagination without kaminari for now    # Simple pagination without kaminari for now

    page = params[:page]&.to_i || 1    page = params[:page]&.to_i || 1

    per_page = 20    per_page = 20

    offset = (page - 1) * per_page    offset = (page - 1) * per_page

        

    @customers = @customers.limit(per_page).offset(offset)    @customers = @customers.limit(per_page).offset(offset)

        

    render json: {    render json: {

      data: @customers.map { |customer| customer_json(customer) },      data: @customers.map { |customer| customer_json(customer) },

      pagination: {      pagination: {

        current_page: page,        current_page: page,

        total_pages: (Customer.count / per_page.to_f).ceil,        total_pages: (Customer.count / per_page.to_f).ceil,

        total_count: Customer.count        total_count: Customer.count

      }      }

    }    }

  end  end

    

  def show  def show

    render json: { data: customer_json(@customer, include_details: true) }    render json: { data: customer_json(@customer, include_details: true) }

  end  end

    

  def create  def create

    @customer = Customer.new(customer_params)    @customer = Customer.new(customer_params)

        

    if @customer.save    if @customer.save

      render json: { data: customer_json(@customer) }, status: :created      render json: { data: customer_json(@customer) }, status: :created

    else    else

      render json: {       render json: { 

        errors: @customer.errors.full_messages,        errors: @customer.errors.full_messages,

        message: 'Failed to create customer'        message: 'Failed to create customer'

      }, status: :unprocessable_entity      }, status: :unprocessable_entity

    end    end

  end  end

    

  def update  def update

    if @customer.update(customer_params)    if @customer.update(customer_params)

      render json: { data: customer_json(@customer) }      render json: { data: customer_json(@customer) }

    else    else

      render json: {       render json: { 

        errors: @customer.errors.full_messages,        errors: @customer.errors.full_messages,

        message: 'Failed to update customer'        message: 'Failed to update customer'

      }, status: :unprocessable_entity      }, status: :unprocessable_entity

    end    end

  end  end

    

  def destroy  def destroy

    @customer.update(active: false)    @customer.update(active: false)

    head :no_content    head :no_content

  end  end

    

  # GET /customers/{id}/numbers - Get phone numbers for customer  # GET /customers/{id}/numbers - Get phone numbers for customer

  def phone_numbers  def phone_numbers

    phone_numbers = @customer.phone_numbers.order(:created_at)    phone_numbers = @customer.phone_numbers.order(:created_at)

    render json: {    render json: {

      data: phone_numbers.map { |pn| phone_number_json(pn, include_faqs: true) }      data: phone_numbers.map { |pn| phone_number_json(pn, include_faqs: true) }

    }    }

  end  end

    

  # POST /customers/{id}/numbers - Add phone number to customer  # POST /customers/{id}/numbers - Add phone number to customer

  def create_phone_number  def create_phone_number

    @phone_number = @customer.phone_numbers.build(phone_number_params)    @phone_number = @customer.phone_numbers.build(phone_number_params)

        

    if @phone_number.save    if @phone_number.save

      render json: {       render json: { 

        data: phone_number_json(@phone_number, include_faqs: true),        data: phone_number_json(@phone_number, include_faqs: true),

        message: 'Phone number added successfully'        message: 'Phone number added successfully'

      }, status: :created      }, status: :created

    else    else

      render json: {       render json: { 

        errors: @phone_number.errors.full_messages,        errors: @phone_number.errors.full_messages,

        message: 'Failed to add phone number'        message: 'Failed to add phone number'

      }, status: :unprocessable_entity      }, status: :unprocessable_entity

    end    end

  end  end

        data: @customers.map { |customer| customer_json(customer) },

  # GET /customers/{id}/website - Get website settings      pagination: {

  def website_settings        current_page: page,

    phone_numbers_with_websites = @customer.phone_numbers.includes(:faqs)        total_pages: (Customer.count / per_page.to_f).ceil,

                                          .joins(:faqs)        total_count: Customer.count

                                          .where.not(faqs: { website_url: [nil, ''] })      }

                                          .distinct    }

      end

    website_faqs = Faq.joins(:phone_number)  

                     .where(phone_number: { customer: @customer })  def show

                     .where.not(website_url: [nil, ''])    render json: { data: customer_json(@customer, include_details: true) }

                     .includes(:phone_number)  end

      

    render json: {  def create

      data: {    @customer = Customer.new(customer_params)

        customer_id: @customer.id,    

        phone_numbers: phone_numbers_with_websites.map do |pn|    if @customer.save

          {      render json: { data: customer_json(@customer) }, status: :created

            id: pn.id,    else

            number: pn.number,      render json: { 

            formatted_number: pn.formatted_number,        errors: @customer.errors.full_messages,

            website_faqs: pn.faqs.where.not(website_url: [nil, '']).map { |faq| website_faq_json(faq) }        message: 'Failed to create customer'

          }      }, status: :unprocessable_entity

        end,    end

        website_faqs: website_faqs.map { |faq| website_faq_json(faq) },  end

        scan_summary: get_last_scan_summary(@customer)  

      }  def update

    }    if @customer.update(customer_params)

  end      render json: { data: customer_json(@customer) }

      else

  # PUT /customers/{id}/website - Update website settings      render json: { 

  def update_website_settings        errors: @customer.errors.full_messages,

    updated_faqs = []        message: 'Failed to update customer'

    errors = []      }, status: :unprocessable_entity

        end

    if params[:faqs].present?  end

      params[:faqs].each do |faq_params|  

        faq = Faq.joins(:phone_number).find_by(id: faq_params[:id], phone_number: { customer: @customer })  def destroy

            @customer.update(active: false)

        if faq && faq.update(website_faq_params(faq_params))    head :no_content

          updated_faqs << faq  end

        elsif faq  

          errors << "FAQ #{faq.id}: #{faq.errors.full_messages.join(', ')}"  # GET /customers/{id}/numbers - Get phone numbers for customer

        else  def phone_numbers

          errors << "FAQ #{faq_params[:id]} not found"    phone_numbers = @customer.phone_numbers.order(:created_at)

        end    render json: {

      end      data: phone_numbers.map { |pn| phone_number_json(pn, include_faqs: true) }

    end    }

      end

    if errors.empty?  

      render json: {  # POST /customers/{id}/numbers - Add phone number to customer

        message: 'Website settings updated successfully',  def create_phone_number

        data: {    @phone_number = @customer.phone_numbers.build(phone_number_params)

          updated_faqs: updated_faqs.map { |faq| website_faq_json(faq) },    

          scan_summary: get_website_scan_summary(@customer)    if @phone_number.save

        }      render json: { 

      }        data: phone_number_json(@phone_number, include_faqs: true),

    else        message: 'Phone number added successfully'

      render json: {      }, status: :created

        errors: errors,    else

        message: 'Some website settings failed to update'      render json: { 

      }, status: :unprocessable_entity        errors: @phone_number.errors.full_messages,

    end        message: 'Failed to add phone number'

  end      }, status: :unprocessable_entity

      end

  # GET /customers/{id}/faq - Get FAQ settings  end

  def faq_settings  

    phone_numbers = @customer.phone_numbers.includes(:faqs).order(:created_at)  # GET /customers/{id}/website - Get website settings

      def website_settings

    render json: {    phone_numbers_with_websites = @customer.phone_numbers.includes(:faqs)

      data: {                                          .joins(:faqs)

        customer_id: @customer.id,                                          .where.not(faqs: { website_url: [nil, ''] })

        customer_name: @customer.name,                                          .distinct

        phone_numbers: phone_numbers.map do |pn|    

          {    website_faqs = Faq.joins(:phone_number)

            id: pn.id,                     .where(phone_number: { customer: @customer })

            number: pn.number,                     .where.not(website_url: [nil, ''])

            formatted_number: pn.formatted_number,                     .includes(:phone_number)

            faqs: pn.faqs.order(:created_at).map { |faq| faq_json(faq) }    

          }    render json: {

        end,      data: {

        total_faqs: @customer.phone_numbers.joins(:faqs).count        customer_id: @customer.id,

      }        phone_numbers: phone_numbers_with_websites.map do |pn|

    }          {

  end            id: pn.id,

              number: pn.formatted_number,

  # PUT /customers/{id}/faq - Update FAQ settings            display_name: pn.display_name,

  def update_faq_settings            website_faqs: pn.faqs.where.not(website_url: [nil, '']).map { |faq| website_faq_json(faq) }

    updated_faqs = []          }

    created_faqs = []        end,

    errors = []        total_website_faqs: website_faqs.count,

            last_scan_summary: get_last_scan_summary(@customer)

    if params[:phone_numbers].present?      }

      params[:phone_numbers].each do |pn_params|    }

        phone_number = @customer.phone_numbers.find_by(id: pn_params[:id])  end

        next unless phone_number  

          # PUT /customers/{id}/website - Update website settings

        if pn_params[:faqs].present?  def update_website_settings

          pn_params[:faqs].each do |faq_params|    success_count = 0

            if faq_params[:id].present?    error_count = 0

              # Update existing FAQ    errors = []

              faq = phone_number.faqs.find_by(id: faq_params[:id])    

              if faq && faq.update(faq_update_params(faq_params))    if params[:website_faqs].present?

                updated_faqs << faq      params[:website_faqs].each do |faq_data|

              elsif faq        faq = Faq.find_by(id: faq_data[:id])

                errors << "FAQ #{faq.id}: #{faq.errors.full_messages.join(', ')}"        

              end        if faq && faq.phone_number.customer == @customer

            else          if faq.update(website_faq_params(faq_data))

              # Create new FAQ            success_count += 1

              faq = phone_number.faqs.build(faq_create_params(faq_params))            # Trigger website scan if URL changed

              if faq.save            if faq.saved_change_to_website_url? && faq.website_url.present?

                created_faqs << faq              faq.scan_website_content!

              else            end

                errors << "New FAQ for #{phone_number.number}: #{faq.errors.full_messages.join(', ')}"          else

              end            error_count += 1

            end            errors << "FAQ #{faq.id}: #{faq.errors.full_messages.join(', ')}"

          end          end

        end        else

      end          error_count += 1

    end          errors << "FAQ #{faq_data[:id]}: Not found or access denied"

            end

    if errors.empty?      end

      render json: {    end

        message: 'FAQ settings updated successfully',    

        data: {    if error_count == 0

          updated_faqs: updated_faqs.map { |faq| faq_json(faq) },      render json: {

          created_faqs: created_faqs.map { |faq| faq_json(faq) },        message: "Successfully updated #{success_count} website FAQ(s)",

          total_faqs: @customer.phone_numbers.joins(:faqs).count        data: { updated_count: success_count }

        }      }

      }    else

    else      render json: {

      render json: {        message: "Updated #{success_count} FAQ(s), #{error_count} error(s)",

        errors: errors,        errors: errors,

        message: 'Some FAQ settings failed to update'        data: { updated_count: success_count, error_count: error_count }

      }, status: :unprocessable_entity      }, status: :unprocessable_entity

    end    end

  end  end

    

  # GET /customers/{id}/sip_configuration - Get customer SIP settings  # GET /customers/{id}/faq - Get FAQ settings

  def sip_configuration  def faq_settings

    render json: {    phone_numbers = @customer.phone_numbers.includes(:faqs).order(:created_at)

      data: {    

        customer_id: @customer.id,    render json: {

        customer_name: @customer.name,      data: {

        sip_enabled: @customer.sip_enabled,        customer_id: @customer.id,

        sip_username: @customer.sip_username,        phone_numbers: phone_numbers.map do |pn|

        sip_domain: @customer.sip_domain,          {

        sip_uri: @customer.sip_uri,            id: pn.id,

        max_concurrent_calls: @customer.max_concurrent_calls,            number: pn.formatted_number,

        phone_numbers: @customer.phone_numbers.map do |pn|            display_name: pn.display_name,

          {            description: pn.description,

            id: pn.id,            faqs: pn.faqs.order(:created_at).map { |faq| faq_json(faq) }

            number: pn.number,          }

            formatted_number: pn.formatted_number,        end,

            sip_trunk_enabled: pn.sip_trunk_enabled,        total_faqs: @customer.phone_numbers.joins(:faqs).count,

            sip_trunk_host: pn.sip_trunk_host,        website_scan_summary: get_website_scan_summary(@customer)

            sip_trunk_port: pn.sip_trunk_port,      }

            sip_trunk_username: pn.sip_trunk_username,    }

            sip_trunk_domain: pn.sip_trunk_domain,  end

            sip_trunk_protocol: pn.sip_trunk_protocol,  

            sip_trunk_context: pn.sip_trunk_context,  # PUT /customers/{id}/faq - Update FAQ settings

            incoming_calls_enabled: pn.incoming_calls_enabled,  def update_faq_settings

            outbound_calls_enabled: pn.outbound_calls_enabled,    success_count = 0

            sip_trunk_uri: pn.sip_trunk_uri    error_count = 0

          }    errors = []

        end    

      }    if params[:faqs].present?

    }      params[:faqs].each do |faq_data|

  end        if faq_data[:id].present?

            # Update existing FAQ

  # PATCH /customers/{id}/sip_configuration - Update customer SIP settings          faq = Faq.joins(:phone_number).find_by(id: faq_data[:id], phone_number: { customer: @customer })

  def update_sip_configuration          

    if @customer.update(sip_configuration_params)          if faq

      render json: {            if faq.update(faq_params(faq_data))

        message: 'SIP configuration updated successfully',              success_count += 1

        data: {              # Trigger website scan if needed

          sip_enabled: @customer.sip_enabled,              if faq.website_url.present? && faq.needs_website_scan?

          sip_username: @customer.sip_username,                faq.scan_website_content!

          sip_domain: @customer.sip_domain,              end

          max_concurrent_calls: @customer.max_concurrent_calls            else

        }              error_count += 1

      }              errors << "FAQ #{faq.id}: #{faq.errors.full_messages.join(', ')}"

    else            end

      render json: {          else

        errors: @customer.errors.full_messages,            error_count += 1

        message: 'Failed to update SIP configuration'            errors << "FAQ #{faq_data[:id]}: Not found or access denied"

      }, status: :unprocessable_entity          end

    end        else

  end          # Create new FAQ

            phone_number = @customer.phone_numbers.find_by(id: faq_data[:phone_number_id])

  # POST /customers/{id}/phone_numbers/{phone_number_id}/configure_sip_trunk          

  def configure_sip_trunk          if phone_number

    phone_number = @customer.phone_numbers.find(params[:phone_number_id])            faq = phone_number.faqs.build(faq_params(faq_data))

                

    if phone_number.update(sip_trunk_params)            if faq.save

      render json: {              success_count += 1

        message: 'SIP trunk configured successfully',              # Trigger website scan if needed

        data: {              if faq.website_url.present?

          phone_number: phone_number.number,                faq.scan_website_content!

          sip_trunk_enabled: phone_number.sip_trunk_enabled,              end

          sip_trunk_uri: phone_number.sip_trunk_uri,            else

          gateway_xml: phone_number.to_freeswitch_gateway_xml,              error_count += 1

          dialplan_xml: phone_number.to_freeswitch_dialplan_xml              errors << "New FAQ: #{faq.errors.full_messages.join(', ')}"

        }            end

      }          else

    else            error_count += 1

      render json: {            errors << "Phone number #{faq_data[:phone_number_id]}: Not found"

        errors: phone_number.errors.full_messages,          end

        message: 'Failed to configure SIP trunk'        end

      }, status: :unprocessable_entity      end

    end    end

  end    

      if error_count == 0

  # POST /customers/{id}/phone_numbers/{phone_number_id}/test_sip_trunk      render json: {

  def test_sip_trunk        message: "Successfully processed #{success_count} FAQ(s)",

    phone_number = @customer.phone_numbers.find(params[:phone_number_id])        data: { updated_count: success_count }

    test_result = phone_number.test_sip_trunk_connection      }

        else

    render json: {      render json: {

      message: 'SIP trunk test completed',        message: "Processed #{success_count} FAQ(s), #{error_count} error(s)",

      test_result: test_result        errors: errors,

    }        data: { updated_count: success_count, error_count: error_count }

  end      }, status: :unprocessable_entity

      end

  # GET /customers/{id}/freeswitch_config - Generate FreeSWITCH configuration for customer  end

  def freeswitch_config  

    sip_enabled_numbers = @customer.phone_numbers.sip_trunk_enabled  # GET /customers/{id}/sip_configuration - Get customer SIP settings

      def sip_configuration

    gateway_configs = sip_enabled_numbers.map(&:to_freeswitch_gateway_xml).compact    render json: {

    dialplan_configs = sip_enabled_numbers.map(&:to_freeswitch_dialplan_xml).compact      data: {

            customer_id: @customer.id,

    render json: {        customer_name: @customer.name,

      customer_id: @customer.id,        sip_enabled: @customer.sip_enabled,

      customer_name: @customer.name,        sip_username: @customer.sip_username,

      directory_xml: @customer.to_freeswitch_directory_xml,        sip_domain: @customer.sip_domain,

      gateway_configs: gateway_configs,        sip_uri: @customer.sip_uri,

      dialplan_configs: dialplan_configs,        max_concurrent_calls: @customer.max_concurrent_calls,

      sip_enabled_numbers: sip_enabled_numbers.count        phone_numbers: @customer.phone_numbers.map do |pn|

    }          {

  end            id: pn.id,

            number: pn.number,

  private            formatted_number: pn.formatted_number,

              sip_trunk_enabled: pn.sip_trunk_enabled,

  def set_customer            sip_trunk_host: pn.sip_trunk_host,

    @customer = Customer.find(params[:id])            sip_trunk_port: pn.sip_trunk_port,

  end            sip_trunk_username: pn.sip_trunk_username,

              sip_trunk_domain: pn.sip_trunk_domain,

  def customer_params            sip_trunk_protocol: pn.sip_trunk_protocol,

    params.require(:customer).permit(:name, :email, :phone, :company, :address, :notes)            sip_trunk_context: pn.sip_trunk_context,

  end            incoming_calls_enabled: pn.incoming_calls_enabled,

              outbound_calls_enabled: pn.outbound_calls_enabled,

  def sip_configuration_params            sip_trunk_uri: pn.sip_trunk_uri

    params.require(:customer).permit(:sip_enabled, :max_concurrent_calls)          }

  end        end

        }

  def sip_trunk_params    }

    params.require(:phone_number).permit(  end

      :sip_trunk_enabled, :sip_trunk_host, :sip_trunk_port,   

      :sip_trunk_username, :sip_trunk_password, :sip_trunk_domain,  # PATCH /customers/{id}/sip_configuration - Update customer SIP settings

      :sip_trunk_protocol, :sip_trunk_context, :incoming_calls_enabled,   def update_sip_configuration

      :outbound_calls_enabled    if @customer.update(sip_configuration_params)

    )      render json: {

  end        message: 'SIP configuration updated successfully',

          data: {

  def phone_number_params          sip_enabled: @customer.sip_enabled,

    params.require(:phone_number).permit(:number, :label, :description)          sip_username: @customer.sip_username,

  end          sip_domain: @customer.sip_domain,

            max_concurrent_calls: @customer.max_concurrent_calls

  def website_faq_params(faq_params)        }

    faq_params.permit(:website_url, :title)      }

  end    else

        render json: {

  def faq_create_params(faq_params)        errors: @customer.errors.full_messages,

    faq_params.permit(:title, :content, :website_url)        message: 'Failed to update SIP configuration'

  end      }, status: :unprocessable_entity

      end

  def faq_update_params(faq_params)  end

    faq_params.permit(:title, :content, :website_url)  

  end  # POST /customers/{id}/phone_numbers/{phone_number_id}/configure_sip_trunk

    def configure_sip_trunk

  def customer_json(customer, include_details: false)    phone_number = @customer.phone_numbers.find(params[:phone_number_id])

    base_data = {    

      id: customer.id,    if phone_number.update(sip_trunk_params)

      name: customer.name,      render json: {

      email: customer.email,        message: 'SIP trunk configured successfully',

      phone: customer.phone,        data: {

      company: customer.company,          phone_number: phone_number.number,

      created_at: customer.created_at,          sip_trunk_enabled: phone_number.sip_trunk_enabled,

      updated_at: customer.updated_at,          sip_trunk_uri: phone_number.sip_trunk_uri,

      phone_numbers_count: customer.phone_numbers.count          gateway_xml: phone_number.to_freeswitch_gateway_xml,

    }          dialplan_xml: phone_number.to_freeswitch_dialplan_xml

            }

    if include_details      }

      base_data.merge!({    else

        address: customer.address,      render json: {

        notes: customer.notes,        errors: phone_number.errors.full_messages,

        phone_numbers: customer.phone_numbers.map { |pn| phone_number_json(pn) }        message: 'Failed to configure SIP trunk'

      })      }, status: :unprocessable_entity

    end    end

      end

    base_data  

  end  # POST /customers/{id}/phone_numbers/{phone_number_id}/test_sip_trunk

    def test_sip_trunk

  def phone_number_json(phone_number, include_faqs: false)    phone_number = @customer.phone_numbers.find(params[:phone_number_id])

    base_data = {    test_result = phone_number.test_sip_trunk_connection

      id: phone_number.id,    

      number: phone_number.number,    render json: {

      formatted_number: phone_number.formatted_number,      message: 'SIP trunk test completed',

      created_at: phone_number.created_at,      test_result: test_result

      updated_at: phone_number.updated_at    }

    }  end

      

    if include_faqs  # GET /customers/{id}/freeswitch_config - Generate FreeSWITCH configuration for customer

      base_data[:faqs] = phone_number.faqs.map { |faq| faq_json(faq) }  def freeswitch_config

      base_data[:faqs_count] = phone_number.faqs.count    sip_enabled_numbers = @customer.phone_numbers.sip_trunk_enabled

    end    

        gateway_configs = sip_enabled_numbers.map(&:to_freeswitch_gateway_xml).compact

    base_data    dialplan_configs = sip_enabled_numbers.map(&:to_freeswitch_dialplan_xml).compact

  end    

      render json: {

  def faq_json(faq)      customer_id: @customer.id,

    {      customer_name: @customer.name,

      id: faq.id,      directory_xml: @customer.to_freeswitch_directory_xml,

      title: faq.title,      gateway_configs: gateway_configs,

      content: faq.content,      dialplan_configs: dialplan_configs,

      website_url: faq.website_url,      sip_enabled_numbers: sip_enabled_numbers.count

      pdf_url: faq.pdf_url,    }

      created_at: faq.created_at,  end

      updated_at: faq.updated_at

    }  private  def set_customer

  end    @customer = Customer.find(params[:id])

    rescue ActiveRecord::RecordNotFound

  def website_faq_json(faq)    render json: { message: 'Customer not found' }, status: :not_found

    {  end

      id: faq.id,  

      title: faq.title,  def customer_params

      website_url: faq.website_url,    params.require(:customer).permit(:name, :email, :company, :phone, :address, :notes)

      scan_status: faq.website_scan_status,  end

      scanned_at: faq.website_scanned_at,  

      content_length: faq.content&.length || 0,  def phone_number_params

      needs_scan: faq.needs_website_scan?    # Handle different parameter structures from frontend

    }    if params[:number].present?

  end      # Frontend sends: { "number": { "phone_number": "+1234", "description": "...", "active": true } }

        # OR the entire phone number object including readonly fields

  def get_last_scan_summary(customer)      number_params = params.require(:number)

    faqs_with_websites = Faq.joins(:phone_number)      

                           .where(phone_number: { customer: customer })      # Extract only the updatable fields, ignore readonly fields like id, created_at, etc.

                           .where.not(website_url: [nil, ''])      extracted_params = {}

          

    {      # Map phone_number field to number

      total_website_faqs: faqs_with_websites.count,      if number_params[:phone_number].present?

      scanned: faqs_with_websites.where(website_scan_status: 'scanned').count,        extracted_params[:number] = number_params[:phone_number]

      failed: faqs_with_websites.where(website_scan_status: 'scan_failed').count,      elsif number_params[:number].present?

      pending: faqs_with_websites.where(website_scan_status: ['not_scanned', 'scanning']).count,        extracted_params[:number] = number_params[:number]

      last_scan_at: faqs_with_websites.maximum(:website_scanned_at)      end

    }      

  end      # Map other fields

        extracted_params[:display_name] = number_params[:display_name] if number_params[:display_name].present?

  def get_website_scan_summary(customer)      extracted_params[:description] = number_params[:description] if number_params[:description].present?

    faqs_with_websites = Faq.joins(:phone_number)      

                           .where(phone_number: { customer: customer })      # Handle is_primary/active mapping

                           .where.not(website_url: [nil, ''])      if number_params[:is_primary].present?

            extracted_params[:is_primary] = number_params[:is_primary]

    total_faqs = Faq.joins(:phone_number).where(phone_number: { customer: customer }).count      elsif number_params[:active].present?

            extracted_params[:is_primary] = number_params[:active]

    {      end

      total_faqs: total_faqs,      

      website_faqs: faqs_with_websites.count,      extracted_params

      scan_status: {    else

        scanned: faqs_with_websites.where(website_scan_status: 'scanned').count,      # Standard structure: { "phone_number": { "number": "+1234", "display_name": "...", "is_primary": false } }

        failed: faqs_with_websites.where(website_scan_status: 'scan_failed').count,      params.require(:phone_number).permit(:number, :display_name, :description, :is_primary)

        pending: faqs_with_websites.where(website_scan_status: ['not_scanned', 'scanning']).count    end

      }  end

    }  

  end  def faq_params(faq_data = params)

end    faq_data.permit(:title, :content, :website_url, :pdf_url)
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