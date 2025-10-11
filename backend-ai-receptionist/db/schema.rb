# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_06_150605) do
  create_table "call_transcripts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "phone_number_id", null: false
    t.string "caller_id"
    t.integer "call_duration"
    t.text "transcript"
    t.text "ai_response"
    t.string "call_status"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["phone_number_id"], name: "index_call_transcripts_on_phone_number_id"
  end

  create_table "customers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone"
    t.string "company"
    t.text "address"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "faqs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "phone_number_id", null: false
    t.string "title"
    t.text "content"
    t.string "pdf_url"
    t.string "website_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "website_scanned_at"
    t.string "website_scan_status"
    t.string "website_content_hash"
    t.index ["phone_number_id"], name: "index_faqs_on_phone_number_id"
  end

  create_table "phone_numbers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "number"
    t.string "display_name"
    t.text "description"
    t.boolean "is_primary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "sip_trunk_enabled", default: false, null: false
    t.string "sip_trunk_host"
    t.integer "sip_trunk_port", default: 5060
    t.string "sip_trunk_username"
    t.string "sip_trunk_password"
    t.string "sip_trunk_domain"
    t.string "sip_trunk_protocol", default: "UDP"
    t.string "sip_trunk_context", default: "ai_receptionist"
    t.boolean "incoming_calls_enabled", default: true, null: false
    t.boolean "outbound_calls_enabled", default: false, null: false
    t.string "connection_mode", default: "trunk"
    t.index ["connection_mode"], name: "index_phone_numbers_on_connection_mode"
    t.index ["customer_id"], name: "index_phone_numbers_on_customer_id"
    t.index ["sip_trunk_enabled"], name: "index_phone_numbers_on_sip_trunk_enabled"
    t.index ["sip_trunk_username", "sip_trunk_domain"], name: "index_phone_numbers_on_sip_trunk_username_and_domain"
  end

  add_foreign_key "call_transcripts", "phone_numbers"
  add_foreign_key "faqs", "phone_numbers"
  add_foreign_key "phone_numbers", "customers"
end
