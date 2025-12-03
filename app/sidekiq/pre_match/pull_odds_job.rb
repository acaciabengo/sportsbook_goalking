class PreMatch::PullOddsJob
  include Sidekiq::Job
  sidekiq_options queue: :high, retry: 1

  def perform()
    # Find all fixtures that are not yet started or live
    Fixture
      .where(match_status: ["not_started"])
      .find_in_batches(batch_size: 50)
      .each do |fixtures|
        # Create BetBalancer instance once per batch to reuse HTTP connection
        bet_balancer = BetBalancer.new
        fixtures.each do |fixture|
          status, odds_data =
            bet_balancer.get_matches(match_id: fixture.event_id)
          odds_data.remove_namespaces!

          if status != 200
            Rails.logger.error(
              "Failed to fetch odds for fixture #{fixture.id} with event_id #{fixture.event_id}: Status #{status}"
            )
            next
          end

          # check fixture data
          fixture_node =
            odds_data.xpath(
              "//Match[@BetbalancerMatchID='#{fixture.event_id}']/Fixture"
            )
          if fixture_node
            status_info = fixture_node.xpath("StatusInfo/Off").text
            if status_info == "1"
              fixture.update(status: status_info)
            end
          end

          # Process odds_data as needed
          odds_data
            .xpath("//Match/MatchOdds/Bet")
            .each do |market|
              # new_odds = {}
              ext_market_id = market["OddsType"]&.to_i
              # Group odds by specifier
              odds_by_specifier = {}
              
              market.xpath("Odds").each do |odd|
                outcome = odd["OutCome"]
                outcome_id = odd["OutComeId"]&.to_i
                value = odd.text.to_f
                specifier = odd["SpecialBetValue"]
                
                # Initialize hash for this specifier if not exists
                odds_by_specifier[specifier] ||= {}
                
                # Store odds without specifier in the hash 
                odds_by_specifier[specifier][outcome] = {
                  "odd" => value,
                  "outcome_id" => outcome_id
                }.compact
              end

              # Create/update separate PreMarket for each specifier
              odds_by_specifier.each do |specifier, odds_hash|
                # Find the pre-market by fixture, market identifier, AND specifier
                pre_market = PreMarket.find_by(
                  fixture_id: fixture.id,
                  market_identifier: ext_market_id,
                  specifier: specifier
                )

                if pre_market
                  # Pre-market exists - update odds directly
                  unless pre_market.update(odds: odds_hash, status: "active")
                    Rails.logger.error(
                      "Failed to update pre-market #{pre_market.id} for fixture #{fixture.id}: #{pre_market.errors.full_messages.join(", ")}"
                    )
                  end
                else
                  # Pre-market doesn't exist - create new one
                  new_pre_market = PreMarket.create(
                    fixture_id: fixture.id,
                    market_identifier: ext_market_id,
                    specifier: specifier,
                    odds: odds_hash,
                    status: "active"
                  )

                  unless new_pre_market.persisted?
                    Rails.logger.error(
                      "Failed to create pre-market for fixture #{fixture.id}, market #{ext_market_id}, specifier #{specifier}: #{new_pre_market.errors.full_messages.join(", ")}"
                    )
                  end
                end
              end
            end

          # check if results exist in the match node
          results_node = odds_data.xpath("//Match/Result")
          next if results_node.empty?

          # extract full-time result
          ft_result = results_node.xpath("ScoreInfo/Score[@Type='FT']").text

          if ft_result.present?
            fixture.update(
              match_status: "finished",
              home_score: ft_result.split(":")[0].to_i,
              away_score: ft_result.split(":")[1].to_i
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


# 
# <Sport BetbalancerSportID="1">
#   <Texts>
#     <Text Language="BET"><Value>Soccer</Value></Text>
#     <Text Language="en"><Value>Soccer</Value></Text>
#     <Text Language="it"><Value>Calcio</Value></Text>
#   </Texts>
#   <Category BetbalancerCategoryID="1">
#     <Texts>
#       <Text Language="BET"><Value>England</Value></Text>
#       <Text Language="en"><Value>England</Value></Text>
#       <Text Language="it"><Value>Inghilterra</Value></Text>
#     </Texts>
#     <Tournament BetbalancerTournamentID="17">
#       <Texts>
#         <Text Language="BET"><Value>Premier League</Value></Text>
#         <Text Language="en"><Value>Premier League</Value></Text>
#         <Text Language="it"><Value>Premier League</Value></Text>
#       </Texts>
#       <Match BetbalancerMatchID="123456">
#         <Fixture>
#           <DateInfo>
#             <MatchDate>2025-11-24T15:00:00.000Z</MatchDate>
#           </DateInfo>
#           <StatusInfo>
#             <Off>0</Off>
#           </StatusInfo>
#           <Competitors>
#             <Texts>
#               <Text ID="4871">
#                 <Text Language="BET"><Value>Arsenal FC</Value></Text>
#                 <Text Language="en"><Value>Arsenal FC</Value></Text>
#                 <Text Language="it"><Value>Arsenal</Value></Text>
#               </Text>
#             </Texts>
#             <Texts>
#               <Text ID="4878">
#                 <Text Language="BET"><Value>Liverpool FC</Value></Text>
#                 <Text Language="en"><Value>Liverpool FC</Value></Text>
#                 <Text Language="it"><Value>Liverpool</Value></Text>
#               </Text>
#             </Texts>
#           </Competitors>
#         </Fixture>
#         <MatchOdds>
#           <Bet OddsType="1">
#             <Odds OutCome="1" OutcomeID="1">2.45</Odds>
#             <Odds OutCome="X" OutcomeID="2">3.20</Odds>
#             <Odds OutCome="2" OutcomeID="3">2.90</Odds>
#           </Bet>
#           <Bet OddsType="18">
#             <Odds OutCome="Over" OutcomeID="12" SpecialBetValue="2.5">1.85</Odds>
#             <Odds OutCome="Under" OutcomeID="13" SpecialBetValue="2.5">1.95</Odds>
#           </Bet>
#         </MatchOdds>
#       </Match>
#     </Tournament>
#   </Category>
# </Sport>

