class Live::SuspendBetsJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 1

  def perform()
    # find all active live_markets and suspend them
    LiveMarket.where(status: 'active').update_all(status: 'suspended')
  end
end
