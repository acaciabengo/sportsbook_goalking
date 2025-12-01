Fabricator(:transaction) do
  user
  reference { SecureRandom.uuid }
  amount { rand(1000.0..50000.0).round(2) }
  phone_number { "2567#{rand(10000000..99999999)}" }
  currency { 'UGX' }
  status { 'PENDING' }
  category { 'Deposit' }
  balance_before { 0.0 }
  balance_after { |attrs| attrs[:balance_before] + attrs[:amount] }
  created_at { Time.current }
  updated_at { Time.current }
end