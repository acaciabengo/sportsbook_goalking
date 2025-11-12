Fabricator(:user) do
  first_name { Faker::Name.first_name }
  last_name { Faker::Name.last_name }
  phone_number { sequence(:phone_number) { |i| "256#{700_000_000 + i}" } }
  email { sequence(:email) { |i| "user#{i}@example.com" } }
  password { "Password123!" }
  password_confirmation { "Password123!" }
  balance { 0.0 }
  bonus { 0.0 }
  pin { rand(1000..9999) }
  verified { true }
  account_active { true }
  agreement { true }
  nationality { "KE" }
  activated_signup_bonus { false }
  signup_bonus_amount { 0.0 }
  activated_first_deposit_bonus { false }
  first_deposit_bonus_amount { 0.0 }
  confirmed_at { Time.current }
end

# User with balance
Fabricator(:user_with_balance, from: :user) { balance { 1000.0 } }

# User with bonus
Fabricator(:user_with_bonus, from: :user) { bonus { 500.0 } }

# User with both balance and bonus
Fabricator(:funded_user, from: :user) do
  balance { 2000.0 }
  bonus { 1000.0 }
end

# Unverified user
Fabricator(:unverified_user, from: :user) do
  verified { false }
  pin_sent_at { Time.current }
end

# Locked user
Fabricator(:locked_user, from: :user) do
  locked_at { Time.current }
  failed_attempts { 5 }
end

# Inactive user
Fabricator(:inactive_user, from: :user) { account_active { false } }

# User with signup bonus
Fabricator(:user_with_signup_bonus, from: :user) do
  activated_signup_bonus { true }
  signup_bonus_amount { 100.0 }
  bonus { 100.0 }
end

# User with first deposit bonus
Fabricator(:user_with_first_deposit_bonus, from: :user) do
  activated_first_deposit_bonus { true }
  first_deposit_bonus_amount { 200.0 }
  bonus { 200.0 }
end

# User with both bonuses
Fabricator(:user_with_all_bonuses, from: :user) do
  activated_signup_bonus { true }
  signup_bonus_amount { 100.0 }
  activated_first_deposit_bonus { true }
  first_deposit_bonus_amount { 200.0 }
  bonus { 300.0 }
end

# User without agreement
Fabricator(:user_without_agreement, from: :user) { agreement { false } }

# User with ID number
Fabricator(:verified_user_with_id, from: :user) do
  id_number { "12345678" }
  verified { true }
  nationality { "KE" }
end

# VIP user (high balance)
Fabricator(:vip_user, from: :user) do
  balance { 100000.0 }
  bonus { 10000.0 }
  verified { true }
end

# New user (just registered)
Fabricator(:new_user, from: :user) do
  balance { 0.0 }
  bonus { 0.0 }
  sign_in_count { 0 }
  verified { false }
end

# Active bettor (has sign ins and balance)
Fabricator(:active_bettor, from: :user) do
  balance { 5000.0 }
  sign_in_count { 50 }
  last_sign_in_at { 1.day.ago }
  verified { true }
end

# User with email (optional field)
Fabricator(:user_with_email, from: :user) { email { Faker::Internet.email } }

# User needing password reset
Fabricator(:user_needing_password_reset, from: :user) do
  password_reset_code { rand(100_000..999_999) }
  password_reset_sent_at { Time.current }
end

# Confirmed user
Fabricator(:confirmed_user, from: :user) do
  confirmed_at { 1.week.ago }
  confirmation_token { nil }
end

# User with deposits
Fabricator(:user_with_deposits, from: :user) do
  balance { 5000.0 }
  after_create do |user|
    3.times { Fabricate(:deposit, user: user, status: "completed") }
  end
end

# User with bet slips
Fabricator(:user_with_bet_slips, from: :user) do
  balance { 1000.0 }
  after_create { |user| 5.times { Fabricate(:bet_slip, user: user) } }
end

# User with winning history
Fabricator(:winning_user, from: :user) do
  balance { 10000.0 }
  after_create do |user|
    3.times { Fabricate(:bet_slip, user: user, status: "won", result: "win") }
  end
end

# User with losing history
Fabricator(:losing_user, from: :user) do
  balance { 100.0 }
  after_create do |user|
    5.times { Fabricate(:bet_slip, user: user, status: "lost", result: "loss") }
  end
end

# Admin user (if using same table)
Fabricator(:admin_user, from: :user) do
  first_name { "Admin" }
  last_name { "User" }
  verified { true }
  account_active { true }
end

# Kenyan user
Fabricator(:kenyan_user, from: :user) do
  nationality { "KE" }
  phone_number { sequence(:phone_number) { |i| "254#{7_000_000_000 + i}" } }
end

# Ugandan user
Fabricator(:ugandan_user, from: :user) do
  nationality { "UG" }
  phone_number { sequence(:phone_number) { |i| "256#{7_000_000_000 + i}" } }
end

# Tanzanian user
Fabricator(:tanzanian_user, from: :user) do
  nationality { "TZ" }
  phone_number { sequence(:phone_number) { |i| "255#{7_000_000_000 + i}" } }
end

# User with specific phone number
Fabricator(:user_with_phone, from: :user) do
  transient :custom_phone
  phone_number { |attrs| attrs[:custom_phone] || "254712345678" }
end

# Suspended user
Fabricator(:suspended_user, from: :user) do
  account_active { false }
  locked_at { Time.current }
end
