class Market < ApplicationRecord
   has_many :bets

   def self.ransackable_associations(auth_object = nil)
      ["bets"]
   end

   def self.ransackable_attributes(auth_object = nil)
      ["created_at", "ext_market_id", "id", "name", "sport_id", "updated_at"]
   end
end
