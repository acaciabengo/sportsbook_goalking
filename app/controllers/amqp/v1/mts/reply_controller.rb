class Amqp::V1::Mts::ReplyController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate
  require "uri"
  require "cgi"

  def create
    if confirm_params[:payload].present? &&
       confirm_params[:routing_key].present?
      payload = confirm_params[:payload]
      routing_key = confirm_params[:routing_key]
      message = JSON.parse(payload)

      #logs the received information
      Rails.logger.error("#{routing_key} - #{message}")
      TicketReplyWorker.perform_async(message, routing_key)
      render status: 200, json: { response: "OK" }
    else
      render status: 400, json: { response: "Failed" }
    end
  end

  private

  def confirm_params
    params.permit(:payload, :routing_key)
  end

  def authenticate
    auth_token = ENV["AUTH_TOKEN"]
    token = request.headers["access-token"]
    unless token == auth_token
      render json: { status: "Unauthorized. Invalid token" }
    end
  end
end
