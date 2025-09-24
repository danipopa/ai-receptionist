class CreatePhoneNumbers < ActiveRecord::Migration[8.0]
  def change
    create_table :phone_numbers do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :number
      t.string :display_name
      t.text :description
      t.boolean :is_primary

      t.timestamps
    end
  end
end
