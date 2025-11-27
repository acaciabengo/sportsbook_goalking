class PreMatch::PullSettlementsJob
  include Sidekiq::Job
  sidekiq_options queue: :high, retry: 1

  def perform()
    # Find markets of fixtures that are finished but not yet settled
    PreMarket
      .joins(:fixture)
      .where(fixtures: { match_status: "finished" }, status: "active")
      .find_in_batches(batch_size: 50)
      .each do |markets|
        markets.each do |market|
          # Logic to settle bets based on fixture results
          fixture = market.fixture
          bet_balancer = BetBalancer.new
          status, settlement_data =
            bet_balancer.get_matches(
              match_id: fixture.event_id,
              want_score: true
            )

          if status != 200 || settlement_data.nil?
            # puts "Failed to fetch settlement data for fixture #{fixture.id}"
            next
          end

          settlement_data.remove_namespaces!

          # puts "settlements data: #{settlement_data.to_xml}"
          results = {}
          settlement_data
            .xpath("//Match/BetResult/*")
            .each do |bet_result|
              # puts "found bet result: #{bet_result.to_xml}"
              status = bet_result.name # e.g., "W" or "L"
              specifier = bet_result["SpecialBetValue"]
              outcome_id = bet_result["OutComeId"]
              outcome = bet_result["OutCome"]
              results[outcome] = {
                "status" => status,
                "outcome_id" => outcome_id,
                "specifier" => specifier,
                "void_factor" => bet_result["VoidFactor"]
              }
            end

          existing_results = market.results.present? ? JSON.parse(market.results) : {}
          existing_results = existing_results.deep_transform_keys(&:to_s)
          merged_results = existing_results.deep_merge(results)
          market.update(results: merged_results, status: "settled")
          # puts "Settled market #{market.id} for fixture #{fixture.id}"

          # close settled bets
          # CloseSettledBetsWorker.perform_async(fixture.id, market.id, results)
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
