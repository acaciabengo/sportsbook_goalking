class SyncTournamentsJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 1

  def perform(*args)
    bet_balancer = BetBalancer.new

    # Use find_each to process in batches and avoid loading all records into memory
    Category.find_each do |category|
      status, tournaments_data =
        bet_balancer.get_tournaments(category_id: category.ext_category_id)

      if status != 200
        Rails.logger.error("Failed to fetch tournaments data: HTTP #{status}")
        next
      end

      tournaments_data
        .xpath("//Category/Tournament")
        .each do |tournament|
          tournament_id = tournament["BetbalancerTournamentID"]&.to_i
          tournament_name =
            tournament.at_xpath("Texts/Text[@Language='en']/Value")&.content
          
          next unless tournament_name.present? && tournament_id.to_i > 0

          tournament_record = Tournament.find_or_initialize_by(
            ext_tournament_id: tournament_id,
            category: category
          )

          if tournament_record.new_record? || tournament_record.name != tournament_name
            tournament_record.name = tournament_name

            unless tournament_record.save
              Rails.logger.error(
                "Failed to save tournament #{tournament_id}: #{tournament_record.errors.full_messages.join(", ")}"
              )
            end
          end
        end
      
      # Clear Nokogiri document from memory after processing each category
      tournaments_data = nil
      GC.start if (category.id % 10).zero? # Periodic GC hint every 10 categories
    end
  end
end


# <?xml version="1.0" encoding="UTF-8"?>
# <BetbalancerBetData>
#   <Timestamp CreatedTime="2025-11-20T08:24:51.559Z" TimeZone="UTC"/>
#   <Sports>
#     <Sport BetbalancerSportID="1">
#       <Category BetbalancerCategoryID="1">
#         <Tournament BetbalancerTournamentID="17">
#           <Texts>
#             <Text Language="BET">
#               <Value>Premier League</Value>
#             </Text>
#             <Text Language="it">
#               <Value>Premier League</Value>
#             </Text>
#             <Text Language="en">
#               <Value>Premier League</Value>
#             </Text>
#           </Texts>
#         </Tournament>
#         <Tournament BetbalancerTournamentID="18">
#           <Texts>
#             <Text Language="BET">
#               <Value>Championship</Value>
#             </Text>
#             <Text Language="it">
#               <Value>Championship</Value>
#             </Text>
#             <Text Language="en">
#               <Value>Championship</Value>
#             </Text>
#           </Texts>
#         </Tournament>
#         <Tournament BetbalancerTournamentID="19">
#           <Texts>
#             <Text Language="BET">
#               <Value>FA Cup</Value>
#             </Text>
#             <Text Language="it">
#               <Value>FA Cup</Value>
#             </Text>
#             <Text Language="en">
#               <Value>FA Cup</Value>
#             </Text>
#           </Texts>
#         </Tournament>
#         <Tournament BetbalancerTournamentID="21">
#           <Texts>
#             <Text Language="BET">
#               <Value>EFL Cup</Value>
#             </Text>
#             <Text Language="it">
#               <Value>EFL Cup</Value>
#             </Text>
#             <Text Language="en">
#               <Value>EFL Cup</Value>
#             </Text>
#           </Texts>
#         </Tournament>
#         <Tournament BetbalancerTournamentID="24">
#           <Texts>
#             <Text Language="BET">
#               <Value>League One</Value>
#             </Text>
#             <Text Language="it">
#               <Value>League One</Value>
#             </Text>
#             <Text Language="en">
#               <Value>League One</Value>
#             </Text>
#           </Texts>
#         </Tournament>
#         <Tournament BetbalancerTournamentID="25">
#           <Texts>
#             <Text Language="BET">
#               <Value>League Two</Value>
#             </Text>
#             <Text Language="it">
#               <Value>League Two</Value>
#             </Text>
#             <Text Language="en">
#               <Value>League Two</Value>
#             </Text>
#           </Texts>
#         </Tournament>
#         <Tournament BetbalancerTournamentID="334">
#           <Texts>
#             <Text Language="BET">
#               <Value>EFL Trophy</Value>
#             </Text>
#             <Text Language="it">
#               <Value>Football League Trophy</Value>
#             </Text>
#             <Text Language="en">
#               <Value>EFL Trophy</Value>
#             </Text>
#           </Texts>
#         </Tournament>
#         <Tournament BetbalancerTournamentID="346">
#           <Texts>
#             <Text Language="BET">
#               <Value>Community Shield</Value>
#             </Text>
#             <Text Language="it">
#               <Value>Community Shield</Value>
#             </Text>
#             <Text Language="en">
#               <Value>Community Shield</Value>
#             </Text>
#           </Texts>
#         </Tournament>
#         <Tournament BetbalancerTournamentID="1696">
#           <Texts>
#             <Text Language="BET">
#               <Value>FA Cup, Qualification</Value>
#             </Text>
#             <Text Language="it">
#               <Value>FA Cup, Qualificazioni</Value>
#             </Text>
#             <Text Language="en">
#               <Value>FA Cup, Qualification</Value>
#             </Text>
#           </Texts>
#         </Tournament>
#         <Tournament BetbalancerTournamentID="45083">
#           <Texts>
#             <Text Language="BET">
#               <Value>National League Cup</Value>
#             </Text>
#             <Text Language="it">
#               <Value>National League Cup</Value>
#             </Text>
#             <Text Language="en">
#               <Value>National League Cup</Value>
#             </Text>
#           </Texts>
#         </Tournament>
#       </Category>
#     </Sport>
#   </Sports>
# </BetbalancerBetData>