class LiveMarket < ApplicationRecord
  belongs_to :fixture

  validates :market_identifier, presence: true
#   validates :market_identifier, uniqueness: true
  validates :fixture_id, presence: true
#   validates :fixture_id, uniqueness: true
  validates :fixture_id, uniqueness: { scope: [:market_identifier, :specifier] }

  after_commit :broadcast_updates, if: :persisted?

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "fixture_id", "id", "market_identifier", "name", "odds", "results", "specifier", "status", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["fixture"]
  end

   
   
  def broadcast_updates
    # ## Create a fixture replica object
    # fixture = {"id": self.fixture_id}

    if saved_change_to_odds? || saved_change_to_status?
      # Make the broadcasts
      data = {
        id: self.id,
        fixture_id: self.fixture_id,
        market_identifier: self.market_identifier,
        specifier: self.specifier,
        name: self.name,
        odds: self.odds,
        results: self.results,
        status: self.status,
        updated_at: self.updated_at
      }

      ActionCable.server.broadcast("live_odds_#{self.market_identifier}_#{self.fixture_id}", data.as_json)
    end
  end
end
