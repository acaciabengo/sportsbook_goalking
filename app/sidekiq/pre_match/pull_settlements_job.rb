class PreMatch::PullSettlementsJob
  include Sidekiq::Job
  sidekiq_options queue: :high, retry: 1

  CHANNEL = 'live_feed_commands'

  def perform()
    # inititalize betbalancer
    @bet_balancer = BetBalancer.new

    # =============================================================
    # Find all fixtures with unsettled pre_markets for fixtures that are finished
    # =============================================================

    # Find fixtures that have unsettled pre_markets    
    sql = <<-SQL
      SELECT DISTINCT fixtures.id, fixtures.event_id
      FROM fixtures
      JOIN pre_markets ON pre_markets.fixture_id = fixtures.id
      WHERE fixtures.match_status IN ('finished', 'ended')
        AND pre_markets.status != 'settled'
      ORDER BY fixtures.id ASC
    SQL

    # Query in batches to avoid memory issues
    fixtures = ActiveRecord::Base.connection.exec_query(sql).to_a
    fixtures.each do |fixture|
      settle_pre_market(fixture)
    end

    # =============================================================
    # Find all fixtures with unsettled live_markets for fixtures that are finished
    # =============================================================

    sql = <<-SQL
      SELECT DISTINCT fixtures.id, fixtures.event_id
      FROM fixtures
        JOIN live_markets ON live_markets.fixture_id = fixtures.id
        WHERE fixtures.match_status IN ('finished', 'ended')
        AND live_markets.status != 'settled'
    SQL

    fixtures = ActiveRecord::Base.connection.exec_query(sql).to_a
    settle_live_market(fixtures)
  end

  def settle_pre_market(fixture)
    status, settlement_data = @bet_balancer.get_matches(match_id: fixture['event_id'], want_score: true)

    if status != 200 || settlement_data.nil?
      Rails.logger.error("Failed to fetch settlement data for fixture #{fixture['id']}")
      return
    end

    settlement_data.remove_namespaces!

    # Group by market_identifier
    markets_by_identifier = {}
    
    settlement_data
      .xpath("//Match/BetResult/*")
      .each do |bet_result|
        market_identifier = bet_result['OddsType'].to_i
        status = bet_result.name # e.g., "W" or "L"
        specifier = bet_result["SpecialBetValue"]
        outcome_id = bet_result["OutComeId"]
        outcome = bet_result["OutCome"]
        
        # Initialize hash for this market if not exists
        markets_by_identifier[market_identifier] ||= {}
        
        # Store this outcome in the market's results (keyed by outcome name)
        markets_by_identifier[market_identifier][outcome] = {
          "status" => status,
          "outcome_id" => outcome_id,
          "outcome" => outcome,
          "specifier" => specifier,
          "void_factor" => bet_result["VoidFactor"]
        }
      end

    # Process each market
    markets_by_identifier.each do |market_identifier, results|
      # Get the specifier from the first result (they should all have the same specifier for a given market)
      # first_result = results.values.first
      # specifier = first_result["specifier"]
      
      market = PreMarket.find_by(
        fixture_id: fixture['id'], 
        market_identifier: market_identifier
      )
      
      next if market.nil?

      existing_results = market.results || {}
      existing_results = existing_results.deep_transform_keys(&:to_s)
      merged_results = existing_results.deep_merge(results)
      
      market.update(results: merged_results, status: "settled")
      
      # close settled bets
      CloseSettledBetsJob.perform_async(fixture['id'], market.id, results, '')
    end
  end

  def settle_live_market(fixtures)
    fixtures.each_slice(10) do |fixture_batch|
      # construct XML request for this batch
      #  <BookmakerStatus timestamp="0">
      #   <Match matchid="661373" />
      # </BookmakerStatus>
      # 
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.BookmakerStatus(timestamp: '0', type: "current") {
          fixture_batch.each do |fixture|
            xml.Match(matchid: fixture["event_id"])
          end
        }
      end

      xml_request = builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION).strip

      # connect to redis and publish the request
      redis = Redis.new(url: ENV['REDIS_URL'])
      redis.publish(CHANNEL, xml_request)
    end
  end
end

