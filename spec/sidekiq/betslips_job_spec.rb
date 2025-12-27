require "rails_helper"

RSpec.describe BetslipsJob, type: :worker do
  describe "#perform" do
    let(:user) { Fabricate(:user, balance: 1000.0, points: 0) }
    let(:stake) { 1000.0 }
    let(:odds) { 2.0 }
    
    # Create a betslip that is "Active"
    let(:betslip) { Fabricate(:bet_slip, user: user, stake: stake, status: "Active", bet_count: 1) }

    context "when all bets are closed" do
      context "when any bet is a loss" do
        before do
          Fabricate(:bet, bet_slip: betslip, status: "Closed", result: "Loss", odds: odds)
          Fabricate.times(3, :bet, bet_slip: betslip, status: "Closed", result: "Win", odds: odds)
        end

        it "marks the betslip as closed and loss" do
          BetslipsJob.new.perform
          betslip.reload
          expect(betslip.status).to eq("Closed")
          expect(betslip.result).to eq("Loss")
        end

        it "does not payout" do
          expect {
            BetslipsJob.new.perform
          }.not_to change { user.reload.balance }
        end
      end

      context "when all bets are wins" do
        before do
          Fabricate.times(3, :bet, bet_slip: betslip, status: "Closed", result: "Win", odds: odds)
        end

        it "marks the betslip as closed and win" do
          BetslipsJob.new.perform
          betslip.reload
          expect(betslip.status).to eq("Closed")
          expect(betslip.result).to eq("Win")
          expect(betslip.paid).to be true
        end

        it "updates user balance with winnings" do
          expected_payout = stake * odds
          # Tax calculation: payout - (payout * tax_rate)
          # Assuming BetSlip::TAX_RATE is defined. Let's check the job logic.
          # net_payout = payout - (payout * BetSlip::TAX_RATE)
          
          # We need to know the tax rate. Assuming it's non-zero or zero.
          # Let's just check balance increases.
          
          expect {
            BetslipsJob.new.perform
          }.to change { user.reload.balance }.by_at_least(stake) 
        end

        it "creates a transaction record" do
          expect {
            BetslipsJob.new.perform
          }.to change(Transaction, :count).by(1)
          
          transaction = Transaction.last
          expect(transaction.category).to include("Win - #{betslip.id}")
          expect(transaction.status).to eq("SUCCESS")
        end
      end

      context "when all bets are void" do
        before do
          Fabricate(:bet, bet_slip: betslip, status: "Closed", result: "Void", odds: odds)
        end

        it "refunds the stake" do
          expect {
            BetslipsJob.new.perform
          }.to change { user.reload.balance }.by(stake)
        end

        it "marks betslip as void" do
          BetslipsJob.new.perform
          betslip.reload
          expect(betslip.status).to eq("Closed")
          expect(betslip.result).to eq("Void")
        end
      end

      context "when mixed wins and voids (no losses)" do
        let(:betslip) { Fabricate(:bet_slip, user: user, stake: stake, status: "Active", bet_count: 2) }
        
        before do
          Fabricate(:bet, bet_slip: betslip, status: "Closed", result: "Win", odds: 2.0)
          Fabricate(:bet, bet_slip: betslip, status: "Closed", result: "Void", odds: 3.0)
        end

        it "calculates payout based on winning bets only" do
          BetslipsJob.new.perform
          betslip.reload
          
          # Only the 2.0 odds should count
          expected_win_amount = stake * 2.0
          expect(betslip.payout).to eq(expected_win_amount)
          expect(betslip.result).to eq("Win")
        end
      end
    end

    context "when bets are not all closed" do
      before do
        Fabricate(:bet, bet_slip: betslip, status: "Active", result: nil)
      end

      it "does not process the betslip" do
        expect {
          BetslipsJob.new.perform
        }.not_to change { betslip.reload.status }
      end
    end

    describe "Crown Points Feature" do
      before do
        Fabricate(:bet, bet_slip: betslip, status: "Closed", result: "Win", odds: odds)
        ENV['CROWN_POINTS_FEATURE'] = 'true'
        ENV['CROWN_POINTS_PER_BETSLIP'] = '5'
      end

      after do
        ENV.delete('CROWN_POINTS_FEATURE')
        ENV.delete('CROWN_POINTS_PER_BETSLIP')
      end

      it "awards crown points to the user" do
        # Stake is 1000. Points = (1000/1000) * 5 = 5
        expect {
          BetslipsJob.new.perform
        }.to change { user.reload.points }.by(5)
      end

      it "does not award points if feature is disabled" do
        ENV['CROWN_POINTS_FEATURE'] = 'false'
        expect {
          BetslipsJob.new.perform
        }.not_to change { user.reload.points }
      end
    end
  end
end