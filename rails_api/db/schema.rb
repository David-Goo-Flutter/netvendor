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

ActiveRecord::Schema[8.1].define(version: 2026_09_10_234358) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "lookups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address", null: false
    t.string "mac_address", null: false
    t.jsonb "raw_response"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.string "vendor"
    t.index ["created_at"], name: "index_lookups_on_created_at"
    t.index ["mac_address"], name: "index_lookups_on_mac_address"
  end
end
