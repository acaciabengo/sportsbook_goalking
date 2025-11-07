class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception, prepend: true
  include Pagy::Backend

  before_action :configure_permitted_parameters, if: :devise_controller?
  # before_action :set_raven_context
  before_action :set_current_user
  # before_action :detect_device_variant
  before_action :set_no_cache

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
        format.json { head :forbidden, content_type: 'text/html' }
        format.html { redirect_to authenticated_admins_root_url, alert: exception.message }
        format.js   { head :forbidden, content_type: 'text/html' }
    end
  end


  private

  def set_current_user
    if user_signed_in?
      current_user && return
    else
      current_user = nil
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    resource_or_scope == :admin ? unauthenticated_admins_root_path : root_path
  end

  def set_no_cache
    response.headers['Cache-Control'] =
      'no-cache, no-store, max-age=0, must-revalidate'
    response.headers['Pragma'] = 'no-cache'
    response.headers['Expires'] = 'Fri, 01 Jan 1990 00:00:00 GMT'
  end

  def current_ability
    if current_user
      @current_ability ||=  Ability.new(current_user)
    elsif current_admin
      @current_ability ||=  AdminAbility.new(current_admin)
    end
  end

  protected

  def configure_permitted_parameters
    added_attrs = %i[
      phone_number
      email
      password
      password_confirmation
      remember_me
      first_name
      last_name
      agreement
      nationality
      id_number
    ]
    devise_parameter_sanitizer.permit :sign_up, keys: added_attrs
    devise_parameter_sanitizer.permit :account_update, keys: added_attrs
    devise_parameter_sanitizer.permit(:sign_in, keys: [:phone_number])
  end

  def set_raven_context
    Raven.user_context(id: session[:current_user_id]) # or anything else in session
    Raven.extra_context(params: params.to_unsafe_h, url: request.url)
  end

  # def redirect_if_unverified
  #   if user_signed_in? && !current_user.verified?
  #     redirect_to new_verify_url, format: :json
  #   end
  # end

  # def detect_device_variant
  #   request.variant = :phone if (
  #     browser.device.mobile? || browser.device.tablet?
  #   )
  # end
end
