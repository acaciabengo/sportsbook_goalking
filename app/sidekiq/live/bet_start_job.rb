class Live::BetStartJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 0

  def perform(doc)
    doc.xpath("//Match").each do |match|
      bet_status = match["betstatus"]
      match_id = match["matchid"].to_i

      # find the fixture and update its status
      fixture = Fixture.find_by(event_id: match_id)
      fixture.update(status: 'active', fixture_status: "not_started") if fixture
    end
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