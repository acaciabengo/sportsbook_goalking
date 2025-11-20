require 'sidekiq'
class RecoveryWorker
   include Sidekiq::Worker
   sidekiq_options queue: "high"
   sidekiq_options retry: false

   def perform(product)
      if product == "3"
         #get a Snapshot
         alert = MarketAlert.where(product: product, subscribed: "1").last

         response = recover_fixture_markets(alert.timestamp.to_i  ,Time.now())

         if response == "200"
            #Re-activate all markets
            producer_type = {
               "1" => "Live",
               "3" => "Pre"
            }

            model_name = producer_type[product] + "Market"
            model_name.constantize.where(status: "Deactivated").update_all(status: "Active")

         end

      end

      if product == "1"
         response = get_live()
      end

   end
end
