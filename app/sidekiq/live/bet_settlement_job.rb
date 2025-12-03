class Live::BetSettlementJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 1

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

        # Build simple results hash
        results = {}
        odds_node.xpath("OddsField").each do |odds_field|
          outcome = odds_field['type']
          outcome_status = odds_field['outcome'] == '1' ? 'W' : 'L'
          void_factor = odds_field['voidfactor']&.to_f || 0.0
          results[outcome] = { status: outcome_status, void_factor: void_factor }
        end

        # Find the specific market by market_identifier AND specifier
        market = fixture.live_markets.find_by(
          market_identifier: ext_market_id, 
          specifier: specifier
        )

        unless market
          Rails.logger.warn("Market not found: fixture=#{fixture.id}, market_identifier=#{ext_market_id}, specifier=#{specifier}")
          next
        end
        
        # Update this specific market directly (no merging!)
        unless market.update(results: results, status: 'settled')
          Rails.logger.error("Failed to settle market #{market.id}: #{market.errors.full_messages.join(', ')}")
          next
        end

        Rails.logger.info("Settled market #{market.id} (#{ext_market_id}|#{specifier}): #{results}")

        # Settle bets for this specific market
        CloseSettledBetsJob.perform_in(2.minutes, fixture.id , market.id, 'Live')
      end
    end
    # Clear parsed document from memory
    doc = nil
  end
end

# <BetbalancerLiveOdds xmlns="http://www.betbalancer.com/BetbalancerLiveOdds" timestamp="1764705316730" status="clearbet">
#   <Match active="1" matchid="61300783" msgnr="313" score="0:1" betstatus="started" status="1p" matchtime="26" setscores="0:1" clearedscore="0:1" matchtime_extended="25:10" cornersaway="0" cornershome="1" redcardsaway="0" redcardshome="0" yellowcardsaway="0" yellowcardshome="0" yellowredcardsaway="0" yellowredcardshome="0">
#     <Odds active="1" combination="0" freetext="Total" id="8" specialoddsvalue="0.5" type="to" typeid="5">
#       <OddsField active="1" outcome="1" type="o" typeid="11"/>
#       <OddsField active="1" outcome="0" type="u" typeid="12"/>
#     </Odds>
#     <Odds active="1" combination="0" freetext="Next goal" id="3" specialoddsvalue="0:0" subtype="13" type="ft3w" typeid="6">
#       <OddsField active="1" outcome="0" type="1" typeid="14"/>
#       <OddsField active="1" outcome="0" type="x" typeid="15"/>
#       <OddsField active="1" outcome="1" type="2" typeid="16"/>
#     </Odds>
#     <Odds active="1" combination="0" freetext="Halftime - Next goal" id="102" specialoddsvalue="0:0" subtype="107" type="ft3w" typeid="6">
#       <OddsField active="1" outcome="0" type="1" typeid="14"/>
#       <OddsField active="1" outcome="0" type="x" typeid="15"/>
#       <OddsField active="1" outcome="1" type="2" typeid="16"/>
#     </Odds>
#     <Odds active="1" combination="0" freetext="Next goal method" id="2878" specialoddsvalue="0:0" subtype="2004" type="ftnw" typeid="8">
#       <OddsField active="1" outcome="0" type="Free Kick" typeid="9350"/>
#       <OddsField active="1" outcome="0" type="Header" typeid="9351"/>
#       <OddsField active="1" outcome="0" type="No Goal" typeid="9352"/>
#       <OddsField active="1" outcome="0" type="Own Goal" typeid="9353"/>
#       <OddsField active="1" outcome="0" type="Penalty" typeid="9354"/>
#       <OddsField active="1" outcome="1" type="Shot" typeid="9355"/>
#     </Odds>
#     <Odds active="1" combination="0" freetext="Total awayteam" id="15422" specialoddsvalue="0.5" subtype="143" type="ftnw" typeid="8">
#       <OddsField active="1" outcome="0" type="under" typeid="425"/>
#       <OddsField active="1" outcome="1" type="over" typeid="426"/>
#     </Odds>
#     <Odds active="1" combination="0" freetext="home team clean sheet" id="2925" specialoddsvalue="-1" subtype="1669" type="ftnw" typeid="8">
#       <OddsField active="1" outcome="0" type="yes" typeid="9366"/>
#       <OddsField active="1" outcome="1" type="no" typeid="9367"/>
#     </Odds>
#     <Odds active="1" combination="0" freetext="Halftime - Total" id="47" specialoddsvalue="0.5" subtype="21" type="ft2w" typeid="7">
#       <OddsField active="1" outcome="0" type="1" typeid="17"/>
#       <OddsField active="1" outcome="1" type="2" typeid="18"/>
#     </Odds>
#   </Match>
# </BetbalancerLiveOdds>