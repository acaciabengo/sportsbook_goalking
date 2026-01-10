class Live::OddsUpdateJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 1

  def perform(xml_string)
    # print out the XML string for debugging
    # puts "Live::OddsUpdateJob: Received XML string: #{xml_string}"

    # Parse XML string to Nokogiri document
    doc = Nokogiri.XML(xml_string) { |config| config.strict.nonet }
    # remove all namespaces for easier xpath querying
    doc.remove_namespaces!
    doc.xpath("//Match").each do |match|
      match_id = match["matchid"]
      score = match["score"]
      live_odds = match["active"]

      # find the fixture
      fixture = Fixture.find_by(event_id: match_id)
      if fixture.nil?
        Rails.logger.error("Fixture with event_id #{match_id} not found.")
        # puts "Fixture with event_id #{match_id} not found."  
        next
      else
        # puts "Updating fixture #{fixture.id} for event_id #{match_id}."
        Rails.logger.info("Updating fixture #{fixture.id} for event_id #{match_id}.")
      end

      update_attributes = {}

      # add the live odds status
      update_attributes[:live_odds] = live_odds if live_odds.present?

      update_attributes[:match_time] = match['matchtime_extended'] if match['matchtime_extended'].present?

      if score.present?
        home_score, away_score = score.split(':').map(&:to_i)
        update_attributes[:home_score] = home_score
        update_attributes[:away_score] = away_score
      end

      match_status = match["active"] #== "1" ? "live" : "finished"
      update_attributes[:match_status] = match_status

      betstatus = match["betstatus"] #== "started" ? "in_play" : "suspended"
    
      # upate the match
      unless fixture.update(update_attributes)
        Rails.logger.error("Failed to update fixture #{fixture.id} with attributes #{update_attributes}: #{fixture.errors.full_messages.join(', ')}")
        # puts "Failed to update fixture #{fixture.id} with attributes #{update_attributes}: #{fixture.errors.full_messages.join(', ')}"  
      end
      

      match.xpath("Odds").each do |odds_node|
        # ext_market_id = odds_node['id'].to_i
        ext_market_id = odds_node['typeid'].to_i
        specifier = odds_node['specialoddsvalue']
        market_name = odds_node['freetext']

        
        new_odds = {}

        odds_node.xpath("OddsField").each do |odds_field|
          outcome = odds_field['type']
          outcome_id = odds_field['typeid'].to_i
          odd_value = odds_field.text.to_f
          new_odds[outcome] = { "odd" => odd_value, "outcome_id" => outcome_id }
        end

        # Skip if no odds fields (empty market)
        next if new_odds.empty?

        live_market = LiveMarket.find_by(
          fixture_id: fixture.id, 
          market_identifier: ext_market_id,
          specifier: specifier
        )

        if live_market
          # existing_odds = live_market.odds || {}
          # merged_odds = existing_odds.deep_merge(new_odds)
          unless live_market.update(odds: new_odds, status: betstatus)
            Rails.logger.error("Failed to update odds for market #{live_market.id} with odds #{new_odds}: #{live_market.errors.full_messages.join(', ')}")
            # puts "Failed to update odds for market #{live_market.id} with odds #{new_odds}: #{live_market.errors.full_messages.join(', ')}"
          end
        else
          # create new market
          live_market = LiveMarket.new(
            fixture_id: fixture.id,
            market_identifier: ext_market_id,
            specifier: specifier,
            name: market_name,
            odds: new_odds,
            status: betstatus
          )
          unless live_market.save
            Rails.logger.error("Failed to create market for fixture #{fixture.id} with market_identifier #{ext_market_id}, specifier #{specifier}, odds #{new_odds}: #{live_market.errors.full_messages.join(', ')}")
            # puts "Failed to create market for fixture #{fixture.id} with market_identifier #{ext_market_id}, specifier #{specifier}, odds #{new_odds}: #{live_market.errors.full_messages.join(', ')}"
          end
        end
      end
    end
    # Clear parsed document from memory
    doc = nil
  end
end

