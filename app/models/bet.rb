class Bet < ApplicationRecord
  audited
  belongs_to :user
  belongs_to :fixture
  belongs_to :bet_slip
  # belongs_to :market

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
    ]
  end
end
