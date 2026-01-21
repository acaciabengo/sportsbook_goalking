class Webhooks::RelworksController < ApplicationController
  skip_before_action :verify_authenticity_token, raise: false

  def deposits
    Rails.logger.info("Relworks deposit webhook received: #{params.inspect}")

    args = extract_params

    if args[:internal_reference].blank?
      Rails.logger.error("Missing internal_reference in Relworks deposit webhook")
      return render status: 400, json: { error: "Missing internal_reference" }
    end

    CompleteRelworksDepositJob.perform_async(args[:internal_reference], args[:status], args[:message])
      

    render status: 200, json: { response: "OK" }
  rescue StandardError => e
    Rails.logger.error("Relworks deposit webhook error: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    render status: 200, json: { response: "OK" }
  end

  def withdraws
    Rails.logger.info("Relworks withdraw webhook received: #{params.inspect}")

    args = extract_params

    if args[:internal_reference].blank?
      Rails.logger.error("Missing internal_reference in Relworks withdraw webhook")
      return render status: 400, json: { error: "Missing internal_reference" }
    end

    CompleteRelworksWithdrawJob.perform_async(args[:internal_reference], args[:status], args[:message])

    render status: 200, json: { response: "OK" }
  rescue StandardError => e
    Rails.logger.error("Relworks withdraw webhook error: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    render status: 200, json: { response: "OK" }
  end

  private

  def extract_params
    {
      status: params[:status],
      message: params[:message],
      customer_reference: params[:customer_reference],
      internal_reference: params[:internal_reference],
      msisdn: params[:msisdn],
      amount: params[:amount],
      currency: params[:currency],
      provider: params[:provider],
      charge: params[:charge],
      completed_at: params[:completed_at]
    }.compact
  end
  
end
