class Live::OddsUpdateJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 1

  def perform(xml_string)
    # Parse XML string to Nokogiri document
    doc = Nokogiri.XML(xml_string) { |config| config.strict.nonet }
    doc.xpath("//Match").each do |match|
      match_id = match["matchid"].to_i
      score = match["score"]

      # find the fixture
      fixture = Fixture.find_by(event_id: match_id)
      next unless fixture

      update_attributes = {}

      if score.present?
        home_score, away_score = score.split(':').map(&:to_i)
        update_attributes[:home_score] = home_score
        update_attributes[:away_score] = away_score
      end

      match_status = match["active"] == "1" ? "live" : "finished"
      update_attributes[:match_status] = match_status

      betstatus = match["betstatus"] == "started" ? "in_play" : "suspended"
    
      # upate the match
      unless fixture.update(update_attributes)
        Rails.logger.error("Failed to update fixture #{fixture.id} with attributes #{update_attributes}: #{fixture.errors.full_messages.join(', ')}")
      end
      

      match.xpath("Odds").each do |odds_node|
        outcome = odds_node['freetext']
        specifier = odds_node['specialoddsvalue']
        market_identifier = odds_node['typeid'].to_i
        new_odds = {}

        odds_node.xpath("OddsField").each do |odds_field|
          outcome = odds_field['type']
          outcome_id = odds_field['typeid'].to_i
          odd_value = odds_field.text.to_f
          new_odds[outcome] = { "odd_value" => odd_value, "outcome_id" => outcome_id, "specifier" => specifier }
        end

        # Skip if no odds fields (empty market)
        next if new_odds.empty?

        market = fixture.live_markets.find_by(market_identifier: market_identifier, specifier: specifier)
        if market
          merged_odds = (market.odds || {}).deep_merge(new_odds)
          unless market.update(odds: merged_odds, status: betstatus)
            Rails.logger.error("Failed to update odds for market #{market.id} with odds #{new_odds}: #{market.errors.full_messages.join(', ')}")
          end

        else
          # create new market
          market = fixture.live_markets.build(market_identifier: market_identifier, odds: new_odds, specifier: specifier, status: betstatus)
          unless market.save
            Rails.logger.error("Failed to create market for fixture #{fixture.id} with market_identifier #{market_identifier}, specifier #{specifier}, odds #{new_odds}: #{market.errors.full_messages.join(', ')}")
          end
        end
      end
    end
    # Clear parsed document from memory
    doc = nil
  end
end

# <BetbalancerLiveOdds
#   xmlns="http://www.betbalancer.com/BetbalancerLiveOdds"
#   status="change"
#   timestamp="1199777659034">
#   <Match
#     active="1"
#     betstatus="started"
#     earlybetstatus="stopped"
#     matchid="5984472"
#     matchtime="38"
#     msgnr="155"
#     score="1:0"
#     setscores="1:0"
#     status="1p">
    
#     <Odds
#       active="1"
#       changed="true"
#       combination="0"
#       freetext="Total Corners"
#       id="57178832"
#       mostbalanced="0"
#       specialoddsvalue="7.5"
#       subtype="126"
#       type="ftnw"
#       typeid="8">
#       <OddsField active="1" type="under" typeid="373">2.6</OddsField>
#       <OddsField active="1" type="over" typeid="374">1.45</OddsField>
#     </Odds>
    
#     <Odds
#       active="1"
#       changed="false"
#       combination="0"
#       id="57178580"
#       mostbalanced="1"
#       specialoddsvalue="-1.25"
#       subtype="36"
#       type="ft2w"
#       typeid="7">
#       <OddsField active="1" type="1" typeid="17">2.8</OddsField>
#       <OddsField active="1" type="2" typeid="18">1.4</OddsField>
#     </Odds>
    
#     <Odds
#       active="0"
#       changed="false"
#       combination="0"
#       id="57173070"
#       mostbalanced="0"
#       specialoddsvalue="-1.5"
#       subtype="123"
#       type="ft2w"
#       typeid="7" />
#   </Match>
# </BetbalancerLiveOdds>

# <BetbalancerLiveOdds
#   xmlns="http://www.betbalancer.com/BetbalancerLiveOdds"
#   status="change"
#   timestamp="1287056116518">
#   <Match
#     active="1"
#     betstatus="started"
#     clock_stopped="0"
#     matchid="1467300"
#     matchtime="32"
#     msgnr="31"
#     remaining_time="8:49"
#     score="13:10"
#     setscores="0:0 - 5:5 - 3:5"
#     status="4q">
    
#     <Odds
#       active="1"
#       changed="false"
#       combination="0"
#       freetext="Asian Handicap"
#       id="748814"
#       specialoddsvalue="-3.5"
#       subtype="34"
#       type="ft2w"
#       typeid="7">
#       <OddsField active="1" type="1">1.75</OddsField>
#       <OddsField active="1" type="2">1.9</OddsField>
#     </Odds>
    
#     <Odds
#       active="0"
#       changed="true"
#       combination="0"
#       typeid="5" />
      
#     <Odds
#       active="0"
#       changed="false"
#       combination="0"
#       id="748888"
#       specialoddsvalue="0.5"
#       subtype="54"
#       type="ft2w"
#       typeid="7" />
      
#     <Odds
#       active="1"
#       changed="true"
#       combination="0"
#       freetext="including overtime"
#       id="748867"
#       specialoddsvalue="-4.5"
#       subtype="38"
#       type="ft2w"
#       typeid="7">
#       <OddsField active="1" type="1">1.85</OddsField>
#       <OddsField active="1" type="2">1.8</OddsField>
#     </Odds>
    
#   </Match>
# </BetbalancerLiveOdds>

#<BetbalancerLiveOdds
#   xmlns="http://www.betbalancer.com/BetbalancerLiveOdds"
#   status="change"
#   timestamp="1413846115107">
#   <Match
#     active="1"
#     betstatus="started"
#     earlybetstatus="stopped"
#     matchid="5650450"
#     matchtime="1"
#     matchtime_extended="0:00"
#     msgnr="6"
#     score="0:0"
#     setscores="0:0"
#     status="1p">
#     </Match>
# </BetbalancerLiveOdds>
# 
#<BetbalancerLiveOdds
#   xmlns="http://www.betbalancer.com/BetbalancerLiveOdds"
#   status="change"
#   timestamp="1413846115107">
#   <Match
#     active="1"
#     betstatus="started"
#     earlybetstatus="stopped"
#     matchid="5650450"
#     matchtime="1"
#     msgnr="6"
#     score="0:0"
#     setscores="0:0"
#     status="1p">
#     </Match>
# </BetbalancerLiveOdds>
# 
#<BetbalancerLiveOdds
#   xmlns="http://www.betbalancer.com/BetbalancerLiveOdds"
#   status="change"
#   timestamp="1414364604992">
#   <Match
#     active="1"
#     betstatus="started"
#     matchid="5867680"
#     matchtime="1"
#     msgnr="5"
#     score="0:0"
#     setscores="0:0"
#     status="1p">
#     </Match>
# </BetbalancerLiveOdds>