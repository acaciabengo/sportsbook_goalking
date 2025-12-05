class Live::CancelBetJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 1

  def perform(xml_string)
    # Parse XML string to Nokogiri document
    doc = Nokogiri.XML(xml_string) { |config| config.strict.nonet }
    doc.remove_namespaces!
    doc.xpath("//Match").each do |match|
      # bet_status = match["betstatus"]
      match_id = match["matchid"].to_i

      # # find the fixture and update its status
      fixture = Fixture.find_by(event_id: match_id)

      results_grouped_by_market_and_specifier = {}

      
      match.xpath("Odds").each do |odds_node|
        outcome = odds_node['freetext']
        outcome_id = odds_node['id'].to_i
        specifier = odds_node['specialoddsvalue']
        ext_market_id = odds_node['typeid'].to_i

        results_grouped_by_market_and_specifier[ext_market_id] ||= {}
        results_grouped_by_market_and_specifier[ext_market_id][specifier] ||= {}
        results_grouped_by_market_and_specifier[ext_market_id][specifier] = {
          'outcome' => outcome,
          'outcome_id' => outcome_id,
          'status' => 'cancelled'
        }
      end


      results_grouped_by_market_and_specifier.each do |ext_market_id, specifier_hash|
        specifier_hash.each do |specifier, results_hash|
          market = fixture.live_markets.find_by(ext_market_id: ext_market_id, specifier: specifier)

          if market.nil?
            Rails.logger.warn("Market not found for cancellation: fixture=#{fixture.id}, ext_market_id=#{ext_market_id}, specifier=#{specifier}")
            next
          end

          unless market.update(results: { results_hash['outcome'] => { status: 'C', void_factor: 1.0 } }, status: 'cancelled')
            Rails.logger.error("Failed to cancel market #{market.id}: #{market.errors.full_messages.join(', ')}")
            next
          end

          # cancel all the bets associated with this market and specifier
          fixture.bets
          .where(market_identifier: ext_market_id, specifier: specifier, outcome: results_hash['outcome_id'])
          .where.not(status: 'settled')
          .update_all(status: 'cancelled') 
        end
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