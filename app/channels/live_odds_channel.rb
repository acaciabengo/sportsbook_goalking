# app/channels/live_odds_channel.rb
class LiveOddsChannel < ApplicationCable::Channel
  def subscribed
    # add logging to track subscriptions
    Rails.logger.info "Subscribing to LiveOddsChannel with params: #{params.inspect}"
    stream_from "live_odds_#{params[:market_identifier]}_#{params[:fixture_id]}"
  end

  def unsubscribed
    stop_all_streams
  end
end
