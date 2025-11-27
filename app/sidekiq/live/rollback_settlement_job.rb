class Live::RollbackSettlementJob
  include Sidekiq::Job
  sidekiq_options queue: :high, retry: 1

  def perform(xml_string)
    # Parse XML string to Nokogiri document
    doc = Nokogiri.XML(xml_string) { |config| config.strict.nonet }
    doc.remove_namespaces!
    doc.xpath("//Match").each do |match|
      # bet_status = match["betstatus"]
      match_id = match["matchid"].to_i

      # find the fixture
      fixture = Fixture.find_by(event_id: match_id)
      next unless fixture

    
      match.xpath("Odds").each do |odds_node|
        # market_name = odds_node['freetext']
        specifier = odds_node['specialoddsvalue']
        ext_market_id = odds_node['typeid'].to_i

        outcomes = []
        odds_node.xpath("OddsField").each do |odds_field|
          outcome = odds_field['type']
          # outcome_status = odds_field['outcome'] == '1' ? 'L' : 'W'
          outcomes << outcome
        end

        # Find all bets
        bets = fixture.bets.where(specifier: specifier, market_identifier: ext_market_id, outcome: outcomes)
        bets.update_all(status: 'active')
      end
    end
    # Clear parsed document from memory
    doc = nil
  end
end


# <BetbalancerLiveOdds
#   xmlns="http://www.betbalancer.com/BetbalancerLiveOdds"
#   status="rollback"
#   time="17"
#   timestamp="1199436168440">
#   <Match
#     active="1"
#     betstatus="stopped"
#     clearedscore="2:0"
#     matchid="661373"
#     matchtime="9"
#     msgnr="45"
#     status="1p">
#     <Odds
#       active="1"
#       combination="0"
#       freetext="Next goal"
#       id="1379"
#       specialoddsvalue="1:0"
#       subtype="13"
#       type="ft3w"
#       typeid="6">
#       <OddsField active="1" outcome="1" type="1" />
#       <OddsField active="1" outcome="0" type="x" />
#       <OddsField active="1" outcome="0" type="2" />
#     </Odds>
#   </Match>
# </BetbalancerLiveOdds>