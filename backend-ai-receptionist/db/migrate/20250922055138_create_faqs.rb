class CreateFaqs < ActiveRecord::Migration[8.0]
  def change
    create_table :faqs do |t|
      t.references :phone_number, null: false, foreign_key: true
      t.string :title
      t.text :content
      t.string :pdf_url
      t.string :website_url

      t.timestamps
    end
  end
end
