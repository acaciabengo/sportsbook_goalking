class PreMatch::PullFixturesJob
  include Sidekiq::Job
  sidekiq_options queue: :high, retry: 3

  ACCEPTED_SPORTS = [].freeze

  def perform(*args)
    bet_balancer = BetBalancer.new

    # sports = Sport.select(:ext_sport_id).where(
    #   ext_sport_id: ACCEPTED_SPORTS
    # )

    ACCEPTED_SPORTS.each do |sport_id|
      fixtures_data = bet_balancer.get_fixtures(sport_id: sport_id)

      # Process fixtures_data as needed
      fixtures_data
        .xpath("//Category")
        .each do |category|
          category_id = category["BetbalancerCategoryID"].to_i
          tournament_id = category["BetbalancerTournamentID"].to_i
          event_id = category.xpath("Match")["BetbalancerMatchID"].to_i
          fixture_date =
            category.xpath("Match/Fixture/DateInfo/MatchDate").content
          start_date fixture_date.to_datetime.strftime("%Y-%m-%d %H:%M:%S")
          status = category.xpath("Match/Fixture/StatusInfo/Off").content
          part_one_id =
            category.xpath("Match/Fixture/Competitors/Texts/Text[@Type='1']")[
              "ID"
            ].to_i
          part_one_name =
            category.xpath(
              "Match/Fixture/Competitors/Texts/Text[@Type='1']/Value"
            ).content
          part_two_id =
            category.xpath("Match/Fixture/Competitors/Texts/Text[@Type='2']")[
              "ID"
            ].to_i
          part_two_name =
            category.xpath(
              "Match/Fixture/Competitors/Texts/Text[@Type='2']/Value"
            ).content

          # Find the fixture by event_id if it does not exist, create it
          unless Fixture.exists?(event_id: event_id)
            fixture_status = status == "0" ? "cancelled" : "not_started"
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
          end

          if !fixture.save
            Rails.logger.error "Failed to save fixture #{event_id}: #{fixture.errors.full_messages.join(", ")}"
            next
          end

          # extract the odds
          odds = {}
          category
            .xpath("Match/MatchOdds/Bet/Odds")
            .each do |odd|
              outcome = odd["OutCome"]
              outcome_id = odd["OutcomeID"].to_i
              value = odd.content.to_f
              odds[outcome] = {
                value: value,
                outcome_id: outcome_id,
                specifier: odd["SpecialBetValue "]
              }
            end

          ext_market_id = odd.parent["OddsType"].to_i

          # Create pre-market for the fixture if not exists
          pre_market =
            PreMarket.new(
              fixture_id: fixture.id,
              market_identifier: ext_market_id,
              odds: odds.to_json,
              status: "active"
            )

          if !pre_market.save
            Rails.logger.error "Failed to save pre-market for fixture #{event_id}, market #{ext_market_id}: #{pre_market.errors.full_messages.join(", ")}"
          end
        end
    end
  end
end

# Example data
# <Match BetbalancerMatchID="109379">
#   <Fixture>
#     <Competitors>
#       <Texts>
#         <Text Type="1" ID="9373" SUPERID="9243">
#           <Value>1. FC BRNO</Value>
#         </Text>
#       </Texts>
#       <Texts>
#         <Text Type="2" ID="371400" SUPERID="1452">
#           <Value>FC SLOVACKO</Value>
#         </Text>
#       </Texts>
#     </Competitors>
#     <DateInfo>
#       <MatchDate>2004−8−23T16:40:00</MatchDate>
#     </DateInfo>
#     <StatusInfo>
#       <Off>0</Off>
#     </StatusInfo>
#     <HasStatistics>
#       <Value>1</Value>
#     </HasStatistics>
#     <NeutralGround>
#       <Value>0</Value>
#     </NeutralGround>
#   </Fixture>
#   <MatchOdds>
#     <Bet OddsType="10">
#       <Odds OutCome="1">2.15</Odds>
#       <Odds OutCome="X">2.85</Odds>
#       <Odds OutCome="2">2.9</Odds>
#     </Bet>
#   </MatchOdds>
#   <Result>
#     <ScoreInfo>
#       <Score Type="FT">1:0</Score>
#       <Score Type="HT">0:0</Score>
#     </ScoreInfo>
#     <Comment>
#       <Texts>
#         <Text>
#           <Value>1:0(62.)Luis Fabiano</Value>
#         </Text>
#       </Texts>
#     </Comment>
#   </Result>
#   <Goals>
#     <Goal Id="4199894" ScoringTeam="1" Team1="1" Team2="0" Time="62">
#       <Player Id="17149" Name="Luís Fabiano"/>
#     </Goal>
#   </Goals>
#   <Cards>
#     <Card Id="4199983" Time="42:00" Type="Yellow">
#       <Player Id="39586" Name="Petrovi, Radosav"/>
#     </Card>
#     <Card Id="4200011" Time="45:00" Type="Yellow">
#       <Player Id="39584" Name="Lazic, Djordje"/>
#     </Card>
#   </Cards>
# </Match>
