class MarketAlert < ApplicationRecord
  include Recovery

  def check_producers
    (0..5).each do
      ["1", "3"].each do |product|
        if product == "3"
          threshold = 90
        end

        if product == "1"
          threshold = 20
        end
        last_update = MarketAlert.where(:product => product).last
        if last_update
          if ((Time.now.to_i) - last_update[:timestamp].to_i) > threshold
            #first close all active markets
            puts "Deactivation :: CHECK ::::: timestamp: #{timestamp}, new stamp: #{last_update[:timestamp]}, product: #{product}"
            DeactivateMarketsWorker.perform_async(product)

            #Restart the Feed
            restart_feed(product)
          end
        end
      end
    end

    sleep 12
  end
end
