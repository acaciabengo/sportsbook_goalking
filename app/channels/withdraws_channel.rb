class WithdrawsChannel < ApplicationCable::Channel
  def subscribed
    if current_user
      stream_from "withdraws_#{current_user.id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end
end