class PreMarket < ApplicationRecord
  belongs_to :fixture

  validates :market_identifier, presence: true
  #   validates :market_identifier, uniqueness: true
  validates :fixture_id, presence: true
  #   validates :fixture_id, uniqueness: true
  validates :fixture_id, uniqueness: { scope: %i[market_identifier specifier] }

  after_commit :broadcast_updates, if: :persisted?

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

  def broadcast_updates
    ## Create a fixture replica object
    # fixture = {"id": self.fixture_id}

    if saved_change_to_odds?
      # Add necessary odds and status to the fixture

      # Make the broadcasts
      ActionCable.server.broadcast(
        "pre_odds_#{self.market_identifier}_#{self.fixture_id}",
        self.as_json
      )
      ActionCable.server.broadcast(
        "betslips_#{self.market_identifier}_#{self.fixture_id}",
        self.as_json
      )
    end

    if saved_change_to_status?
      #Make the broadcast for market and betslip
      ActionCable.server.broadcast(
        "betslips_#{self.market_identifier}_#{self.fixture_id}",
        self.as_json
      )
      ActionCable.server.broadcast(
        "markets_#{self.market_identifier}_#{self.fixture_id}",
        self.as_json
      )
    end
  end
end
