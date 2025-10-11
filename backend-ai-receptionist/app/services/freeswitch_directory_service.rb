class FreeswitchDirectoryService
  class << self
    # Generate FreeSWITCH directory XML - simplified since customers don't register TO us
    def generate_directory_xml
      # No customer registration needed - just basic domain setup
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <document type="freeswitch/xml">
          <section name="directory">
            <domain name="ai-receptionist.local">
              <params>
                <param name="dial-string" value="{presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(*/${dialed_user}@${dialed_domain})}"/>
              </params>
              <variables>
                <variable name="record_stereo" value="true"/>
                <variable name="transfer_fallback_extension" value="ai_operator"/>
              </variables>
              <groups>
                <group name="ai_receptionist">
                  <users>
                    <!-- AI Receptionist service users only -->
                    <user id="ai_service">
                      <params>
                        <param name="password" value="ai_service_internal"/>
                      </params>
                      <variables>
                        <variable name="user_context" value="ai_receptionist"/>
                      </variables>
                    </user>
                  </users>
                </group>
              </groups>
            </domain>
          </section>
        </document>
      XML
    end
    
    # Generate FreeSWITCH gateway configuration for all SIP connections (both trunk and register modes)
    def generate_gateway_xml
      phone_numbers = PhoneNumber.sip_trunk_enabled.includes(:customer)
      
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <document type="freeswitch/xml">
          <section name="configuration">
            <configuration name="sofia.conf">
              <profiles>
                <profile name="external">
                  <gateways>
                    #{phone_numbers.map(&:to_freeswitch_gateway_xml).compact.join("\n")}
                  </gateways>
                </profile>
              </profiles>
            </configuration>
          </section>
        </document>
      XML
    end
    
    # Generate FreeSWITCH dialplan for incoming call routing
    def generate_dialplan_xml
      phone_numbers = PhoneNumber.sip_trunk_enabled.incoming_enabled.includes(:customer)
      
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <document type="freeswitch/xml">
          <section name="dialplan">
            <context name="ai_receptionist">
              #{phone_numbers.map(&:to_freeswitch_dialplan_xml).join("\n")}
              
              <!-- Default extension for unmatched numbers -->
              <extension name="unmatched">
                <condition field="destination_number" expression="^(.*)$">
                  <action application="answer"/>
                  <action application="sleep" data="1000"/>
                  <action application="playback" data="ivr/ivr-no_user_response.wav"/>
                  <action application="hangup"/>
                </condition>
              </extension>
            </context>
          </section>
        </document>
      XML
    end
    
    # Handle FreeSWITCH directory lookup requests
    def handle_directory_request(params)
      domain = params['domain']
      user = params['user']
      
      return generate_directory_xml unless user.present?
      
      # First try to find by customer SIP username
      customer = Customer.find_by(sip_username: user, sip_domain: domain)
      return customer_directory_xml(customer) if customer&.sip_enabled?
      
      # Then try to find by phone number SIP trunk username
      phone_number = PhoneNumber.joins(:customer)
                               .where(sip_trunk_username: user, 
                                     sip_trunk_domain: domain,
                                     sip_trunk_enabled: true)
                               .first
      
      return phone_number_directory_xml(phone_number) if phone_number
      
      not_found_xml
    end
    
    # Handle incoming call routing requests
    def handle_dialplan_request(params)
      destination_number = params['Caller-Destination-Number']
      
      return generate_dialplan_xml unless destination_number.present?
      
      # Find phone number by incoming number
      phone_number = PhoneNumber.find_by(number: destination_number, 
                                        sip_trunk_enabled: true,
                                        incoming_calls_enabled: true)
      
      return phone_number_dialplan_xml(phone_number) if phone_number
      
      not_found_xml
    end
    
    # Handle gateway configuration requests
    def handle_configuration_request(params)
      section = params['section']
      
      case section
      when 'sofia.conf'
        generate_gateway_xml
      else
        not_found_xml
      end
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
    
    def phone_number_directory_xml(phone_number)
      customer = phone_number.customer
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <document type="freeswitch/xml">
          <section name="directory">
            <domain name="#{phone_number.sip_trunk_domain}">
              <groups>
                <group name="#{phone_number.sip_trunk_context}">
                  <users>
                    <user id="#{phone_number.sip_trunk_username}">
                      <params>
                        <param name="password" value="#{phone_number.sip_trunk_password}"/>
                        <param name="dial-string" value="{presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(${dialed_user}@${dialed_domain})}"/>
                      </params>
                      <variables>
                        <variable name="customer_id" value="#{customer.id}"/>
                        <variable name="phone_number_id" value="#{phone_number.id}"/>
                        <variable name="phone_number" value="#{phone_number.number}"/>
                        <variable name="customer_name" value="#{customer.name}"/>
                        <variable name="toll_allow" value="domestic,international,local"/>
                        <variable name="accountcode" value="#{phone_number.sip_trunk_username}"/>
                        <variable name="user_context" value="#{phone_number.sip_trunk_context}"/>
                        <variable name="effective_caller_id_name" value="#{customer.name}"/>
                        <variable name="effective_caller_id_number" value="#{phone_number.number}"/>
                      </variables>
                    </user>
                  </users>
                </group>
              </groups>
            </domain>
          </section>
        </document>
      XML
    end
    
    def phone_number_dialplan_xml(phone_number)
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <document type="freeswitch/xml">
          <section name="dialplan">
            <context name="#{phone_number.sip_trunk_context}">
              #{phone_number.to_freeswitch_dialplan_xml}
            </context>
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