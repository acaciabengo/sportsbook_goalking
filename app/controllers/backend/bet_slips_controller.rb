class Backend::BetSlipsController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"

  def index
    @q = BetSlip.all.ransack(params[:q])
    @bet_slips = @q.result.order("created_at DESC").page params[:page]

    respond_to do |format|
      format.html
      format.csv do
        send_data BetSlip.all.to_csv, filename: "betslips-#{Date.today}.csv"
      end
    end
  end

  def show
    @bet_slip = BetSlip.find(params[:id])
  end

  # def cancel
  #   @bet_slip = BetSlip.find(params[:slip])

  #   #make the request with code 103
  #   Mts::SubmitCancel.new.publish(slip_id: @bet_slip.id, code: 103)
  #   redirect_to action: 'show', id: @bet_slip.id
  # end
end
