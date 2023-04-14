require "rails_helper"

RSpec.describe LsportsPre do
  let(:lsports_pre) { described_class.new }

  describe "#initialize" do
    it "creates a new Bunny connection" do
      expect(Bunny).to receive(:new).once
      lsports_pre
    end

    it "sets the connection options correctly" do
      expect(Bunny).to receive(:new).with(
        {
          host: LsportsPre::CONNECTION_HOST,
          port: 5672,
          username: ENV["LSPORTS_USERNAME"],
          password: ENV["LSPORTS_PASSWORD"],
          vhost: "Customers",
          heartbeat: 5,
          ack: false,
          loggers: [Rails.logger],
        }
      )
      lsports_pre
    end
  end

  describe "#start" do
    let(:connection) { instance_double(Bunny) }
    let(:channel) { instance_double(Bunny::Channel) }
    let(:queue) { instance_double(Bunny::Queue) }
    let(:exchange) { instance_double(Bunny::Exchange) }

    before do
      allow(lsports_pre.instance_variable_get(:@connection)).to receive(:start)
      allow(lsports_pre.instance_variable_get(:@connection)).to receive(:create_channel).and_return(channel)
      allow(channel).to receive(:queue).and_return(queue)
      allow(channel).to receive(:default_exchange).and_return(exchange)
      allow(Rails.cache).to receive(:write)
      allow(lsports_pre).to receive(:check_connection)
      allow(lsports_pre).to receive(:listen)
    end

    it "starts the Bunny connection" do
      expect(lsports_pre.instance_variable_get(:@connection)).to receive(:start).once
      lsports_pre.start
    end

    it "creates a channel" do
      expect(lsports_pre.instance_variable_get(:@connection)).to receive(:create_channel).once
      lsports_pre.start
    end

    it "creates a queue" do
      expect(channel).to receive(:queue).with(
        "_4372_",
        exchange: "",
        durable: true,
        passive: true,
        auto_delete: false,
      ).once
      lsports_pre.start
    end

    it "creates a default exchange" do
      expect(channel).to receive(:default_exchange).once
      lsports_pre.start
    end

    it "writes to the cache store" do
      expect(Rails.cache).to receive(:write).with(LsportsPre::ALERTS_KEY, an_instance_of(Integer))
      expect(Rails.cache).to receive(:write).with(LsportsPre::STATUS_KEY, 0)
      lsports_pre.start
    end

    it "calls #check_connection" do
      expect(lsports_pre).to receive(:check_connection).once
      lsports_pre.start
    end

    it "calls #listen" do
      expect(lsports_pre).to receive(:listen).once
      lsports_pre.start
    end
  end

  describe "#listen" do
    let(:connection) { instance_double(Bunny) }
    let(:channel) { instance_double(Bunny::Channel) }
    let(:queue) { instance_double(Bunny::Queue) }
    let(:exchange) { instance_double(Bunny::Exchange) }
    let(:message) { { "Header" => { "Type" => 1 } } }

    before do
      allow(lsports_pre.instance_variable_get(:@connection)).to receive(:start)
      allow(lsports_pre.instance_variable_get(:@connection)).to receive(:create_channel).and_return(channel)
      allow(channel).to receive(:queue).and_return(queue)
      allow(channel).to receive(:default_exchange).and_return(exchange)
      allow(Rails.cache).to receive(:write)
      allow(lsports_pre).to receive(:sleep)
      allow(queue).to receive(:subscribe).and_yield(nil, nil, message.to_json)
      allow(FixtureChangeWorker).to receive(:perform_async)
    end

    it "subscribes to the queue" do
      expect(queue).to receive(:subscribe).once
      expect(FixtureChangeWorker).to receive(:perform_async).once
      lsports_pre.start
    end
  end

  describe "#check_connection" do
  end
end
