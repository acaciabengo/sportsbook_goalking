class Live::CancelBetJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 1

  def perform(xml_string)
    # Parse XML string to Nokogiri document
    doc = Nokogiri.XML(xml_string) { |config| config.strict.nonet }
    doc.xpath("//Match").each do |match|
      bet_status = match["betstatus"]
      match_id = match["matchid"].to_i

      # # find the fixture and update its status
      fixture = Fixture.find_by(event_id: match_id)
      
        match.xpath("Odds").each do |odds_node|
          outcome = odds_node['freetext']
          outcome_id = odds_node['id'].to_i
          specifier = odds_node['specialoddsvalue']
          ext_market_id = odds_node['typeid'].to_i


          results = { outcome => { "status" => "cancelled", "outcome_id" => outcome_id, "specifier" => specifier } }
          market = fixture.markets.find_by(ext_market_id: ext_market_id)
          merged_results = market.market_results.deep_merge(results)
          unless market.update(market_results: merged_results)
            Rails.logger.error("Failed to update market results for market #{market.id} with results #{results}: #{market.errors.full_messages.join(', ')}")
          end

          # cancel all the bets associated with this outcome
          fixture.bets.where(outcome_id: outcome_id, specifier: specifier).where.not(status: 'settled').update_all(status: 'cancelled')
        end
      
    end
    # Clear parsed document from memory
    doc = nil
  end
end

# <BetbalancerLiveOdds xmlns="http://www.betbalancer.com/BetbalancerLiveOdds" status="cancelbet" timestamp="1199436169018">
#   <Match
#     active="1"
#     betstatus="stopped"
#     matchid="661373"
#     matchtime="9"
#     msgnr="46"
#     status="1p">
#     <Odds
#       active="1"
#       combination="0"
#       freetext="Next goal"
#       id="13792"
#       specialoddsvalue="2:0"
#       subtype="13"
#       type="ft3w"
#       typeid="6" />
#   </Match>
# </BetbalancerLiveOdds>
# 
# <BetbalancerLiveOdds
#   xmlns="http://www.betbalancer.com/BetbalancerLiveOdds"
#   endtime="1199436022222"
#   starttime="1199435902000"
#   status="cancelbet"
#   timestamp="1199436037753">
#   <Match
#     active="1"
#     betstatus="started"
#     matchid="661373"
#     matchtime="7"
#     msgnr="33"
#     status="1p">
#     <Odds
#       active="1"
#       combination="0"
#       freetext="Next goal"
#       id="13790"
#       specialoddsvalue="1:0"
#       subtype="13"
#       type="ft3w"
#       typeid="6" />
#   </Match>