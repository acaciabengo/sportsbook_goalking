class Backend::BroadcastsController < ApplicationController
  before_action :authenticate_admin!, except: [:process_broadcasts]
  before_action :set_broadcast, only: %i[destroy show]

  layout "admin_application"

  def index
    @broadcasts = Broadcast.all.order("created_at DESC").page params[:page]
  end

  def new
    @broadcast = Broadcast.new()
  end

  def create
    @broadcast =
      Broadcast.new(
        message: broadcast_params["message"],
        start_date: broadcast_params[:start_date].to_datetime,
        end_date: broadcast_params[:end_date].to_datetime,
        execution_time: broadcast_params[:execution_time].to_datetime,
        subject: broadcast_params[:subject],
        status: "PENDING",
        admin_id: current_admin.id
      )

    if @broadcast.save
      flash[:notice] = "Broadcast Successfully Created."
      redirect_to action: "index"
    else
      #show to error notice and show index
      flash.now[:alert] = @broadcast.errors
      render action: "new"
    end
  end

  def destroy
    @broadcast.destroy
    flash[:notice] = "Broadcast was successfully deleted."
    redirect_to action: "index"
  end

  def show
    user_array =
      Bet
        .distinct
        .where(
          "created_at >= ? AND created_at <= ?",
          @broadcast.start_date,
          @broadcast.end_date
        )
        .pluck(:user_id)
    @users = User.where("id IN (?)", user_array).page params[:page]
    @bets =
      Bet.where(
        "created_at >= ? AND created_at <= ?",
        @broadcast.start_date,
        @broadcast.end_date
      ).page params[:page]
    slips_array =
      Bet
        .distinct
        .where(
          "created_at >= ? AND created_at <= ?",
          @broadcast.start_date,
          @broadcast.end_date
        )
        .pluck(:bet_slip_id)
    @bet_slips = BetSlip.where("id IN (?)", slips_array).page params[:page]
  end

  def set_broadcast
    @broadcast = Broadcast.find(params[:id])
  end

  private

  def broadcast_params
    params.require(:broadcast).permit(
      :start_date,
      :end_date,
      :message,
      :execution_time,
      :status,
      :subject
    )
  end
end
