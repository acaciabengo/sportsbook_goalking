class PreMatch::PullSettlementsJob
  include Sidekiq::Job
  sidekiq_options queue: :high, retry: 1

  def perform()
    # Find markets of fixtures that are finished but not yet settled
    Markets
      .join(:fixture)
      .where(fixtures: { status: "finished" }, markets: { status: "active" })
      .find_in_batches(batch_size: 50)
      .each_batch do |markets|
        markets.each do |market|
          # Logic to settle bets based on fixture results
          fixture = market.fixture
          bet_balancer = BetBalancer.new
          settlement_data =
            bet_balancer.get_matches(
              match_id: fixture.event_id,
              want_scores: true
            )
          results = {}
          settlement_data
            .xpath("//Match/BetResults/W")
            .each do |bet_result|
              odds_type = bet_result["OddsType"]
              specifier = bet_result["SpecialBetValue"]
              results[odds_type] = {
                outcome: bet_result["OutCome"],
                outcome_id: bet_result["OutComeID"],
                specifier: specifier,
                void_factor: bet_result["VoidFactor"],
                status: bet_result["Status"]
              }
            end

          merged_results = (market.results || {}).deep_merge(results)
          market.update(results: merged_results, status: "settled")

          # close settled bets
          CloseSettledBetsWorker.perform_async(
            fixture.id,
            market.id,
            results,
            specifier
          )
        end
      end
  end
end

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
