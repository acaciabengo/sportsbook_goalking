class MatchStatus < ApplicationRecord

   validates :description, presence: true
   validates :match_status_id, presence: true
   validates :match_status_id, uniqueness: true

   def self.ransackable_attributes(auth_object = nil)
      ["created_at", "description", "id", "match_status_id", "sports", "updated_at"]
   end
end
