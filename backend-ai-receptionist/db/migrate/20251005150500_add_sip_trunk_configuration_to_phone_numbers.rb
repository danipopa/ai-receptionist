class AddSipTrunkConfigurationToPhoneNumbers < ActiveRecord::Migration[8.0]
  def change
    add_column :phone_numbers, :sip_trunk_enabled, :boolean, default: false, null: false
    add_column :phone_numbers, :sip_trunk_host, :string
    add_column :phone_numbers, :sip_trunk_port, :integer, default: 5060
    add_column :phone_numbers, :sip_trunk_username, :string
    add_column :phone_numbers, :sip_trunk_password, :string
    add_column :phone_numbers, :sip_trunk_domain, :string
    add_column :phone_numbers, :sip_trunk_protocol, :string, default: 'UDP'
    add_column :phone_numbers, :sip_trunk_context, :string, default: 'ai_receptionist'
    add_column :phone_numbers, :incoming_calls_enabled, :boolean, default: true, null: false
    add_column :phone_numbers, :outbound_calls_enabled, :boolean, default: false, null: false
    
    add_index :phone_numbers, [:sip_trunk_username, :sip_trunk_domain], 
              name: 'index_phone_numbers_on_sip_trunk_username_and_domain'
    add_index :phone_numbers, :sip_trunk_enabled
  end
end