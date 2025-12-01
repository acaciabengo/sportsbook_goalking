class Tournament < ApplicationRecord
  belongs_to :category

  def self.ransackable_attributes(auth_object = nil)
    ["#<ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition", "category_id", "created_at", "ext_tournament_id", "id", "name", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["category"]
  end
end
