class Live::BetSettlementJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 1

  def perform(xml_string)
    # Parse XML string to Nokogiri document
    doc = Nokogiri.XML(xml_string) { |config| config.strict.nonet }
    doc.xpath("//Match").each do |match|
      # bet_status = match["betstatus"]
      match_id = match["matchid"].to_i

      # find the fixture
      fixture = Fixture.find_by(event_id: match_id)
      next unless fixture

      # update the fixture with score and status
      clearedscore = match["clearedscore"]
      update_attrs = {}
      if clearedscore.present?
        update_attrs[:home_score] = clearedscore.split(':')[0].to_i
        update_attrs[:away_score] = clearedscore.split(':')[1].to_i
      end
      update_attrs[:status] = 'inactive'
      update_attrs[:match_status] = 'finished'
      fixture.update(update_attrs) if update_attrs.any?

      match.xpath("Odds").each do |odds_node|
        # market_name = odds_node['freetext']
        specifier = odds_node['specialoddsvalue']
        ext_market_id = odds_node['typeid'].to_i

        results = {}

        odds_node.xpath("OddsField").each do |odds_field|
          outcome = odds_field['type']
          outcome_status = odds_field['outcome'] == '1' ? 'W' : 'L'
          results[outcome] = { "status" => outcome_status, "specifier" => specifier }
        end

        
        market = fixture.markets.find_by(ext_market_id: ext_market_id)
        merged_results = market.market_results.deep_merge(results)
        unless market.update(market_results: merged_results, status: 'settled')
          Rails.logger.error("Failed to update market results for market #{market.id} with results #{results}: #{market.errors.full_messages.join(', ')}")
        end

        # settle all the bets associated with this outcome
        # close settled bets
        CloseSettledBetsWorker.perform_async(fixture.id, market.id, results)
      end
    end
    # Clear parsed document from memory
    doc = nil
  end
end

# <BetbalancerLiveOdds
#   xmlns="http://www.betbalancer.com/BetbalancerLiveOdds"
#   status="clearbet"
#   time="1"
#   timestamp="1199435884237">
#   <Match
#     active="1"
#     betstatus="stopped"
#     clearedscore="1:0"
#     matchid="661373"
#     matchtime="4"
#     msgnr="21"
#     status="1p">
#     <Odds
#       active="1"
#       combination="0"
#       freetext="Next goal"
#       id="13786"
#       specialoddsvalue="0:0"
#       subtype="13"
#       type="ft3w"
#       typeid="6">
#       <OddsField active="1" outcome="1" type="1" />
#       <OddsField active="1" outcome="0" type="x" />
#       <OddsField active="1" outcome="0" type="2" />
#     </Odds>
#   </Match>
# </BetbalancerLiveOdds>

# <BetbalancerLiveOdds
#   xmlns="http://www.betbalancer.com/BetbalancerLiveOdds"
#   status="clearbet"
#   time="2"
#   timestamp="1266483496355">
#   <Match
#     active="1"
#     betstatus="stopped"
#     clearedscore="0:1"
#     matchid="935448"
#     msgnr="19"
#     status="paused">
#     <Odds
#       active="1"
#       combination="0"
#       freetext="Asian total first half"
#       id="311538"
#       specialoddsvalue="1.25"
#       subtype="35"
#       type="ftnw"
#       typeid="8">
#       <OddsField active="1" outcome="1" />
#       <OddsField active="1" />
#     </Odds>
#   </Match>
# </BetbalancerLiveOdds>
