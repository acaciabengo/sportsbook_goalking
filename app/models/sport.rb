class Sport < ApplicationRecord
  has_many :categories, dependent: :destroy

  validates :name, presence: true
  validates :ext_sport_id, presence: true, uniqueness: true
  

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "ext_sport_id", "id", "name", "updated_at"]
  end

end
