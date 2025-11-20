class BetstopReason < ApplicationRecord

   validates :description, presence: true
   validates :betstop_reason_id, presence: true
   validates :betstop_reason_id, uniqueness: true

   def self.ransackable_attributes(auth_object = nil)
      ["betstop_reason_id", "created_at", "description", "id", "updated_at"]
   end
end
