class UserBonus < ApplicationRecord
  self.table_name = "user_bonuses"
  belongs_to :user

  def self.ransackable_attributes(auth_object = nil)
    ["amount", "created_at", "id", "status", "updated_at", "user_id"]
  end
end
