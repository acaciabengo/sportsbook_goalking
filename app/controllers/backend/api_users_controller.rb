class Backend::ApiUsersController < ApplicationController
  before_action :authenticate_admin!

  load_and_authorize_resource

  layout "admin_application"

  require "mobile_money/mtn_open_api"

  def index
    @api_users = ApiUser.all.order("created_at DESC")
  end

  def new
    @api_user = ApiUser.new
  end

  def create
    @api_user = ApiUser.new(api_user_params)
    @api_user.api_id = generate_uuid
    if @api_user.save
      flash[:notice] = "API User Successfully Created."
      redirect_to action: "index"
    else
      flash.now[:alert] = @api_user.errors
      render action: "new"
    end
  end

  def generate_api_keys
    @api_user = ApiUser.find(params[:id])
    if !@api_user.registered?
      if MobileMoney::MtnOpenApi.register_api_user(@api_user.api_id) == true
        @api_user.update(registered: true)
      end
    end

    api_key = nil
    if @api_user.registered?
      api_key = MobileMoney::MtnOpenApi.receive_api_key(@api_user.api_id)

      if api_key && @api_user.update(api_key: api_key)
        flash[:notice] = "API Key Successfully Created."
        redirect_to action: "index"
      else
        flash[:alert] = "Oops! Something Went Wrong"
        redirect_to action: "index"
      end
    else
      flash[:alert] = "Oops! Something Went Wrong. Please Try Again."
      redirect_to action: "index"
    end
  end

  private

  def api_user_params
    params.require(:api_user).permit(:first_name, :last_name, :user_type)
  end

  def generate_uuid
    loop do
      uuid = SecureRandom.uuid
      break uuid unless ApiUser.where(api_id: uuid).exists?
    end
  end
end
