class Outcome < ApplicationRecord

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "description", "id", "outcome_id", "updated_at"]
  end
end
