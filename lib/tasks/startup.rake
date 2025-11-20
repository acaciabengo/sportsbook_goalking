desc "System Start up Tasks"

task system_start_up: :environment do
   
   ## Describe all required actions on system start up here below
   
   #Pull fixtures from today up to 3 days for the different sports
   date_today = Date.today.strftime("%F").to_time.to_i
   
   date_later = (Date.today + 3.day).strftime("%F").to_time.to_i
   
   sportsIds = ["6046", "48242", "54094"]
   
   sportsIds.each do |sport|
        fetch_fixtures(date_today, date_later, sport)
   end
   
   #Then pull the fixture markets for the different fixtures
   sportsIds.each do |sport|
        fetch_fixture_markets(sport)
   end
   
   ## Manually create market alerts for the 2 product types
   MarketAlert.create!(product: "1", timestamp: Time.now.to_i)
   MarketAlert.create!(product: "3", timestamp: Time.now.to_i)
   
end
