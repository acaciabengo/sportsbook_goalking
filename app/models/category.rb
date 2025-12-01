class Category < ApplicationRecord
  belongs_to :sport

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "ext_category_id", "id", "name", "sport_id", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["sport"]
  end
end
