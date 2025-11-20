class Transaction < ApplicationRecord
  audited
  validates_length_of :phone_number, :is => 12, :message => "number should be 12 digits long."
  validates_format_of :phone_number, :with => /\A[256]/, :message => "number should start with 256."
  paginates_per 10

  belongs_to :user

  def self.ransackable_associations(auth_object = nil)
    ["audits", "user"]
  end

  def self.ransackable_attributes(auth_object = nil)
    ["amount", "balance_after", "balance_before", "category", "created_at", "currency", "id", "phone_number", "reference", "status", "updated_at", "user_id"]
  end
end
