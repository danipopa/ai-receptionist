class RefactorSipAuthentication < ActiveRecord::Migration[8.0]
  def change
    # Add connection mode to phone numbers to distinguish between:
    # 'trunk' = Direct SIP trunk (IP-based authentication)
    # 'register' = Outbound registration (username/password authentication)
    add_column :phone_numbers, :connection_mode, :string, default: 'trunk' unless column_exists?(:phone_numbers, :connection_mode)
    
    # Remove the index first to avoid constraint conflicts
    remove_index :customers, name: 'index_customers_on_sip_username_and_sip_domain' if index_exists?(:customers, [:sip_username, :sip_domain])
    
    # Remove unnecessary Customer SIP registration fields
    # Customers don't register TO our FreeSWITCH, they either:
    # 1. Send calls directly via SIP trunk, or
    # 2. We register TO their system
    remove_column :customers, :sip_username, :string if column_exists?(:customers, :sip_username)
    remove_column :customers, :sip_password, :string if column_exists?(:customers, :sip_password)
    remove_column :customers, :sip_domain, :string if column_exists?(:customers, :sip_domain)
    remove_column :customers, :sip_enabled, :boolean if column_exists?(:customers, :sip_enabled)
    remove_column :customers, :max_concurrent_calls, :integer if column_exists?(:customers, :max_concurrent_calls)
    
    # Add index for connection mode lookups
    add_index :phone_numbers, :connection_mode unless index_exists?(:phone_numbers, :connection_mode)
  end
end
