# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180116214338) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "item_to_decom_table_mappings", force: :cascade do |t|
    t.integer "item_id", null: false
    t.integer "packet_config_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "value_type"
    t.integer "item_index"
    t.integer "table_index"
    t.boolean "reduced"
    t.index ["item_id", "packet_config_id", "value_type"], name: "mapping_unique", unique: true
  end

  create_table "items", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "packet_id"
    t.index ["packet_id", "name"], name: "index_items_on_packet_id_and_name", unique: true
  end

  create_table "packet_configs", force: :cascade do |t|
    t.integer "packet_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "ready", default: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.integer "first_system_config_id", null: false
    t.integer "max_table_index", default: -1
    t.index ["packet_id", "name"], name: "index_packet_configs_on_packet_id_and_name", unique: true
  end

  create_table "packet_log_entries", force: :cascade do |t|
    t.integer "target_id", null: false
    t.integer "packet_id", null: false
    t.datetime "time", null: false
    t.integer "packet_log_id", null: false
    t.bigint "data_offset", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "meta_id"
    t.boolean "is_tlm", null: false
    t.integer "decom_state", default: 0
    t.boolean "ready", default: false
    t.index ["is_tlm"], name: "index_packet_log_entries_on_is_tlm"
    t.index ["meta_id"], name: "index_packet_log_entries_on_meta_id"
    t.index ["packet_id"], name: "index_packet_log_entries_on_packet_id"
    t.index ["packet_log_id"], name: "index_packet_log_entries_on_packet_log_id"
    t.index ["ready"], name: "index_packet_log_entries_on_ready"
    t.index ["target_id"], name: "index_packet_log_entries_on_target_id"
    t.index ["time"], name: "index_packet_log_entries_on_time"
  end

  create_table "packet_logs", force: :cascade do |t|
    t.text "filename", null: false
    t.boolean "is_tlm", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["filename"], name: "index_packet_logs_on_filename", unique: true
  end

  create_table "packets", force: :cascade do |t|
    t.integer "target_id", null: false
    t.string "name", null: false
    t.boolean "is_tlm", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["target_id", "name", "is_tlm"], name: "index_packets_on_target_id_and_name_and_is_tlm", unique: true
  end

  create_table "system_configs", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_system_configs_on_name", unique: true
  end

  create_table "targets", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_targets_on_name", unique: true
  end

end
