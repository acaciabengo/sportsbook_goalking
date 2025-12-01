Fabricator(:deposit) do
  user
  amount { rand(1000.0..50000.0).round(2) }
  network { ['MTN', 'Airtel'].sample }
  payment_method { 'mobile_money' }
  balance_before { 0.0 }
  balance_after { |attrs| attrs[:balance_before] + attrs[:amount] }
  ext_transaction_id { "EXT#{SecureRandom.hex(8).upcase}" }
  transaction_id { "TXN#{SecureRandom.hex(8).upcase}" }
  resource_id { "RES#{SecureRandom.hex(8).upcase}" }
  receiving_fri { nil }
  status { 'PENDING' }
  message { nil }
  currency { 'UGX' }
  phone_number { "2567#{rand(10000000..99999999)}" }
  transaction_reference { SecureRandom.uuid }
  created_at { Time.current }
  updated_at { Time.current }
end