class DepositsChannel < ApplicationCable::Channel
  def subscribed
    # reject if no current_user
    reject_unauthorized_connection unless current_user

    stream_from "deposits_#{current_user.id}"
  end

  def unsubscribed
    stop_all_streams
  end
end