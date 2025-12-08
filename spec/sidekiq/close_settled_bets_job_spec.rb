require "rails_helper"

RSpec.describe CloseSettledBetsJob, type: :worker do
  let(:fixture) { Fabricate(:fixture) }
  let(:market) { Fabricate(:pre_market, fixture: fixture, market_identifier: "1", specifier: "total=2.5") }

  let!(:winning_bet) do
    Fabricate(
      :bet,
      fixture: fixture,
      market_identifier: market.market_identifier,
      specifier: market.specifier,
      outcome: "1",
      status: "Active",
      bet_type: "PreMatch"
    )
  end

  let!(:losing_bet) do
    Fabricate(
      :bet,
      fixture: fixture,
      market_identifier: market.market_identifier,
      specifier: market.specifier,
      outcome: "2",
      status: "Active",
      bet_type: "PreMatch"
    )
  end

  let!(:void_bet) do
    Fabricate(
      :bet,
      fixture: fixture,
      market_identifier: market.market_identifier,
      specifier: market.specifier,
      outcome: "3",
      status: "Active",
      bet_type: "PreMatch"
    )
  end

  let(:results) do
    {
      "1" => {
        "status" => "W",
        "void_factor" => 0.0
      },
      "2" => {
        "status" => "L",
        "void_factor" => 0.0
      },
      "3" => {
        "status" => "C",
        "void_factor" => 1.0
      }
    }
  end

  before do
    market.update!(results: results)
  end

  describe "#perform" do
    it "processes bets and updates their statuses" do
      described_class.new.perform(fixture.id, market.id, "PreMatch")

      expect(winning_bet.reload.result).to eq("Win")
      expect(winning_bet.status).to eq("Closed")

      expect(losing_bet.reload.result).to eq("Loss")
      expect(losing_bet.status).to eq("Closed")

      expect(void_bet.reload.result).to eq("Void")
      expect(void_bet.status).to eq("Closed")
      expect(void_bet.void_factor).to eq(1.0)
    end

    it "updates winning bets" do
      described_class.new.perform(fixture.id, market.id, "PreMatch")

      expect(winning_bet.reload).to have_attributes(
        result: "Win",
        status: "Closed"
      )
    end

    it "updates losing bets" do
      described_class.new.perform(fixture.id, market.id, "PreMatch")

      expect(losing_bet.reload).to have_attributes(
        result: "Loss",
        status: "Closed"
      )
    end

    it "updates void bets with void_factor" do
      described_class.new.perform(fixture.id, market.id, "PreMatch")

      expect(void_bet.reload).to have_attributes(
        result: "Void",
        status: "Closed",
        void_factor: 1.0
      )
    end

    context "when bet has cancelled status" do
      before do
        market.update!(results: { "1" => { "status" => "C", "void_factor" => 0.0 } })
      end

      it "marks bet as void" do
        described_class.new.perform(fixture.id, market.id, "PreMatch")

        expect(winning_bet.reload.result).to eq("Void")
      end
    end

    context "when bet has void_factor greater than 0" do
      before do
        market.update!(results: { "1" => { "status" => "W", "void_factor" => 0.5 } })
      end

      it "marks bet as void and stores void_factor" do
        described_class.new.perform(fixture.id, market.id, "PreMatch")

        expect(winning_bet.reload).to have_attributes(
          result: "Void",
          status: "Closed",
          void_factor: 0.5
        )
      end
    end

    context "when market does not exist" do
      it "does not raise error and skips processing" do
        expect {
          described_class.new.perform(fixture.id, 99999, "PreMatch")
        }.not_to raise_error
      end
    end

    context "when no bets exist for fixture" do
      it "does not raise error" do
        expect {
          described_class.new.perform(999, market.id, "PreMatch")
        }.not_to raise_error
      end
    end

    context "when results hash is empty" do
      before do
        market.update!(results: {})
      end

      it "logs warning and returns early without updating bets" do
        expect(Rails.logger).to receive(:warn).with(/No results found/)
        
        described_class.new.perform(fixture.id, market.id, "PreMatch")

        expect(winning_bet.reload.status).to eq("Active")
        expect(losing_bet.reload.status).to eq("Active")
        expect(void_bet.reload.status).to eq("Active")
      end
    end

    it "only updates bets matching the specifier" do
      other_bet =
        Fabricate(
          :bet,
          fixture: fixture,
          market_identifier: market.market_identifier,
          specifier: "different=1.5",
          outcome: "1",
          status: "Active",
          bet_type: "PreMatch"
        )

      described_class.new.perform(fixture.id, market.id, "PreMatch")

      expect(winning_bet.reload.status).to eq("Closed")
      expect(other_bet.reload.status).to eq("Active") # Not updated
    end

    context "with Live market" do
      let(:live_market) { Fabricate(:live_market, fixture: fixture, market_identifier: "1", specifier: "total=2.5", results: results) }
      let!(:live_bet) do
        Fabricate(
          :bet,
          fixture: fixture,
          market_identifier: live_market.market_identifier,
          specifier: live_market.specifier,
          outcome: "1",
          status: "Active",
          bet_type: "Live"
        )
      end

      it "processes Live bets correctly" do
        described_class.new.perform(fixture.id, live_market.id, "Live")

        expect(live_bet.reload).to have_attributes(
          result: "Win",
          status: "Closed"
        )
      end
    end
  end

  describe "Sidekiq configuration" do
    it "is configured with high queue" do
      expect(described_class.sidekiq_options["queue"]).to eq("high")
    end

    it "has retry disabled" do
      expect(described_class.sidekiq_options["retry"]).to eq(false)
    end
  end
end
