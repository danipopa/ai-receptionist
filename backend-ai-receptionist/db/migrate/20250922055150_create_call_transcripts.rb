class CreateCallTranscripts < ActiveRecord::Migration[8.0]
  def change
    create_table :call_transcripts do |t|
      t.references :phone_number, null: false, foreign_key: true
      t.string :caller_id
      t.integer :call_duration
      t.text :transcript
      t.text :ai_response
      t.string :call_status
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
  end
end
