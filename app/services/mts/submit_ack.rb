class Mts::SubmitAck
  require "json"
  require "json/ext"

  QUEUE_NAME = "skyline_skyline-Reply-node#{ENV["NODE_ID"]}".freeze
  EXCHANGE_NAME = "skyline_skyline-Ack".freeze

  def publish(slip_id:, code:, status:)

    #connect to the mqp and send ticket
    channel = BunnyQueueService.connection.create_channel
    exchange = channel.topic(
      EXCHANGE_NAME,
      :durable => true,
    )

    #bind to the exchange then publish
    json_data = payload(slip_id: slip_id, ts: (Time.now.to_i * 1000), code: code, status: status)
    Rails.logger.error(json_data)
    exchange.publish(json_data, routing_key: "ack.cancel")
  end

  private

  def payload(slip_id:, ts:, code:, status:)
    #form the json object
    data = {
      "sender" => {
        "bookmakerId" => ENV["BOOKMAKER_ID"],
      },
      "ticketId" => slip_id,
      "ticketStatus" => "#{status}",
      "code" => code,
      "message" => "Ticket #{status}",
      "timestampUtc" => ts,
      "version" => "2.3",
    }

    json_data = JSON.generate(data)
    return json_data
  end
end
