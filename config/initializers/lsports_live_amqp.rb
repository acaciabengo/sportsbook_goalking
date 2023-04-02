# initializer file for the AMQP connection between lsports and skyline sportsbook
# initialise class

require "bunny"

class LsportsLive
  def initialize
    @connection = Bunny.new(
      host: "inplay-rmq.lsports.eu",
      port: 5672,
      username: ENV["LSPORTS_USERNAME"],
      password: ENV["LSPORTS_PASSWORD"],
      vhost: "Customers",
      heartbeat: 5,
      ack: false,
      loggers: [Rails.logger],
    )
    @connection.start
    @channel = @connection.create_channel
    @queue = @channel.queue(
      "_4373_",
      exchange: "",
      durable: true,
      passive: true,
      auto_delete: false,
    )
    @exchange = @channel.default_exchange
  end

  # method to start listening to the queue
  def start_listening
    begin
      # start listening to the queue
      @queue.subscribe do |delivery_info, properties, payload|
        # process the message
        # decode the JSON message
        message = JSON.parse(payload)
        # extract the message type
        message_type = message.dig("Header", "Type")

        # write case for the different types. Expected 32, 3, 1, 35, 2
        case message_type
        when 1
          # process fixtures
          Live::FixtureChangeWorker.perform_async(message)
        when 2
          # process live scores
          Live::LiveScoresWorker.perform_async(message)
        when 3
          # process odds
          Live::OddsChangeWorker.perform_async(message)
        when 32
          # process alerts
          Live::AlertsWorker.perform_async(message)
        when 35
          # process bet settlements
          # call bet settlement worker
          Live::BetSettlementWorker.perform_async(message)
        end
      end
    rescue
      Rails.logger.error("Error Processing LsportsLive \n message: #{e.message}\n#{e.backtrace.join("\n")}")
    end
  end

  # method to stop listening to the queue
  def stop_listening
    @channel.close
    @connection.close
  end
end

# instantiate and start listening to the queue
listener = LsportsLive.new
listener.start_listening