# <?xml version="1.0" encoding="UTF-8"?>
# <BetbalancerBetData>
#   <Timestamp CreatedTime="2025-12-02T06:59:14.030Z" TimeZone="UTC" />
#   <Sports>
#     <Sport BetbalancerSportID="1">
#       <Texts>
#         <Text Language="BET">
#           <Value>Soccer</Value>
#         </Text>
#         <Text Language="en">
#           <Value>Soccer</Value>
#         </Text>
#         <Text Language="it">
#           <Value>Calcio</Value>
#         </Text>
#       </Texts>
#       <Category BetbalancerCategoryID="1">
#         <Texts>
#           <Text Language="BET">
#             <Value>England</Value>
#           </Text>
#           <Text Language="en">
#             <Value>England</Value>
#           </Text>
#           <Text Language="it">
#             <Value>Inghilterra</Value>
#           </Text>
#         </Texts>
#         <Tournament BetbalancerTournamentID="173">
#           <Texts>
#             <Text Language="BET">
#               <Value>National League</Value>
#             </Text>
#             <Text Language="en">
#               <Value>National League</Value>
#             </Text>
#             <Text Language="it">
#               <Value>National League</Value>
#             </Text>
#           </Texts>
#           <SuperTournament Name="National League" SuperID="173" />
#           <Match BetbalancerMatchID="61915630">
#             <Fixture>
#               <Competitors>
#                 <Texts>
#                   <Text ID="36467" SUPERID="36467" Type="1">
#                     <Text Language="BET">
#                       <Value>Boreham Wood FC</Value>
#                     </Text>
#                     <Text Language="en">
#                       <Value>Boreham Wood FC</Value>
#                     </Text>
#                     <Text Language="it">
#                       <Value>Boreham Wood FC</Value>
#                     </Text>
#                   </Text>
#                 </Texts>
#                 <Texts>
#                   <Text ID="87" SUPERID="87" Type="2">
#                     <Text Language="BET">
#                       <Value>Halifax Town</Value>
#                     </Text>
#                     <Text Language="en">
#                       <Value>Halifax Town</Value>
#                     </Text>
#                     <Text Language="it">
#                       <Value>Halifax Town</Value>
#                     </Text>
#                   </Text>
#                 </Texts>
#               </Competitors>
#               <DateInfo>
#                 <MatchDate Changed="0">2025-11-29T17:30:00.000Z</MatchDate>
#               </DateInfo>
#               <StatusInfo>
#                 <Off>1</Off>
#               </StatusInfo>
#               <NeutralGround>0</NeutralGround>
#             </Fixture>
#             <Result>
#               <ScoreInfo>
#                 <Score Type="FT">2:1</Score>
#                 <Score Type="HT">1:0</Score>
#                 <Score Type="2HT">1:1</Score>
#               </ScoreInfo>
#             </Result>
#             <Goals>
#               <Goal Id="-2087468442" ScoringTeam="1" Team1="1" Team2="0" Time="19">
#                 <Player Id="1869740" Name="Richardson, Lewis" />
#               </Goal>
#               <Goal Id="-2087382804" ScoringTeam="1" Team1="2" Team2="0" Time="67">
#                 <Player Id="868082" Name="Esteves de Sousa, Erico Henrique" />
#               </Goal>
#             </Goals>
#             <Cards>
#               <Card Id="-2087493450" Time="2:00" Type="Yellow">
#                 <Player Id="1125775" Name="White, Tom" TeamId="36467" />
#               </Card>
#               <Card Id="-2087439150" Time="41:00" Type="Yellow">
#                 <Player Id="2156080" Name="O&amp;#39;Connell, Charlie" TeamId="36467" />
#               </Card>
#             </Cards>
#             <Corners>
#               <CornerCount Team="Home" Type="1st Half">4</CornerCount>
#               <CornerCount Team="Away" Type="1st Half">1</CornerCount>
#               <CornerCount Team="Home" Type="2nd Half">3</CornerCount>
#               <CornerCount Team="Away" Type="2nd Half">4</CornerCount>
#               <CornerCount Team="Home" Type="FT">7</CornerCount>
#               <CornerCount Team="Away" Type="FT">5</CornerCount>
#             </Corners>
#             <BetResult>
#               <W OddsType="1" OutComeId="1" OutCome="{$competitor1}" />
#               <W OddsType="8" OutComeId="6" OutCome="{$competitor1}" variant="goalnr=1" />
#               <W OddsType="9" OutComeId="8" OutCome="{$competitor2}" />
#               <W OddsType="10" OutComeId="9" OutCome="{$competitor1} or draw" />
#               <W OddsType="10" OutComeId="10" OutCome="{$competitor1} or {$competitor2}" />
#               <W OddsType="11" OutComeId="4" OutCome="{$competitor1}" />
#               <W OddsType="12" OutComeId="776" OutCome="C" Reason="NO_RESULT_ASSIGNABLE" />
#               <W OddsType="12" OutComeId="778" OutCome="C" Reason="NO_RESULT_ASSIGNABLE" />
#               <W OddsType="13" OutComeId="780" OutCome="{$competitor1}" />
#               <W OddsType="14" OutComeId="1711" OutCome="{$competitor1} ({hcp})" SpecialBetValue="1:0" />
#               <W OddsType="14" OutComeId="1711" OutCome="{$competitor1} ({hcp})" SpecialBetValue="2:0" />
#               <W OddsType="14" OutComeId="1711" OutCome="{$competitor1} ({hcp})" SpecialBetValue="3:0" />
#               <W OddsType="14" OutComeId="1712" OutCome="draw ({hcp})" SpecialBetValue="0:1" />
#               <W OddsType="14" OutComeId="1713" OutCome="{$competitor2} ({hcp})" SpecialBetValue="0:2" />
#               <W OddsType="14" OutComeId="1713" OutCome="{$competitor2} ({hcp})" SpecialBetValue="0:3" />
#               <W OddsType="14" OutComeId="1713" OutCome="{$competitor2} ({hcp})" SpecialBetValue="0:4" />
#               <W OddsType="14" OutComeId="1713" OutCome="{$competitor2} ({hcp})" SpecialBetValue="0:5" />
#               <W OddsType="14" OutComeId="1713" OutCome="{$competitor2} ({hcp})" SpecialBetValue="0:6" />
#               <W OddsType="15" OutComeId="113" OutCome="{$competitor1} by 1" variant="variant=sr:winning_margin:3+" />
#               <W OddsType="16" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-0.25" />
#               <W OddsType="16" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-0.5" />
#               <W OddsType="16" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-0.75" VoidFactor="0.5" Status="W" />
#               <W OddsType="16" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-1" VoidFactor="1.0" />
#               <W OddsType="16" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-1.25" VoidFactor="0.5" Status="L" />
#               <W OddsType="16" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="0" />
#               <W OddsType="16" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="0.25" />
#               <W OddsType="16" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="0.5" />
#               <W OddsType="16" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="0.75" />
#               <W OddsType="16" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-0.75" VoidFactor="0.5" Status="L" />
#               <W OddsType="16" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-1" VoidFactor="1.0" />
#               <W OddsType="16" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-1.25" VoidFactor="0.5" Status="W" />
#               <W OddsType="16" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-1.5" />
#               <W OddsType="16" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-1.75" />
#               <W OddsType="16" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-2" />
#               <W OddsType="16" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-2.25" />
#               <W OddsType="16" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-2.5" />
#               <W OddsType="16" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-2.75" />
#               <W OddsType="16" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-3" />
#               <W OddsType="18" OutComeId="12" OutCome="over {total}" SpecialBetValue="0.5" />
#               <W OddsType="18" OutComeId="12" OutCome="over {total}" SpecialBetValue="0.75" />
#               <W OddsType="18" OutComeId="12" OutCome="over {total}" SpecialBetValue="1" />
#               <W OddsType="18" OutComeId="12" OutCome="over {total}" SpecialBetValue="1.25" />
#               <W OddsType="18" OutComeId="12" OutCome="over {total}" SpecialBetValue="1.5" />
#               <W OddsType="18" OutComeId="12" OutCome="over {total}" SpecialBetValue="1.75" />
#               <W OddsType="18" OutComeId="12" OutCome="over {total}" SpecialBetValue="2" />
#               <W OddsType="18" OutComeId="12" OutCome="over {total}" SpecialBetValue="2.25" />
#               <W OddsType="18" OutComeId="12" OutCome="over {total}" SpecialBetValue="2.5" />
#               <W OddsType="18" OutComeId="12" OutCome="over {total}" SpecialBetValue="2.75" VoidFactor="0.5" Status="W" />
#               <W OddsType="18" OutComeId="12" OutCome="over {total}" SpecialBetValue="3" VoidFactor="1.0" />
#               <W OddsType="18" OutComeId="12" OutCome="over {total}" SpecialBetValue="3.25" VoidFactor="0.5" Status="L" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="2.75" VoidFactor="0.5" Status="L" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="3" VoidFactor="1.0" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="3.25" VoidFactor="0.5" Status="W" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="3.5" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="3.75" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="4" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="4.25" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="4.5" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="4.75" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="5" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="5.25" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="5.5" />
#               <W OddsType="18" OutComeId="13" OutCome="under {total}" SpecialBetValue="5.75" />
#               <W OddsType="19" OutComeId="12" OutCome="over {total}" SpecialBetValue="0.5" />
#               <W OddsType="19" OutComeId="12" OutCome="over {total}" SpecialBetValue="1.5" />
#               <W OddsType="19" OutComeId="13" OutCome="under {total}" SpecialBetValue="2.5" />
#               <W OddsType="19" OutComeId="13" OutCome="under {total}" SpecialBetValue="3.5" />
#               <W OddsType="19" OutComeId="13" OutCome="under {total}" SpecialBetValue="4.5" />
#               <W OddsType="20" OutComeId="12" OutCome="over {total}" SpecialBetValue="0.5" />
#               <W OddsType="20" OutComeId="13" OutCome="under {total}" SpecialBetValue="1.5" />
#               <W OddsType="20" OutComeId="13" OutCome="under {total}" SpecialBetValue="2.5" />
#               <W OddsType="20" OutComeId="13" OutCome="under {total}" SpecialBetValue="3.5" />
#               <W OddsType="21" OutComeId="71" OutCome="3" variant="variant=sr:exact_goals:6+" />
#               <W OddsType="21" OutComeId="1339" OutCome="3" variant="variant=sr:exact_goals:5+" />
#               <W OddsType="23" OutComeId="90" OutCome="2" variant="variant=sr:exact_goals:3+" />
#               <W OddsType="24" OutComeId="89" OutCome="1" variant="variant=sr:exact_goals:3+" />
#               <W OddsType="25" OutComeId="1122" OutCome="2-3" variant="variant=sr:point_range:6+" />
#               <W OddsType="25" OutComeId="1343" OutCome="2-3" variant="variant=sr:goal_range:7+" />
#               <W OddsType="26" OutComeId="70" OutCome="odd" />
#               <W OddsType="27" OutComeId="72" OutCome="even" />
#               <W OddsType="28" OutComeId="70" OutCome="odd" />
#               <W OddsType="29" OutComeId="74" OutCome="yes" />
#               <W OddsType="30" OutComeId="792" OutCome="both teams" />
#               <W OddsType="31" OutComeId="76" OutCome="no" />
#               <W OddsType="32" OutComeId="76" OutCome="no" />
#               <W OddsType="33" OutComeId="76" OutCome="no" />
#               <W OddsType="34" OutComeId="76" OutCome="no" />
#               <W OddsType="35" OutComeId="78" OutCome="{$competitor1} &amp; yes" />
#               <W OddsType="36" OutComeId="90" OutCome="over {total} &amp; yes" SpecialBetValue="2.5" />
#               <W OddsType="37" OutComeId="794" OutCome="{$competitor1} &amp; under {total}" SpecialBetValue="3.5" />
#               <W OddsType="37" OutComeId="794" OutCome="{$competitor1} &amp; under {total}" SpecialBetValue="4.5" />
#               <W OddsType="37" OutComeId="796" OutCome="{$competitor1} &amp; over {total}" SpecialBetValue="1.5" />
#               <W OddsType="37" OutComeId="796" OutCome="{$competitor1} &amp; over {total}" SpecialBetValue="2.5" />
#               <W OddsType="41" OutComeId="130" OutCome="2:1" variant="score=0:0" />
#               <W OddsType="45" OutComeId="288" OutCome="2:1" />
#               <W OddsType="46" OutComeId="382" OutCome="1:0 2:1" />
#               <W OddsType="47" OutComeId="418" OutCome="{$competitor1}/{$competitor1}" />
#               <W OddsType="48" OutComeId="76" OutCome="no" />
#               <W OddsType="49" OutComeId="76" OutCome="no" />
#               <W OddsType="50" OutComeId="74" OutCome="yes" />
#               <W OddsType="51" OutComeId="76" OutCome="no" />
#               <W OddsType="52" OutComeId="438" OutCome="2nd half" />
#               <W OddsType="53" OutComeId="440" OutCome="equal" />
#               <W OddsType="54" OutComeId="438" OutCome="2nd half" />
#               <W OddsType="55" OutComeId="812" OutCome="no/yes" />
#               <W OddsType="56" OutComeId="74" OutCome="yes" />
#               <W OddsType="57" OutComeId="76" OutCome="no" />
#               <W OddsType="58" OutComeId="76" OutCome="no" SpecialBetValue="1.5" />
#               <W OddsType="59" OutComeId="76" OutCome="no" SpecialBetValue="1.5" />
#               <W OddsType="60" OutComeId="1" OutCome="{$competitor1}" />
#               <W OddsType="62" OutComeId="6" OutCome="{$competitor1}" variant="goalnr=1" />
#               <W OddsType="63" OutComeId="9" OutCome="{$competitor1} or draw" />
#               <W OddsType="63" OutComeId="10" OutCome="{$competitor1} or {$competitor2}" />
#               <W OddsType="64" OutComeId="4" OutCome="{$competitor1}" />
#               <W OddsType="65" OutComeId="1711" OutCome="{$competitor1} ({hcp})" SpecialBetValue="1:0" />
#               <W OddsType="65" OutComeId="1712" OutCome="draw ({hcp})" SpecialBetValue="0:1" />
#               <W OddsType="65" OutComeId="1713" OutCome="{$competitor2} ({hcp})" SpecialBetValue="0:2" />
#               <W OddsType="65" OutComeId="1713" OutCome="{$competitor2} ({hcp})" SpecialBetValue="0:3" />
#               <W OddsType="66" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-0.25" />
#               <W OddsType="66" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-0.5" />
#               <W OddsType="66" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-0.75" VoidFactor="0.5" Status="W" />
#               <W OddsType="66" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-1" VoidFactor="1.0" />
#               <W OddsType="66" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-1.25" VoidFactor="0.5" Status="L" />
#               <W OddsType="66" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="0" />
#               <W OddsType="66" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="0.25" />
#               <W OddsType="66" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="0.5" />
#               <W OddsType="66" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-0.75" VoidFactor="0.5" Status="L" />
#               <W OddsType="66" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-1" VoidFactor="1.0" />
#               <W OddsType="66" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-1.25" VoidFactor="0.5" Status="W" />
#               <W OddsType="66" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-1.5" />
#               <W OddsType="68" OutComeId="12" OutCome="over {total}" SpecialBetValue="0.5" />
#               <W OddsType="68" OutComeId="12" OutCome="over {total}" SpecialBetValue="0.75" VoidFactor="0.5" Status="W" />
#               <W OddsType="68" OutComeId="12" OutCome="over {total}" SpecialBetValue="1" VoidFactor="1.0" />
#               <W OddsType="68" OutComeId="12" OutCome="over {total}" SpecialBetValue="1.25" VoidFactor="0.5" Status="L" />
#               <W OddsType="68" OutComeId="13" OutCome="under {total}" SpecialBetValue="0.75" VoidFactor="0.5" Status="L" />
#               <W OddsType="68" OutComeId="13" OutCome="under {total}" SpecialBetValue="1" VoidFactor="1.0" />
#               <W OddsType="68" OutComeId="13" OutCome="under {total}" SpecialBetValue="1.25" VoidFactor="0.5" Status="W" />
#               <W OddsType="68" OutComeId="13" OutCome="under {total}" SpecialBetValue="1.5" />
#               <W OddsType="68" OutComeId="13" OutCome="under {total}" SpecialBetValue="1.75" />
#               <W OddsType="68" OutComeId="13" OutCome="under {total}" SpecialBetValue="2" />
#               <W OddsType="68" OutComeId="13" OutCome="under {total}" SpecialBetValue="2.25" />
#               <W OddsType="68" OutComeId="13" OutCome="under {total}" SpecialBetValue="2.5" />
#               <W OddsType="68" OutComeId="13" OutCome="under {total}" SpecialBetValue="2.75" />
#               <W OddsType="68" OutComeId="13" OutCome="under {total}" SpecialBetValue="3" />
#               <W OddsType="69" OutComeId="12" OutCome="over {total}" SpecialBetValue="0.5" />
#               <W OddsType="69" OutComeId="13" OutCome="under {total}" SpecialBetValue="1.5" />
#               <W OddsType="69" OutComeId="13" OutCome="under {total}" SpecialBetValue="2.5" />
#               <W OddsType="70" OutComeId="13" OutCome="under {total}" SpecialBetValue="0.5" />
#               <W OddsType="70" OutComeId="13" OutCome="under {total}" SpecialBetValue="1.5" />
#               <W OddsType="71" OutComeId="86" OutCome="1" variant="variant=sr:exact_goals:2+" />
#               <W OddsType="71" OutComeId="89" OutCome="1" variant="variant=sr:exact_goals:3+" />
#               <W OddsType="74" OutComeId="70" OutCome="odd" />
#               <W OddsType="75" OutComeId="76" OutCome="no" />
#               <W OddsType="76" OutComeId="74" OutCome="yes" />
#               <W OddsType="77" OutComeId="76" OutCome="no" />
#               <W OddsType="78" OutComeId="80" OutCome="{$competitor1} &amp; no" />
#               <W OddsType="79" OutComeId="794" OutCome="{$competitor1} &amp; under {total}" SpecialBetValue="1.5" />
#               <W OddsType="81" OutComeId="468" OutCome="1:0" />
#               <W OddsType="83" OutComeId="2" OutCome="draw" />
#               <W OddsType="84" OutComeId="6" OutCome="{$competitor1}" variant="goalnr=1" />
#               <W OddsType="85" OutComeId="9" OutCome="{$competitor1} or draw" />
#               <W OddsType="85" OutComeId="11" OutCome="draw or {$competitor2}" />
#               <W OddsType="86" OutComeId="4" OutCome="C" Reason="NO_RESULT_ASSIGNABLE" />
#               <W OddsType="86" OutComeId="5" OutCome="C" Reason="NO_RESULT_ASSIGNABLE" />
#               <W OddsType="87" OutComeId="1711" OutCome="{$competitor1} ({hcp})" SpecialBetValue="1:0" />
#               <W OddsType="87" OutComeId="1713" OutCome="{$competitor2} ({hcp})" SpecialBetValue="0:1" />
#               <W OddsType="87" OutComeId="1713" OutCome="{$competitor2} ({hcp})" SpecialBetValue="0:2" />
#               <W OddsType="87" OutComeId="1713" OutCome="{$competitor2} ({hcp})" SpecialBetValue="0:3" />
#               <W OddsType="88" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-0.25" VoidFactor="0.5" Status="L" />
#               <W OddsType="88" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="0" VoidFactor="1.0" />
#               <W OddsType="88" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="0.25" VoidFactor="0.5" Status="W" />
#               <W OddsType="88" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="0.5" />
#               <W OddsType="88" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-0.25" VoidFactor="0.5" Status="W" />
#               <W OddsType="88" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-0.5" />
#               <W OddsType="88" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-0.75" />
#               <W OddsType="88" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-1" />
#               <W OddsType="88" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-1.25" />
#               <W OddsType="88" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-1.5" />
#               <W OddsType="88" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-1.75" />
#               <W OddsType="88" OutComeId="1715" OutCome="{$competitor2} ({-hcp})" SpecialBetValue="0" VoidFactor="1.0" />
#               <W OddsType="88" OutComeId="1715" OutCome="{$competitor2} ({-hcp})" SpecialBetValue="0.25" VoidFactor="0.5" Status="L" />
#               <W OddsType="90" OutComeId="12" OutCome="over {total}" SpecialBetValue="0.5" />
#               <W OddsType="90" OutComeId="12" OutCome="over {total}" SpecialBetValue="0.75" />
#               <W OddsType="90" OutComeId="12" OutCome="over {total}" SpecialBetValue="1" />
#               <W OddsType="90" OutComeId="12" OutCome="over {total}" SpecialBetValue="1.25" />
#               <W OddsType="90" OutComeId="12" OutCome="over {total}" SpecialBetValue="1.5" />
#               <W OddsType="90" OutComeId="12" OutCome="over {total}" SpecialBetValue="1.75" VoidFactor="0.5" Status="W" />
#               <W OddsType="90" OutComeId="12" OutCome="over {total}" SpecialBetValue="2" VoidFactor="1.0" />
#               <W OddsType="90" OutComeId="12" OutCome="over {total}" SpecialBetValue="2.25" VoidFactor="0.5" Status="L" />
#               <W OddsType="90" OutComeId="13" OutCome="under {total}" SpecialBetValue="1.75" VoidFactor="0.5" Status="L" />
#               <W OddsType="90" OutComeId="13" OutCome="under {total}" SpecialBetValue="2" VoidFactor="1.0" />
#               <W OddsType="90" OutComeId="13" OutCome="under {total}" SpecialBetValue="2.25" VoidFactor="0.5" Status="W" />
#               <W OddsType="90" OutComeId="13" OutCome="under {total}" SpecialBetValue="2.5" />
#               <W OddsType="90" OutComeId="13" OutCome="under {total}" SpecialBetValue="2.75" />
#               <W OddsType="90" OutComeId="13" OutCome="under {total}" SpecialBetValue="3" />
#               <W OddsType="91" OutComeId="12" OutCome="over {total}" SpecialBetValue="0.5" />
#               <W OddsType="91" OutComeId="13" OutCome="under {total}" SpecialBetValue="1.5" />
#               <W OddsType="91" OutComeId="13" OutCome="under {total}" SpecialBetValue="2.5" />
#               <W OddsType="92" OutComeId="12" OutCome="over {total}" SpecialBetValue="0.5" />
#               <W OddsType="92" OutComeId="13" OutCome="under {total}" SpecialBetValue="1.5" />
#               <W OddsType="92" OutComeId="13" OutCome="under {total}" SpecialBetValue="2.5" />
#               <W OddsType="93" OutComeId="87" OutCome="2+" variant="variant=sr:exact_goals:2+" />
#               <W OddsType="94" OutComeId="72" OutCome="even" />
#               <W OddsType="95" OutComeId="74" OutCome="yes" />
#               <W OddsType="96" OutComeId="76" OutCome="no" />
#               <W OddsType="97" OutComeId="76" OutCome="no" />
#               <W OddsType="98" OutComeId="554" OutCome="1:1" />
#               <W OddsType="100" OutComeId="586" OutCome="16-30" variant="goalnr=1" />
#               <W OddsType="101" OutComeId="600" OutCome="11-20" variant="goalnr=1" />
#               <W OddsType="105" OutComeId="2" OutCome="draw" variant="from=1|to=10" />
#               <W OddsType="184" OutComeId="814" OutCome="{$competitor1} goal &amp; {$competitor1}" variant="goalnr=1" />
#               <W OddsType="199" OutComeId="1317" OutCome="2:1" variant="variant=sr:correct_score:max:6" />
#               <W OddsType="199" OutComeId="1483" OutCome="2:1" variant="variant=sr:correct_score:below:5-5" />
#               <W OddsType="540" OutComeId="1719" OutCome="{$competitor1}/draw &amp; no" />
#               <W OddsType="540" OutComeId="1721" OutCome="{$competitor1}/{$competitor2} &amp; no" />
#               <W OddsType="541" OutComeId="1718" OutCome="{$competitor1}/draw &amp; yes" />
#               <W OddsType="541" OutComeId="1720" OutCome="{$competitor1}/{$competitor2} &amp; yes" />
#               <W OddsType="542" OutComeId="1719" OutCome="{$competitor1}/draw &amp; no" />
#               <W OddsType="542" OutComeId="1721" OutCome="{$competitor1}/{$competitor2} &amp; no" />
#               <W OddsType="543" OutComeId="82" OutCome="draw &amp; yes" />
#               <W OddsType="544" OutComeId="800" OutCome="draw &amp; over {total}" SpecialBetValue="1.5" />
#               <W OddsType="545" OutComeId="1718" OutCome="{$competitor1}/draw &amp; yes" />
#               <W OddsType="545" OutComeId="1722" OutCome="draw/{$competitor2} &amp; yes" />
#               <W OddsType="546" OutComeId="1718" OutCome="{$competitor1}/draw &amp; yes" />
#               <W OddsType="546" OutComeId="1720" OutCome="{$competitor1}/{$competitor2} &amp; yes" />
#               <W OddsType="547" OutComeId="1724" OutCome="{$competitor1}/draw &amp; under {total}" SpecialBetValue="3.5" />
#               <W OddsType="547" OutComeId="1724" OutCome="{$competitor1}/draw &amp; under {total}" SpecialBetValue="4.5" />
#               <W OddsType="547" OutComeId="1725" OutCome="{$competitor1}/{$competitor2} &amp; under {total}" SpecialBetValue="3.5" />
#               <W OddsType="547" OutComeId="1725" OutCome="{$competitor1}/{$competitor2} &amp; under {total}" SpecialBetValue="4.5" />
#               <W OddsType="547" OutComeId="1727" OutCome="{$competitor1}/draw &amp; over {total}" SpecialBetValue="1.5" />
#               <W OddsType="547" OutComeId="1727" OutCome="{$competitor1}/draw &amp; over {total}" SpecialBetValue="2.5" />
#               <W OddsType="547" OutComeId="1728" OutCome="{$competitor1}/{$competitor2} &amp; over {total}" SpecialBetValue="1.5" />
#               <W OddsType="547" OutComeId="1728" OutCome="{$competitor1}/{$competitor2} &amp; over {total}" SpecialBetValue="2.5" />
#               <W OddsType="548" OutComeId="1731" OutCome="1-3" />
#               <W OddsType="548" OutComeId="1732" OutCome="1-4" />
#               <W OddsType="548" OutComeId="1733" OutCome="1-5" />
#               <W OddsType="548" OutComeId="1734" OutCome="1-6" />
#               <W OddsType="548" OutComeId="1735" OutCome="2-3" />
#               <W OddsType="548" OutComeId="1736" OutCome="2-4" />
#               <W OddsType="548" OutComeId="1737" OutCome="2-5" />
#               <W OddsType="548" OutComeId="1738" OutCome="2-6" />
#               <W OddsType="548" OutComeId="1739" OutCome="3-4" />
#               <W OddsType="548" OutComeId="1740" OutCome="3-5" />
#               <W OddsType="548" OutComeId="1741" OutCome="3-6" />
#               <W OddsType="549" OutComeId="1746" OutCome="1-2" />
#               <W OddsType="549" OutComeId="1747" OutCome="1-3" />
#               <W OddsType="549" OutComeId="1748" OutCome="2-3" />
#               <W OddsType="550" OutComeId="1746" OutCome="1-2" />
#               <W OddsType="550" OutComeId="1747" OutCome="1-3" />
#               <W OddsType="551" OutComeId="1754" OutCome="2:1, 3:1 or 4:1" />
#               <W OddsType="552" OutComeId="1746" OutCome="1-2" />
#               <W OddsType="552" OutComeId="1747" OutCome="1-3" />
#               <W OddsType="553" OutComeId="1746" OutCome="1-2" />
#               <W OddsType="553" OutComeId="1747" OutCome="1-3" />
#               <W OddsType="553" OutComeId="1748" OutCome="2-3" />
#               <W OddsType="818" OutComeId="1836" OutCome="{$competitor1}/{$competitor1} &amp; under {total}" SpecialBetValue="3.5" />
#               <W OddsType="818" OutComeId="1836" OutCome="{$competitor1}/{$competitor1} &amp; under {total}" SpecialBetValue="4.5" />
#               <W OddsType="818" OutComeId="1845" OutCome="{$competitor1}/{$competitor1} &amp; over {total}" SpecialBetValue="1.5" />
#               <W OddsType="818" OutComeId="1845" OutCome="{$competitor1}/{$competitor1} &amp; over {total}" SpecialBetValue="2.5" />
#               <W OddsType="819" OutComeId="1836" OutCome="{$competitor1}/{$competitor1} &amp; under {total}" SpecialBetValue="1.5" />
#               <W OddsType="819" OutComeId="1836" OutCome="{$competitor1}/{$competitor1} &amp; under {total}" SpecialBetValue="2.5" />
#               <W OddsType="819" OutComeId="1845" OutCome="{$competitor1}/{$competitor1} &amp; over {total}" SpecialBetValue="0.5" />
#               <W OddsType="820" OutComeId="1866" OutCome="{$competitor1}/{$competitor1} &amp; 3" />
#               <W OddsType="854" OutComeId="74" OutCome="yes" SpecialBetValue="2.5" />
#               <W OddsType="855" OutComeId="74" OutCome="yes" SpecialBetValue="2.5" />
#               <W OddsType="856" OutComeId="74" OutCome="yes" SpecialBetValue="2.5" />
#               <W OddsType="857" OutComeId="76" OutCome="no" SpecialBetValue="2.5" />
#               <W OddsType="858" OutComeId="74" OutCome="yes" SpecialBetValue="2.5" />
#               <W OddsType="859" OutComeId="76" OutCome="no" SpecialBetValue="2.5" />
#               <W OddsType="860" OutComeId="74" OutCome="yes" />
#               <W OddsType="861" OutComeId="74" OutCome="yes" />
#               <W OddsType="862" OutComeId="74" OutCome="yes" />
#               <W OddsType="863" OutComeId="74" OutCome="yes" />
#               <W OddsType="864" OutComeId="76" OutCome="no" />
#               <W OddsType="865" OutComeId="76" OutCome="no" />
#               <W OddsType="879" OutComeId="76" OutCome="no" />
#               <W OddsType="880" OutComeId="74" OutCome="yes" />
#               <W OddsType="881" OutComeId="74" OutCome="yes" />
#             </BetResult>
#           </Match>
#         </Tournament>
#       </Category>
#     </Sport>
#   </Sports>
# </BetbalancerBetData>