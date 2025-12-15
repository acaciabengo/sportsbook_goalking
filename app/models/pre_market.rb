class PreMarket < ApplicationRecord
  belongs_to :fixture

  validates :market_identifier, presence: true
  #   validates :market_identifier, uniqueness: true
  validates :fixture_id, presence: true
  #   validates :fixture_id, uniqueness: true
  validates :fixture_id, uniqueness: { scope: %i[market_identifier specifier] }

  before_save :adjust_odds_and_results

  
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

  # # adjust odds and results by replacing all placeholder keys with string versions
  # def adjust_odds_and_results
  #   if self.odds.present?
  #   #  if keys include {$competitor1} or {$competitor2}, replace them with string versions
  #   #  if includes {+hcp} or {-hcp}, replace them with string versions
  #   #  
  #     adjusted_odds = {}
  #     self.odds.each do |key, value|
  #       new_key = key.to_s
  #       adjusted_odds[new_key] = value
  #     end
  #     self.odds = adjusted_odds
  #   end

  #   if self.results.present?
     
  #   end
  # end
end
