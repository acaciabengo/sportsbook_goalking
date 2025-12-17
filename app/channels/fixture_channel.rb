class FixtureChannel < ApplicationCable::Channel
  def subscribed
    stream_from "fixture_#{params[:fixture_id]}"
  end

  def unsubscribed
    stop_all_streams
  end
end

