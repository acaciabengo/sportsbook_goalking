namespace :fixtures do
   desc "Pull Fixtures between dates"
   task pull_fixtures: :environment do
      puts "Starting Fixture Pull"
      

      start_date = Date.today.strftime("%F").to_time.to_i

      end_date = (Date.today + 3.day).strftime("%F").to_time.to_i

      sportsIds = ["6046", "48242", "54094"]

      #Fetching fixtures for all the 3 sport types
      sportsIds.each do |sport|
         puts "Starting #{sport} Pull"
         fixture_today = fetch_fixtures(start_date, end_date, sport)
      end

   end

   desc "Pull Fixtures and markets between dates"
   task pull_markets: :environment do
      puts "Starting Fixture Pull"
      
      start_date = Date.today.strftime("%F").to_time.to_i

      end_date = (Date.today + 3.day).strftime("%F").to_time.to_i

      sportsIds = ["6046", "48242", "54094"]

      #Fetching fixtures for all the 3 sport types
      sportsIds.each do |sport|
         puts "Starting #{sport} Pull"
         fixture_today = fetch_fixture_markets(sport)
      end

   end

end
