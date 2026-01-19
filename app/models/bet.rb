class Bet < ApplicationRecord
  audited
  belongs_to :user
  belongs_to :fixture
  belongs_to :bet_slip
  # belongs_to :market
  
  # restrict bet_types to "PreMatch" or "Live"
  BET_TYPES = ["PreMatch", "Live"].freeze
  validates :bet_type, inclusion: { in: BET_TYPES }

  def market_name
    if bet_type == "PreMatch"
      Market.find_by(ext_market_id: market_identifier)&.name
    else
      LiveMarket.find_by(fixture_id: fixture_id, market_identifier: market_identifier, specifier: specifier)&.name
    end
  end

  def self.ransackable_attributes(auth_object = nil)
    %w[
      bet_slip_id
      created_at
      fixture_id
      id
      market_identifier
      odds
      outcome
      outcome_desc
      product
      reason
      result
      specifier
      sport
      status
      updated_at
      user_id
      void_factor
      bet_type
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    ["audits", "bet_slip", "fixture", "user"]
  end
end
