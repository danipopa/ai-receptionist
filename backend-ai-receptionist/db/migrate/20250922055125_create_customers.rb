class CreateCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :customers do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.string :company
      t.text :address
      t.text :notes

      t.timestamps
    end
  end
end
