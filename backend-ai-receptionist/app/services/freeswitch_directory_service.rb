class FreeswitchDirectoryService
  class << self
    # Generate FreeSWITCH directory XML for all customers
    def generate_directory_xml
      customers = Customer.sip_enabled.includes(:phone_numbers)
      
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <document type="freeswitch/xml">
          <section name="directory">
            <domain name="ai-receptionist.local">
              <params>
                <param name="dial-string" value="{^^:sip_invite_domain=${dialed_domain}:presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(*/${dialed_user}@${dialed_domain})}"/>
              </params>
              <variables>
                <variable name="record_stereo" value="true"/>
                <variable name="default_gateway" value="$${default_provider}"/>
                <variable name="default_areacode" value="$${default_areacode}"/>
                <variable name="transfer_fallback_extension" value="operator"/>
              </variables>
              <groups>
                <group name="ai_receptionist">
                  <users>
                    #{customers.map(&:to_freeswitch_directory_xml).join("\n")}
                  </users>
                </group>
              </groups>
            </domain>
          </section>
        </document>
      XML
    end
    
    # Handle FreeSWITCH directory lookup requests
    def handle_directory_request(params)
      domain = params['domain']
      user = params['user']
      
      return generate_directory_xml unless user.present?
      
      customer = Customer.find_by(sip_username: user, sip_domain: domain)
      return not_found_xml unless customer&.sip_enabled?
      
      customer_directory_xml(customer)
    end
    
    private
    
    def customer_directory_xml(customer)
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <document type="freeswitch/xml">
          <section name="directory">
            <domain name="#{customer.sip_domain}">
              <groups>
                <group name="ai_receptionist">
                  <users>
                    #{customer.to_freeswitch_directory_xml}
                  </users>
                </group>
              </groups>
            </domain>
          </section>
        </document>
      XML
    end
    
    def not_found_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <document type="freeswitch/xml">
          <section name="result">
            <result status="not found" />
          </section>
        </document>
      XML
    end
  end
end