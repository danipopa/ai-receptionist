class AddSipAuthenticationToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :sip_username, :string
    add_column :customers, :sip_password, :string
    add_column :customers, :sip_domain, :string, default: 'ai-receptionist.local'
    add_column :customers, :sip_enabled, :boolean, default: true
    add_column :customers, :max_concurrent_calls, :integer, default: 5
    
    add_index :customers, :sip_username, unique: true
    add_index :customers, [:sip_username, :sip_domain], unique: true
  end
end