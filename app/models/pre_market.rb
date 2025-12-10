class PreMarket < ApplicationRecord
  belongs_to :fixture

  validates :market_identifier, presence: true
  #   validates :market_identifier, uniqueness: true
  validates :fixture_id, presence: true
  #   validates :fixture_id, uniqueness: true
  validates :fixture_id, uniqueness: { scope: %i[market_identifier specifier] }

  
  def self.ransackable_associations(auth_object = nil)
    ["fixture"]
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[
      created_at
      fixture_id
      id
      market_identifier
      name
      odds
      results
      specifier
      status
      updated_at
    ]
  end
end
