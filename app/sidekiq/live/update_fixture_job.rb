class Live::UpdateFixtureJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 1

  def perform(doc)
    # print out the doc and check its type
    Rails.logger.info("Document class: #{doc.class}")
    puts "Document class: #{doc.class}"
    Rails.logger.info("Document content: #{doc}")
    Rails.logger.info("Received XML document: #{doc.to_xml}")
    puts "Received XML document: #{doc.to_xml}"

    doc.xpath("//Match").each do |match|
      match_id = match["matchid"].to_i
      match_status = match["status"]

      # find the fixture
      fixture = Fixture.find_by(event_id: match_id)
      next unless fixture

      if fixture.booked == false 
        fixture.booked = true
      end

      fixture.status = "active"
      fixture.match_status = match_status

      # update fixture details
      match_info = match.at_xpath("MatchInfo")
      if match_info
        date_of_match = match_info.at_xpath("DateOfMatch")&.text
        fixture.start_date = Time.at(date_of_match.to_i / 1000) if date_of_match.present?

        home_team_node = match_info.at_xpath("HomeTeam")
        if home_team_node
          fixture.part_one_id = home_team_node["id"].to_i
          fixture.part_one_name = home_team_node.text.strip
        end

        away_team_node = match_info.at_xpath("AwayTeam")
        if away_team_node
          fixture.part_two_id = away_team_node["id"].to_i
          fixture.part_two_name = away_team_node.text.strip
        end
      end

      # save fixture if changed
      fixture.save! if fixture.changed?
    end
  end
end

# <BetbalancerLiveOdds xmlns="http://www.betbalancer.com/BetbalancerLiveOdds" timestamp="1764146500433" status="meta">
#   <Match active="1" booked="0" matchid="66082668" status="not_started">
#     <MatchInfo>
#       <DateOfMatch>1764147600000</DateOfMatch>
#       <Sport id="37">Squash</Sport>
#       <Category id="371">International</Category>
#       <Tournament id="21426">Hong Kong Open, Women</Tournament>
#       <HomeTeam id="282937">Ramadan, Hana</HomeTeam>
#       <AwayTeam id="640600">Azman, Aira</AwayTeam>
#       <TvChannels/>
#     </MatchInfo>
#     <Translation>
#       <Sport id="37">
#         <Name lang="en">Squash</Name>
#         <Name lang="it">Squash</Name>
#         <Name lang="fr">Squash</Name>
#       </Sport>
#       <Category id="371">
#         <Name lang="en">International</Name>
#         <Name lang="it">Internazionale</Name>
#         <Name lang="fr">International</Name>
#       </Category>
#       <Tournament id="21426">
#         <Name lang="en">Hong Kong Open, Women</Name>
#         <Name lang="it">Hong Kong Open, Donne</Name>
#         <Name lang="fr">Open de Hong Kong, Dames</Name>
#       </Tournament>
#       <HomeTeam id="282937">
#         <Name lang="en">Ramadan, Hana</Name>
#         <Name lang="it">Ramadan, Hana</Name>
#         <Name lang="fr">Ramadan, Hana</Name>
#       </HomeTeam>
#       <AwayTeam id="640600">
#         <Name lang="en">Azman, Aira</Name>
#         <Name lang="it">Azman, Aira</Name>
#         <Name lang="fr">Azman, Aira</Name>
#       </AwayTeam>
#     </Translation>
#   </Match>
# </BetbalancerLiveOdds>