require "rails_helper"
require "sidekiq/testing"
Sidekiq::Testing.fake!

RSpec.describe OddsChangeWorker, type: :worker do
  describe "#perform" do
    let(:job) { described_class.new }
    let(:message) { { "Body" => { "Events" => events } } }
    let(:events) { [] }
    let(:product) { "3" }

    before do
      allow(double(described_class)).to receive(:process_odds_change)
    end

    it "does not raise an error when events are nil" do
      expect(subject).to_not receive(:process_odds_change)
      job.perform(message, product)
    end

    it "processes events" do
      event = { "FixtureId" => 123, "Markets" => [{ "Providers" => [{ "Bets" => [] }] }] }
      events << event
      expect(job).to receive(:process_odds_change).with(event["FixtureId"], event["Markets"].first).once
      job.perform(message, product)
    end

    it "skips processing when fixture is not found" do
      event = { "FixtureId" => 123, "Markets" => [{ "Providers" => [{ "Bets" => [] }] }] }
      events << event

      expect(Fixture).to receive(:find_by).with(event_id: event["FixtureId"]).and_return(nil)
      expect(double(Fixture)).not_to receive(:pre_markets)

      job.perform(message, product)
    end
  end

  describe "#process_odds_change" do
    let(:event_id) { 123 }
    let(:market) { { "Providers" => [] } }
    let(:fixture) { Fabricate(:fixture, event_id: event_id) }

    it "skips processing when fixture is not found" do
      expect(Fixture).to receive(:find_by).with(event_id: event_id).and_return(nil)

      subject.process_odds_change(event_id, market)

      expect(fixture.reload.odds_changes.count).to eq(0)
    end

    it "creates a new odds change entry" do
      expect(Fixture).to receive(:find_by).with(event_id: event_id).and_return(fixture)

      provider = { "Bets" => [{ "BaseLine" => "baseline", "Name" => "win", "Price" => 2.0, "Status" => 1 }] }
      market["Providers"] << provider

      expect { subject.process_odds_change(event_id, market) }.to change { fixture.reload.odds_changes.count }.by(1)

      odds_change = fixture.reload.odds_changes.last
      expect(odds_change.market_identifier).to eq(market["Id"])
      expect(odds_change.specifier).to eq("baseline")
      expect(odds_change.status).to eq("Active")
      expect(odds_change.odds).to eq({ "outcome_win" => 2.0 })
    end

    it "updates an existing odds change entry" do
      expect(Fixture).to receive(:find_by).with(event_id: event_id).and_return(fixture)

      provider = { "Bets" => [{ "BaseLine" => "baseline", "Name" => "win", "Price" => 2.0, "Status" => 1 }] }
      market["Providers"] << provider

      subject.process_odds_change(event_id, market)

      provider["Bets"].first["Price"] = 3.0

      expect { subject.process_odds_change(event_id, market) }.not_to change { fixture.reload.odds_changes.count }

      odds_change = fixture.reload.odds_changes.last
      expect(odds_change.odds).to eq()
    end
  end
end
