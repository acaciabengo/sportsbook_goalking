class Fixture < ApplicationRecord
  include PgSearch::Model

  before_create :set_sports, :set_category, :set_tournament

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
    %w[
      away_score
      booked
      category_name
      created_at
      event_id
      ext_category_id
      ext_provider_id
      ext_tournament_id
      featured
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
      tournament_name
      updated_at
    ]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[bets live_markets pre_markets]
  end

  def tournament_name
    Tournament.find_by(id: self.ext_tournament_id)&.name
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

  def set_sports
    if self.sport_id.present?
      sport = Sport.find_by(id: self.sport_id)
      if sport
        self.sport = sport.name
      end
    end
  end

  def set_category
    if self.ext_category_id.present?
      category = Category.find_by(id: self.ext_category_id)
      if category
        self.category_name = category.name
      end
    end
  end

  def set_tournament
    if self.ext_tournament_id.present?
      tournament = Tournament.find_by(id: self.ext_tournament_id)
      if tournament
        self.tournament_name = tournament.name
      end
    end
  end
end