class Fixture < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :global_search,
                  against: %i[part_one_name part_two_name league_name location],
                  using: {
                    tsearch: {
                      prefix: true
                    }
                  }

  FIXTURE_STATUSES = 
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
       ].freeze

  # { select_one: "", true: true, false: false }

  
  validates :event_id, presence: true
  validates :event_id, uniqueness: true

  has_many :pre_markets
  has_many :live_markets
  has_many :bets

  after_commit :broadcast_updates, if: :persisted?

  paginates_per 100

  def self.ransackable_attributes(auth_object = nil)
    ["away_score", "booked", "created_at", "event_id", "ext_category_id", "ext_provider_id", "ext_tournament_id", "featured", "home_score", "id", "league_id", "league_name", "live_odds", "location", "location_id", "match_status", "match_time", "part_one_id", "part_one_name", "part_two_id", "part_two_name", "priority", "season_id", "season_name", "sport", "sport_id", "start_date", "status", "tournament_round", "updated_at"]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[bets live_markets pre_markets]
  end

  def broadcast_updates
    ActionCable.server.broadcast(
      "fixture_#{self.id}_channel",
      self.as_json(
        only: %i[
          id
          event_id
          home_score
          away_score
          match_status
          start_date
          status
          match_time
        ]
      )
    )
  end
end
