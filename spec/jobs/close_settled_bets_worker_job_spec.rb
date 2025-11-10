# filepath: /Users/acacia/Desktop/work/skyline_sms/sportsbook_goalking/spec/jobs/close_settled_bets_worker_job_spec.rb
require "rails_helper"

RSpec.describe CloseSettledBetsWorker, type: :worker do
  let(:fixture) { Fabricate(:fixture) }
  let(:market_id) { "1" }
  let(:specifier) { "total=2.5" }

  let!(:winning_bet) do
    Fabricate(
      :bet,
      fixture: fixture,
      market_identifier: market_id,
      specifier: specifier,
      outcome: "1",
      status: "Active"
    )
  end

  let!(:losing_bet) do
    Fabricate(
      :bet,
      fixture: fixture,
      market_identifier: market_id,
      specifier: specifier,
      outcome: "2",
      status: "Active"
    )
  end

  let!(:void_bet) do
    Fabricate(
      :bet,
      fixture: fixture,
      market_identifier: market_id,
      specifier: specifier,
      outcome: "3",
      status: "Active"
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

  describe "#perform" do
    it "processes bets and updates their statuses" do
      described_class.new.perform(fixture.id, market_id, results, specifier)

      expect(winning_bet.reload.result).to eq("Win")
      expect(winning_bet.status).to eq("Closed")

      expect(losing_bet.reload.result).to eq("Loss")
      expect(losing_bet.status).to eq("Closed")

      expect(void_bet.reload.result).to eq("Void")
      expect(void_bet.status).to eq("Closed")
      expect(void_bet.void_factor).to eq(1.0)
    end

    it "updates winning bets" do
      described_class.new.perform(fixture.id, market_id, results, specifier)

      expect(winning_bet.reload).to have_attributes(
        result: "Win",
        status: "Closed"
      )
    end

    it "updates losing bets" do
      described_class.new.perform(fixture.id, market_id, results, specifier)

      expect(losing_bet.reload).to have_attributes(
        result: "Loss",
        status: "Closed"
      )
    end

    it "updates void bets with void_factor" do
      described_class.new.perform(fixture.id, market_id, results, specifier)

      expect(void_bet.reload).to have_attributes(
        result: "Void",
        status: "Closed",
        void_factor: 1.0
      )
    end

    context "when bet has cancelled status" do
      let(:results) { { "1" => { "status" => "C", "void_factor" => 0.0 } } }

      it "marks bet as void" do
        described_class.new.perform(fixture.id, market_id, results, specifier)

        expect(winning_bet.reload.result).to eq("Void")
      end
    end

    context "when bet has void_factor greater than 0" do
      let(:results) { { "1" => { "status" => "W", "void_factor" => 0.5 } } }

      it "marks bet as void and stores void_factor" do
        described_class.new.perform(fixture.id, market_id, results, specifier)

        expect(winning_bet.reload).to have_attributes(
          result: "Void",
          status: "Closed",
          void_factor: 0.5
        )
      end
    end

    context "when no bets exist for fixture" do
      it "does not raise error" do
        expect {
          described_class.new.perform(999, market_id, results, specifier)
        }.not_to raise_error
      end
    end

    context "when results hash is empty" do
      let(:results) { {} }

      it "marks all bets as loss" do
        described_class.new.perform(fixture.id, market_id, results, specifier)

        expect(winning_bet.reload.result).to eq("Loss")
        expect(losing_bet.reload.result).to eq("Loss")
        expect(void_bet.reload.result).to eq("Loss")
      end
    end

    it "only updates bets matching the specifier" do
      other_bet =
        Fabricate(
          :bet,
          fixture: fixture,
          market_identifier: market_id,
          specifier: "different=1.5",
          outcome: "1",
          status: "Active"
        )

      described_class.new.perform(fixture.id, market_id, results, specifier)

      expect(winning_bet.reload.status).to eq("Closed")
      expect(other_bet.reload.status).to eq("Active") # Not updated
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

  describe "bulk updates performance" do
    it "updates bets in bulk instead of individually" do
      expect(Bets).to receive(:update_all).at_least(3).times

      described_class.new.perform(fixture.id, market_id, results, specifier)
    end
  end
end
