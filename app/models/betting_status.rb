class BettingStatus < ApplicationRecord

   validates :description, presence: true
   validates :betting_status_id, presence: true
   validates :betting_status_id, uniqueness: true

   def self.ransackable_attributes(auth_object = nil)
      ["betting_status_id", "created_at", "description", "id", "updated_at"]
   end
end
