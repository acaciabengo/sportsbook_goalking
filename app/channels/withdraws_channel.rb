class WithdrawsChannel < ApplicationCable::Channel
  def subscribed
    # reject if no current_user exits
    reject_unauthorized_connection unless current_user
    

    stream_from "withdraws_#{current_user.id}"
  end

  def unsubscribed
    stop_all_streams
  end
end