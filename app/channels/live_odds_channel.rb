class LiveOddsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "live_odds_#{params[:market_identifier]}_#{params[:fixture_id]}"
  end

  def unsubscribed
    stop_all_streams
  end
end
