class Live::BetStartJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 0

  def perform(xml_string)
    # Parse XML string to Nokogiri document
    doc = Nokogiri.XML(xml_string) { |config| config.strict.nonet }
    doc.remove_namespaces!
    doc.xpath("//Match").each do |match|
      # bet_status = match["betstatus"]
      match_id = match["matchid"].to_i

      # find the fixture and activate all markets
      fixture = Fixture.find_by(event_id: match_id)
      suspended_markets = fixture.live_markets.where(status: 'suspended')
      suspended_markets.update_all(status: 'active') 
    end
    # Clear parsed document from memory
    doc = nil
  end
end

# <BetbalancerLiveOdds
#   xmlns="http://www.betbalancer.com/BetbalancerLiveOdds"
#   status="betstart"
#   time="0"
#   timestamp="1199435558847">
#   <Match
#     active="1"
#     betstatus="started"
#     matchid="661373"
#     msgnr="5"
#     score="-:-"
#     status="not_started" />
# </BetbalancerLiveOdds>

# <BetbalancerLiveOdds
#   xmlns="http://www.betbalancer.com/BetbalancerLiveOdds"
#   status="betstop"
#   time="0"
#   timestamp="1199435635925">
#   <Match
#     active="1"
#     betstatus="stopped"
#     matchid="661373"
#     msgnr="6"
#     score="-:-"
#     status="not_started" />
# </BetbalancerLiveOdds>