Fabricator(:slip_bonus) do
  min_accumulator { 2 }
  max_accumulator { 5 }
  multiplier { 10.0 }
  status { 'Active' }
  created_at { Time.current }
  updated_at { Time.current }
end

# Specific variants for different accumulator ranges
Fabricator(:slip_bonus_small, from: :slip_bonus) do
  min_accumulator { 2 }
  max_accumulator { 3 }
  multiplier { 5.0 }
end

Fabricator(:slip_bonus_medium, from: :slip_bonus) do
  min_accumulator { 4 }
  max_accumulator { 6 }
  multiplier { 10.0 }
end

Fabricator(:slip_bonus_large, from: :slip_bonus) do
  min_accumulator { 7 }
  max_accumulator { 10 }
  multiplier { 20.0 }
end

Fabricator(:slip_bonus_inactive, from: :slip_bonus) do
  status { 'Inactive' }
end