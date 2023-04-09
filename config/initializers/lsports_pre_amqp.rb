# initializer file for the AMQP connection between lsports and skyline sportsbook
# initialise class

require "bunny"

class LsportsPre
  # declare constants
  CONNECTION_THRESHOLD = 90.freeze
  PRODUCT = "3".freeze
  CONNECTION_HOST = "prematch-rmq.lsports.eu".freeze
  ALERTS_KEY = "lsports_pre_alerts".freeze
  STATUS_KEY = "lsports_pre_status".freeze

  def initialize
    @connection = Bunny.new(
      host: CONNECTION_HOST,
      port: 5672,
      username: ENV["LSPORTS_USERNAME"],
      password: ENV["LSPORTS_PASSWORD"],
      vhost: "Customers",
      heartbeat: 5,
      ack: false,
      loggers: [Rails.logger],
    )
  end

  def start
    @connection.start
    @channel = @connection.create_channel
    @queue = @channel.queue(
      "_4372_",
      exchange: "",
      durable: true,
      passive: true,
      auto_delete: false,
    )
    @exchange = @channel.default_exchange

    # write initial cache store
    RAILS.cache.write(ALERTS_KEY, Time.now.to_i)
    RAILS.cache.write(STATUS_KEY, 0)

    # call connection checker
    check_connection

    # call the message receiver
    listen
  end

  # method to start listening to the queue
  def listen
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
          Pre::FixtureChangeWorker.perform_async(message)
        when 2
          # process live scores
          Pre::LiveScoresWorker.perform_async(message)
        when 3
          # process odds
          Pre::OddsChangeWorker.perform_async(message)
        when 32
          # process alerts
          # extract the timestamp
          timestamp = message["Header"]["ServerTimestamp"]

          # write this to the cache store
          RAILS.cache.write(ALERTS_KEY, timestamp)
        when 35
          # process bet settlements
          # call bet settlement worker
          Live::BetSettlementWorker.perform_async(message)
        end
      end
    rescue => e
      Rails.logger.error("Error Processing LsportsPre \n message: #{e.message}\n#{e.backtrace.join("\n")}")
      # wait 10 seconds before trying to reconnect
      sleep 10
      # call the start method again
      start
    end
  end

  # method to stop listening to the queue
  def stop_listening
    @channel.close
    @connection.close
  end

  # method to check the connection status
  def check_connection
    # create a loop to check the connection
    Thread.new do
      while true
        # every 15 seconds check the connection
        # if current time - last update > 90 seconds,deactivate all markets
        last_update = RAILS.cache.read(ALERTS_KEY)
        status = RAILS.cache.read(STATUS_KEY)

        if (Time.now.to_i - last_update) > CONNECTION_THRESHOLD
          # change the connection status
          RAILS.cache.write(STATUS_KEY, 0)
          # deactivate markets
          DeactivateMarketsWorker.perform_async(PRODUCT)
        else
          RAILS.cache.write(STATUS_KEY, 1) if status == 0
        end
        sleep 15
      end
    end
  end
end

# run this is enviroment is not test
if Rails.env.production?
  # instantiate and start listening to the queue
  listener = LsportsPre.new
  listener.start
end
