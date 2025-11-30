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
    SQL

    # Query in batches to avoid memory issues
    fixtures = ActiveRecord::Base.connection.exec_query(sql).to_a
    fixtures.each do |fixture|
      settle_pre_markets_for_fixture(fixture)
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
    status, settlement_data = @bet_balancer.get_matches(match_id: fixture.event_id, want_score: true)

    if status != 200 || settlement_data.nil?
      Rails.logger.error("Failed to fetch settlement data for fixture #{fixture['id']}")
      return
    end

    settlement_data.remove_namespaces!

    results = {}
    settlement_data
      .xpath("//Match/BetResult/*")
      .each do |bet_result|
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

    existing_results = market.results ||  {}
    existing_results = existing_results.deep_transform_keys(&:to_s)
    merged_results = existing_results.deep_merge(results)
    market.update(results: merged_results, status: "settled")
    
    # close settled bets
    CloseSettledBetsJob.perform_async(fixture.id, market.id, results, '')
  end

  def settle_live_market(fixtures)
    fixtures.batch(10) do |fixture_batch|
      # construct XML request for this batch
      #  <BookmakerStatus timestamp="0">
      #   <Match matchid="661373" />
      # </BookmakerStatus>
      # 
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.BookmakerStatus(timestamp: '0') {
          fixture_batch.each do |fixture|
            xml.Match(matchid: fixture["event_id"])
          end
        }
      end

      xml_request = builder.to_xml

      # connect to redis and publish the request
      redis = Redis.new(url: ENV['REDIS_URL'])
      redis.publish(CHANNEL, xml_request)
    end
  end
end

# <Match BetbalancerMatchID="109379">
#   <Fixture">
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
