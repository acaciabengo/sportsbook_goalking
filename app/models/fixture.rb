class Fixture < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :global_search,
                  against: %i[part_one_name part_two_name league_name location],
                  using: {
                    tsearch: {
                      prefix: true
                    }
                  }

  enum :fixture_status,
       %i[
         not_started
         live
         finished
         cancelled
         interrupted
         postponed
         abandoned
         about_to_start
         coverage_lost
       ]

  enum :booking_status, { select_one: "", true: true, false: false }

  after_commit :broadcast_updates, if: :persisted?

  validates :event_id, presence: true
  validates :event_id, uniqueness: true

  has_many :pre_markets
  has_many :live_markets
  has_many :bets

  include BetBalancer

  paginates_per 100

  def self.ransackable_attributes(auth_object = nil)
    %w[
      away_score
      booked
      booking_status
      created_at
      event_id
      ext_provider_id
      featured
      fixture_status
      home_score
      id
      league_id
      league_name
      live_odds
      location
      location_id
      match_status
      match_time
      part_one_id
      part_one_name
      part_two_id
      part_two_name
      priority
      season_id
      season_name
      sport
      sport_id
      start_date
      status
      tournament_round
      updated_at
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[bets live_markets pre_markets]
  end

  def broadcast_updates
    #check if change was on status
    if saved_change_to_attribute?(:status)
      if self.status == "postponed" || self.status == "cancelled"
        bets = self.bets
        bets.update_all(
          status: "Closed",
          result: "Void",
          reason: "Fixture #{self.status}"
        )
      end
    end
    #check if match status is live and change was on either scores or match time
    if self.status == "live"
      if saved_change_to_attribute?(:home_score) ||
           saved_change_to_attribute?(:away_score) ||
           saved_change_to_attribute?(:match_time)
        fixture = { fixture_id: self.id }

        ## Add scores and match time to the fixture object
        fixture["home_score"] = self.home_score
        fixture["away_score"] = self.away_score
        fixture["match_time"] = self.match_time

        ## Broadcast the changes
        ActionCable.server.broadcast("fixtures_#{self.id}", fixture)
        # CableWorker.perform_async("fixtures_#{self.id}", fixture)
      end
    end
  end
end
