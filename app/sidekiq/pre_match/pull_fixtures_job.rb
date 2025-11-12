class PreMatch::PullFixturesJob
  include Sidekiq::Job
  sidekiq_options queue: :high, retry: 3

  ACCEPTED_SPORTS = [1].freeze

  def perform(*args)
    bet_balancer = BetBalancer.new

    # sports = Sport.select(:ext_sport_id).where(
    #   ext_sport_id: ACCEPTED_SPORTS
    # )

    ACCEPTED_SPORTS.each do |sport_id|
      fixtures_data = bet_balancer.get_matches(sport_id: sport_id)

      # Process fixtures_data as needed
      fixtures_data
        .xpath("//Category")
        .each do |category|
          category_id = category["BetbalancerCategoryID"].to_i
          category
            .xpath("//Tournament")
            .each do |tournament|
              tournament_id = tournament["BetbalancerTournamentID"].to_i

              tournament
                .xpath("Match")
                .each do |match|
                  # process_match data
                  process_match(
                    category_id: category_id,
                    tournament_id: tournament_id,
                    sport_id: sport_id,
                    match: match
                  )
                end
            end
        end
    end
  end

  def process_match(category_id:, tournament_id:, sport_id:, match:)
    event_id = match["BetbalancerMatchID"].to_i

    # Fix xpath - use relative paths without //
    fixture_date = match.at_xpath("Fixture/DateInfo/MatchDate")&.text
    return unless fixture_date

    start_date = fixture_date.to_datetime.strftime("%Y-%m-%d %H:%M:%S")
    status = match.at_xpath("Fixture/StatusInfo/Off")&.text || "1"

    part_one_node = match.at_xpath("Fixture/Competitors/Texts/Text[@Type='1']")
    part_one_id = part_one_node["ID"].to_i
    part_one_name = part_one_node.at_xpath("Value")&.text

    part_two_node = match.at_xpath("Fixture/Competitors/Texts/Text[@Type='2']")
    part_two_id = part_two_node["ID"].to_i
    part_two_name = part_two_node.at_xpath("Value")&.text

    unless Fixture.exists?(event_id: event_id)
      status == "0" ? "active" : "cancelled"
      fixture_status = status == "0" ? "not_started" : "cancelled"
      fixture =
        Fixture.new(
          event_id: event_id,
          sport_id: sport_id,
          ext_category_id: category_id,
          ext_tournament_id: tournament_id,
          start_date: start_date,
          match_status: status,
          part_one_id: part_one_id,
          part_one_name: part_one_name,
          part_two_id: part_two_id,
          part_two_name: part_two_name,
          fixture_status: fixture_status
        )

      unless fixture.save
        Rails.logger.error(
          "Failed to save fixture: #{fixture.errors.full_messages.join(", ")}"
        )
        return
      end

      match
        .xpath("MatchOdds/Bet")
        .each { |bet| process_odds(fixture_id: fixture.id, odds: bet) }
    end
  end

  def process_odds(fixture_id:, odds:)
    odds_data = {}

    # Now 'odds' is the Bet element, so we can get OddsType directly
    ext_market_id = odds["OddsType"].to_i
    # specifier = odds["SpecialBetValue"] # For markets like Over/Under 2.5

    odds
      .xpath("Odds")
      .each do |odd|
        outcome = odd["OutCome"]
        outcome_id = odd["OutcomeID"]&.to_i || nil
        value = odd.text.to_f
        specifier = odd["SpecialBetValue"] || nil
        odds_data[outcome] = {
          odd: value,
          outcome_id: outcome_id,
          specifier: specifier
        }
      end

    # Create pre-market for the fixture
    pre_market =
      PreMarket.new(
        fixture_id: fixture_id,
        market_identifier: ext_market_id,
        odds: odds_data&.transform_keys(&:to_s).to_json,
        status: "active"
      )

    unless pre_market.save
      Rails.logger.error "Failed to save pre-market for fixture #{fixture_id}, market #{ext_market_id}: #{pre_market.errors.full_messages.join(", ")}"
    end
  end
end

# # extract the odds
# odds = {}
# category
#   .xpath("Match/MatchOdds/Bet/Odds")
#   .each do |odd|
#     outcome = odd["OutCome"]
#     outcome_id = odd["OutcomeID"].to_i
#     value = odd.content.to_f
#     odds[outcome] = {
#       value: value,
#       outcome_id: outcome_id,
#       specifier: odd["SpecialBetValue "]
#     }
#   end

# ext_market_id = odd.parent["OddsType"].to_i

# # Create pre-market for the fixture if not exists
# pre_market =
#   PreMarket.new(
#     fixture_id: fixture.id,
#     market_identifier: ext_market_id,
#     odds: odds.to_json,
#     status: "active"
#   )

# if !pre_market.save
#   Rails.logger.error "Failed to save pre-market for fixture #{event_id}, market #{ext_market_id}: #{pre_market.errors.full_messages.join(", ")}"
# end
# end
