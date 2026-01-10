class BetRejection < ApplicationRecord
  belongs_to :user

  validates :rejection_reason, presence: true
  validates :stake, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :potential_win, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :by_reason, ->(reason) { where(rejection_reason: reason) }
  scope :by_bet_type, ->(type) { where(bet_type: type) }
  scope :today, -> { where('created_at >= ?', Date.today.beginning_of_day) }
  scope :this_week, -> { where('created_at >= ?', 1.week.ago) }

  def self.ransackable_attributes(auth_object = nil)
    ["bet_count", "bet_type", "created_at", "id", "potential_win", "rejection_reason", "stake", "updated_at", "user_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["user"]
  end
end
