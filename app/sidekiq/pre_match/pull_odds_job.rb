class PreMatch::PullOddsJob
  include Sidekiq::Job
  sidekiq_options queue: :high, retry: 1

  def perform()
    # Find all fixtures that are not yet started or live
    Fixture
      .where(status: "not_started", fixture_status: ["not_started"])
      .find_in_batches(batch_size: 50)
      .each_batch do |fixtures|
        fixtures.each do |fixture|
          bet_balancer = BetBalancer.new
          odds_data = bet_balancer.get_matches(match_id: fixture.event_id)

          # Process odds_data as needed
          odds_data
            .xpath("//Match/MatchOdds/Bet")
            .each do |market|
              odds = {}
              ext_market_id = market["BetID"].to_i
              market
                .xpath("Odds")
                .each do |odd|
                  outcome = odd["OutCome"]
                  value = odd.content.to_f
                  odds[outcome] = value
                end
              # Find the pre-market by fixture and market identifier
              pre_market =
                PreMarket.find_by(
                  fixture_id: fixture.id,
                  market_identifier: ext_market_id
                )
              merged_odds = (pre_market.odds || {}).deep_merge(odds)
              if pre_market
                # Update the odds
                pre_market.update(odds: merged_odds)
              end
            end

          # check if it has FT results and close the fixture bets
          ft_result =
            odds_data.xpath(
              "//Match/Result/ScoreInfo/Score[@Type='FT']"
            ).content
          if ft_result.present?
            fixture.update(
              status: "finished",
              fixture_status: "finished",
              home_score: ft_result.split("-")[0].to_i,
              away_score: ft_result.split("-")[1].to_i
            )
          end
        end
      end
  end
end

# sample data structure
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
#       <MatchDate>2004-8-23T16:40:00</MatchDate>
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
#       <Player Id="17149" Name="Luís Fabiano" />
#     </Goal>
#   </Goals>
#   <Cards>
#     <Card Id="4199983" Time="42:00" Type="Yellow">
#       <Player Id="39586" Name="Petrovi, Radosav" />
#     </Card>
#     <Card Id="4200011" Time="45:00" Type="Yellow">
#       <Player Id="39584" Name="Lazic, Djordje" />
#     </Card>
#   </Cards>
# </Match>