# <BetbalancerLiveOdds xmlns="http://www.betbalancer.com/BetbalancerLiveOdds" timestamp="1764189033344" status="change">
#   <Match active="1" matchid="63369877" msgnr="395" score="1:0" betstatus="started" status="1p" matchtime="30" setscores="1:0" clearedscore="1:0" matchtime_extended="29:38" cornersaway="1" cornershome="0" redcardsaway="0" redcardshome="0" yellowcardsaway="0" yellowcardshome="0" yellowredcardsaway="0" yellowredcardshome="0">
#     <Odds active="1" changed="true" combination="0" freetext="Match Corners" id="3320" specialoddsvalue="10" subtype="2007" type="ftnw" typeid="8">
#       <OddsField active="1" type="over" typeid="9376">5.50</OddsField>
#       <OddsField active="1" type="exactly" typeid="9377">8.50</OddsField>
#       <OddsField active="1" type="under" typeid="9378">1.25</OddsField>
#     </Odds>
#     <Odds active="1" changed="true" combination="0" freetext="2nd Half Corners" id="3696" specialoddsvalue="5" subtype="2009" type="ft3w" typeid="6">
#       <OddsField active="1" type="over" typeid="9382">2.40</OddsField>
#       <OddsField active="1" type="exactly" typeid="9383">5.00</OddsField>
#       <OddsField active="1" type="under" typeid="9384">1.95</OddsField>
#     </Odds>
#     <Odds active="1" changed="true" combination="0" freetext="Which team wins race to X corners" id="100" specialoddsvalue="7" subtype="1506" type="ftnw" typeid="8">
#       <OddsField active="1" type="home" typeid="6384">19.00</OddsField>
#       <OddsField active="1" type="none" typeid="6385">1.25</OddsField>
#       <OddsField active="1" type="away" typeid="6386">3.60</OddsField>
#     </Odds>
#     <Odds active="1" changed="true" combination="0" freetext="1X2 60 min" id="2918" subtype="1663" type="3w" typeid="2">
#       <OddsField active="1" type="1" typeid="1">1.36</OddsField>
#       <OddsField active="1" type="x" typeid="2">3.50</OddsField>
#       <OddsField active="1" type="2" typeid="3">9.50</OddsField>
#     </Odds>
#     <Odds active="1" changed="true" combination="0" freetext="Corner Handicap" id="7923" specialoddsvalue="2:0" subtype="2038" type="hc" typeid="4">
#       <OddsField active="1" type="1" typeid="7">2.20</OddsField>
#       <OddsField active="1" type="2" typeid="8">2.00</OddsField>
#       <OddsField active="1" type="x" typeid="9">6.50</OddsField>
#     </Odds>
#     <Odds active="1" changed="true" combination="0" freetext="Handicap" id="57" specialoddsvalue="2:0" type="hc" typeid="4">
#       <OddsField active="1" type="1" typeid="7">1.04</OddsField>
#       <OddsField active="1" type="2" typeid="8">29.00</OddsField>
#       <OddsField active="1" type="x" typeid="9">15.00</OddsField>
#     </Odds>
#     <Odds active="1" changed="true" combination="0" freetext="Asian total" id="956794" specialoddsvalue="1:0/3.0" subtype="33" type="ftnw" typeid="8">
#       <OddsField active="1" type="under" typeid="114">1.80</OddsField>
#       <OddsField active="1" type="over" typeid="115">2.05</OddsField>
#     </Odds>
#     <Odds active="1" changed="true" combination="0" freetext="Asian total" id="956791" specialoddsvalue="1:0/3.25" subtype="33" type="ftnw" typeid="8">
#       <OddsField active="1" type="under" typeid="114">1.57</OddsField>
#       <OddsField active="1" type="over" typeid="115">2.35</OddsField>
#     </Odds>
#     <Odds active="1" changed="true" combination="0" freetext="Asian Handicap" id="4478" specialoddsvalue="1:0/-0.25" subtype="34" type="ft2w" typeid="7">
#       <OddsField active="1" type="1" typeid="17">2.85</OddsField>
#       <OddsField active="1" type="2" typeid="18">1.40</OddsField>
#     </Odds>
#     <Odds active="1" changed="true" combination="0" freetext="Match Corners" id="3316" specialoddsvalue="6" subtype="2007" type="ftnw" typeid="8">
#       <OddsField active="1" type="over" typeid="9376">1.44</OddsField>
#       <OddsField active="1" type="exactly" typeid="9377">6.00</OddsField>
#       <OddsField active="1" type="under" typeid="9378">4.00</OddsField>
#     </Odds>
#   </Match>
# </BetbalancerLiveOdds>