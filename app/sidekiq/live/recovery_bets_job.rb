class Live::RecoveryBetsJob
  include Sidekiq::Job
  sidekiq_options queue: :critical, retry: 1

  CHANNEL = 'live_feed_commands'

  def perform()
    #  Find all fixtures with status in_play and match_status live and request the latest data
    sql = <<-SQL
        SELECT id, event_id FROM fixtures
        WHERE status = 'active' AND match_status = 'in_play'
      SQL

    fixtures = ActiveRecord::Base.connection.exec_query(sql).to_a

    fixtures.batch(10) do |fixture_batch|
        # construct XML request for this batch
        #  <BookmakerStatus timestamp="0">
        #   <Match matchid="661373" />
        # </BookmakerStatus>
        # 
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.BookmakerStatus(timestamp: '0') {
            fixture_batch.each do |fixture|
              xml.Match(matchid: fixture["event_id"])
            end
          }
        end

        xml_request = builder.to_xml

        # connect to redis and publish the request
        redis = Redis.new(url: ENV['REDIS_URL'])
        redis.publish(CHANNEL, xml_request)
    end

    # Trigger a pre_match odds update
    PreMatch::PullOddsJob.perform_async()
  end
  
end
