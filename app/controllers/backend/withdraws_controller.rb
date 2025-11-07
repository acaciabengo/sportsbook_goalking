class Backend::WithdrawsController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"

  def index
    authorize! :index,
               :withdraw,
               message: "You are not authorized to view this page..."
    @q = Withdraw.all.ransack(params[:q])
    @withdraws = @q.result.order("created_at DESC").page params[:page]
    @search_params = params[:q]
    respond_to do |format|
      format.html
      format.csv do
        send_data Withdraw.all.to_csv, filename: "withdraws-#{Date.today}.csv"
      end
    end
  end
end
