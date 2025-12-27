Fabricator(:user_bonus) do
  user
  amount { 1000.0 }
  status { 'Active' }
  expires_at { 7.days.from_now }
end