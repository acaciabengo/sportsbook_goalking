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

ActiveRecord::Schema[7.2].define(version: 2026_01_13_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "role", default: "support"
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "api_users", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "api_id"
    t.string "api_key"
    t.boolean "registered", default: false
    t.string "user_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "audits", force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.jsonb "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at", precision: nil
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "bet_rejections", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "stake", precision: 15, scale: 2
    t.decimal "potential_win", precision: 15, scale: 2
    t.string "rejection_reason", null: false
    t.string "bet_type"
    t.integer "bet_count"
    t.jsonb "bet_data", default: []
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bet_type"], name: "index_bet_rejections_on_bet_type"
    t.index ["created_at"], name: "index_bet_rejections_on_created_at"
    t.index ["rejection_reason"], name: "index_bet_rejections_on_rejection_reason"
    t.index ["user_id", "created_at"], name: "index_bet_rejections_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_bet_rejections_on_user_id"
  end

  create_table "bet_slip_cancels", force: :cascade do |t|
    t.bigint "bet_slip_id", null: false
    t.string "status"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code"
    t.index ["bet_slip_id"], name: "index_bet_slip_cancels_on_bet_slip_id"
  end

  create_table "bet_slips", force: :cascade do |t|
    t.integer "bet_count"
    t.decimal "stake", precision: 12, scale: 2
    t.decimal "win_amount", precision: 12, scale: 2, default: "0.0"
    t.decimal "odds", precision: 10, scale: 2
    t.decimal "payout", precision: 12, scale: 2
    t.string "status"
    t.boolean "paid", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "result"
    t.string "reason"
    t.decimal "bonus", precision: 10, scale: 2
    t.decimal "tax", precision: 10, scale: 2
    t.string "bet_slip_status"
    t.string "bet_slip_result"
    t.decimal "cashout_value", precision: 10, scale: 2
    t.datetime "cashout_at"
    t.index ["cashout_at"], name: "index_bet_slips_on_cashout_at"
    t.index ["user_id"], name: "index_bet_slips_on_user_id"
  end

  create_table "bets", force: :cascade do |t|
    t.decimal "odds", precision: 5, scale: 2
    t.string "status"
    t.string "product"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "fixture_id", null: false
    t.bigint "bet_slip_id", null: false
    t.string "result"
    t.decimal "void_factor", precision: 5, scale: 2
    t.string "outcome_desc"
    t.string "specifier"
    t.string "outcome"
    t.string "market_identifier"
    t.string "sport"
    t.string "bet_type"
    t.jsonb "meta_data", default: {}
    t.index ["bet_slip_id"], name: "index_bets_on_bet_slip_id"
    t.index ["fixture_id"], name: "index_bets_on_fixture_id"
    t.index ["user_id"], name: "index_bets_on_user_id"
  end

  create_table "betstop_reasons", force: :cascade do |t|
    t.integer "betstop_reason_id"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "betting_statuses", force: :cascade do |t|
    t.integer "betting_status_id"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "broadcasts", force: :cascade do |t|
    t.string "subject"
    t.integer "contacts"
    t.string "message"
    t.datetime "execution_time", precision: nil
    t.bigint "admin_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status"
    t.datetime "start_date", precision: nil
    t.datetime "end_date", precision: nil
    t.index ["admin_id"], name: "index_broadcasts_on_admin_id"
  end

  create_table "carts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "categories", force: :cascade do |t|
    t.integer "ext_category_id"
    t.bigint "sport_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ext_category_id"], name: "index_categories_on_ext_category_id"
    t.index ["sport_id"], name: "index_categories_on_sport_id"
  end

  create_table "complaints", force: :cascade do |t|
    t.bigint "user_id"
    t.string "category"
    t.string "sub_category"
    t.bigint "bet_id"
    t.bigint "betslip_id"
    t.decimal "transaction_amount", precision: 12, scale: 2
    t.date "transaction_date"
    t.string "subject"
    t.text "description"
    t.string "preferred_contact_method"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bet_id"], name: "index_complaints_on_bet_id"
    t.index ["betslip_id"], name: "index_complaints_on_betslip_id"
    t.index ["category"], name: "index_complaints_on_category"
    t.index ["status"], name: "index_complaints_on_status"
  end

  create_table "crown_point_transactions", force: :cascade do |t|
    t.bigint "bet_slip_id", null: false
    t.bigint "user_id", null: false
    t.integer "points"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bet_slip_id"], name: "index_crown_point_transactions_on_bet_slip_id"
    t.index ["user_id"], name: "index_crown_point_transactions_on_user_id"
  end

  create_table "deposits", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2
    t.string "network"
    t.string "payment_method"
    t.decimal "balance_before", precision: 12, scale: 2
    t.decimal "balance_after", precision: 12, scale: 2
    t.string "ext_transaction_id"
    t.string "transaction_id"
    t.string "resource_id"
    t.string "receiving_fri"
    t.string "status"
    t.string "message"
    t.string "currency"
    t.string "phone_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "transaction_reference"
    t.index ["ext_transaction_id"], name: "index_deposits_on_ext_transaction_id", unique: true
    t.index ["phone_number"], name: "index_deposits_on_phone_number"
    t.index ["resource_id"], name: "index_deposits_on_resource_id", unique: true
    t.index ["transaction_id"], name: "index_deposits_on_transaction_id", unique: true
    t.index ["user_id"], name: "index_deposits_on_user_id"
  end

  create_table "fixtures", force: :cascade do |t|
    t.string "event_id"
    t.datetime "start_date", precision: nil
    t.string "live_odds"
    t.string "status"
    t.string "tournament_round"
    t.string "ext_provider_id"
    t.integer "season_id"
    t.string "season_name"
    t.string "league_id"
    t.string "league_name"
    t.string "sport_id"
    t.string "sport"
    t.string "location_id"
    t.string "location"
    t.string "part_one_id"
    t.string "part_one_name"
    t.string "part_two_id"
    t.string "part_two_name"
    t.string "home_score"
    t.string "away_score"
    t.string "match_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "booked", default: false
    t.string "priority"
    t.string "match_time"
    t.boolean "featured", default: false
    t.integer "ext_category_id", default: 0, null: false
    t.integer "ext_tournament_id", default: 0, null: false
    t.string "tournament_name"
    t.string "category_name"
    t.index ["booked"], name: "index_fixtures_on_booked"
    t.index ["event_id"], name: "index_fixtures_on_event_id", unique: true
    t.index ["location"], name: "index_fixtures_on_location"
    t.index ["location_id"], name: "index_fixtures_on_location_id"
    t.index ["match_status"], name: "index_fixtures_on_match_status"
    t.index ["sport"], name: "index_fixtures_on_sport"
    t.index ["sport_id"], name: "index_fixtures_on_sport_id"
    t.index ["start_date"], name: "index_fixtures_on_start_date"
    t.index ["status"], name: "index_fixtures_on_status"
  end

  create_table "line_bets", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.bigint "fixture_id", null: false
    t.decimal "odd", precision: 5, scale: 2
    t.string "description"
    t.string "market"
    t.string "outcome"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "market_identifier"
    t.string "specifier"
    t.string "sport"
    t.index ["cart_id"], name: "index_line_bets_on_cart_id"
    t.index ["fixture_id"], name: "index_line_bets_on_fixture_id"
  end

  create_table "live_markets", force: :cascade do |t|
    t.jsonb "odds"
    t.jsonb "results"
    t.string "status"
    t.string "market_identifier"
    t.bigint "fixture_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "specifier"
    t.string "name"
    t.index ["fixture_id", "market_identifier", "specifier"], name: "custom_index_on_live_markets", unique: true
    t.index ["fixture_id"], name: "index_live_markets_on_fixture_id"
  end

  create_table "market_alerts", force: :cascade do |t|
    t.bigint "timestamp"
    t.integer "product"
    t.integer "subscribed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "status", default: false
  end

  create_table "markets", force: :cascade do |t|
    t.integer "ext_market_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "sport_id", null: false
    t.index ["sport_id"], name: "index_markets_on_sport_id"
  end

  create_table "match_statuses", force: :cascade do |t|
    t.integer "match_status_id"
    t.string "description"
    t.string "sports", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "outcomes", force: :cascade do |t|
    t.string "outcome_id"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pre_markets", force: :cascade do |t|
    t.jsonb "odds"
    t.jsonb "results"
    t.string "status"
    t.string "market_identifier"
    t.bigint "fixture_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "specifier"
    t.string "name"
    t.index ["fixture_id", "market_identifier", "specifier"], name: "custom_index_on_pre_markets", unique: true
    t.index ["fixture_id"], name: "index_pre_markets_on_fixture_id"
  end

  create_table "recovery_requests", force: :cascade do |t|
    t.string "product"
    t.string "timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sign_up_bonuses", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2
    t.string "status"
    t.datetime "expiry", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "slip_bonuses", force: :cascade do |t|
    t.decimal "multiplier", precision: 5, scale: 2
    t.decimal "min_accumulator"
    t.decimal "max_accumulator"
    t.string "status"
    t.datetime "expiry", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sports", force: :cascade do |t|
    t.integer "ext_sport_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ext_sport_id"], name: "index_sports_on_ext_sport_id"
    t.index ["name"], name: "index_sports_on_name"
  end

  create_table "topup_bonuses", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2
    t.decimal "multiplier", precision: 5, scale: 2
    t.string "status"
    t.datetime "expiry", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tournaments", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.integer "ext_tournament_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "#<ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition"
    t.index ["category_id"], name: "index_tournaments_on_category_id"
    t.index ["ext_tournament_id"], name: "index_tournaments_on_ext_tournament_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.integer "user_id"
    t.string "category"
    t.integer "amount"
    t.string "reference"
    t.string "currency"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone_number"
    t.decimal "balance_before", precision: 12, scale: 2
    t.decimal "balance_after", precision: 12, scale: 2
  end

  create_table "user_bonuses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "amount", precision: 10, scale: 2
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "expires_at"
    t.index ["user_id"], name: "index_user_bonuses_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: ""
    t.string "phone_number", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.decimal "balance", precision: 10, scale: 2, default: "0.0"
    t.integer "pin"
    t.datetime "pin_sent_at", precision: nil
    t.boolean "verified", default: false
    t.integer "password_reset_code"
    t.datetime "password_reset_sent_at", precision: nil
    t.boolean "account_active", default: true
    t.boolean "agreement"
    t.string "nationality"
    t.string "id_number"
    t.boolean "activated_signup_bonus", default: false
    t.decimal "signup_bonus_amount", precision: 10, scale: 2, default: "0.0"
    t.boolean "activated_first_deposit_bonus", default: false
    t.decimal "first_deposit_bonus_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "bonus", precision: 10, scale: 2, default: "0.0"
    t.integer "points"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "void_reasons", force: :cascade do |t|
    t.integer "void_reason_id"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "withdraws", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2
    t.string "network"
    t.string "payment_method"
    t.decimal "balance_before", precision: 12, scale: 2
    t.decimal "balance_after", precision: 12, scale: 2
    t.string "ext_transaction_id"
    t.string "transaction_id"
    t.string "resource_id"
    t.string "receiving_fri"
    t.string "status"
    t.string "message"
    t.string "currency"
    t.string "phone_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "transaction_reference"
    t.index ["ext_transaction_id"], name: "index_withdraws_on_ext_transaction_id", unique: true
    t.index ["phone_number"], name: "index_withdraws_on_phone_number"
    t.index ["resource_id"], name: "index_withdraws_on_resource_id", unique: true
    t.index ["status"], name: "index_withdraws_on_status"
    t.index ["transaction_id"], name: "index_withdraws_on_transaction_id", unique: true
    t.index ["user_id"], name: "index_withdraws_on_user_id"
  end

  add_foreign_key "bet_rejections", "users"
  add_foreign_key "bet_slip_cancels", "bet_slips"
  add_foreign_key "bet_slips", "users"
  add_foreign_key "bets", "bet_slips"
  add_foreign_key "bets", "fixtures"
  add_foreign_key "bets", "users"
  add_foreign_key "broadcasts", "users", column: "admin_id"
  add_foreign_key "categories", "sports"
  add_foreign_key "crown_point_transactions", "bet_slips"
  add_foreign_key "crown_point_transactions", "users"
  add_foreign_key "deposits", "users"
  add_foreign_key "line_bets", "carts"
  add_foreign_key "line_bets", "fixtures"
  add_foreign_key "live_markets", "fixtures"
  add_foreign_key "markets", "sports"
  add_foreign_key "pre_markets", "fixtures"
  add_foreign_key "tournaments", "categories"
  add_foreign_key "user_bonuses", "users"
  add_foreign_key "withdraws", "users"
end
