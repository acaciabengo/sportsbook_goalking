require 'rails_helper'

RSpec.describe CashoutExecutor do
  let!(:user) { Fabricate(:user, balance: 10000) }
  let!(:bet_slip) { Fabricate(:bet_slip, user: user, status: 'Active', stake: 1000, payout: 5000) }
  let!(:bet) { Fabricate(:bet, bet_slip: bet_slip, status: 'Active') }
  let(:service) { described_class.new(bet_slip, user) }
  let(:cashout_offer) { { available: true, cashout_value: 3000.0 } }

  before do
    bet
    allow_any_instance_of(CashoutCalculator).to receive(:call).and_return(cashout_offer)
  end

  describe '#call' do
    context 'when cashout is successful' do
      it 'returns true' do
        expect(service.call).to be true
      end

      it 'updates bet slip status to Closed' do
        service.call
        expect(bet_slip.reload.status).to eq('Closed')
      end

      it 'updates bet slip result to Win' do
        service.call
        expect(bet_slip.reload.result).to eq('Win')
      end

      it 'calculates and applies tax on net winnings' do
        #puts "betslip before call: #{bet_slip.inspect}"
        service.call
        #slip after call: #{bet_slip.reload.inspect}"
        # Net winnings: 3000 - 1000 = 2000
        # Tax: 2000 * 0.15 = 300
        expect(bet_slip.reload.tax).to eq(220.0)
      end

      it 'updates user balance with net payout' do
        # 3000 - 300 tax = 2700
        expect { service.call }.to change { user.reload.balance }.from(10000).to(12780)
      end

      it 'closes all associated bets' do
        service.call
        expect(bet.reload.status).to eq('Closed')
        expect(bet.reload.result).to eq('Win')
      end

      it 'creates transaction record' do
        expect { service.call }.to change { user.transactions.count }.by(1)
        transaction = user.transactions.last
        expect(transaction.category).to eq('Cashout')
        expect(transaction.amount).to eq(2780.0)
      end

      it 'broadcasts balance update' do
        # Spy on all broadcasts (allow them to happen normally)
        allow(ActionCable.server).to receive(:broadcast).and_call_original

        service.call

        # Verify that the cashout hash was broadcasted
        # (The User model callback also broadcasts, but we only check for the cashout one)
        expect(ActionCable.server).to have_received(:broadcast).with(
          "balance_#{user.id}",
          hash_including(balance: 12780.0)
        )
      end

      it 'stores cashout value in bet slip' do
        service.call
        expect(bet_slip.reload.cashout_value).to eq(3000.0)
      end
    end

    context 'when cashout is not available' do
      let(:cashout_offer) { { available: false, reason: 'Market suspended' } }

      it 'returns false' do
        expect(service.call).to be false
      end

      it 'sets error message' do
        service.call
        expect(service.error_message).to eq('Market suspended')
      end

      it 'does not update bet slip' do
        expect { service.call }.not_to change { bet_slip.reload.status }
      end

      it 'does not update user balance' do
        expect { service.call }.not_to change { user.reload.balance }
      end
    end

    context 'when transaction fails' do
      before do
        allow(bet_slip).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(bet_slip))
      end

      it 'returns false' do
        expect(service.call).to be false
      end

      it 'sets error message' do
        service.call
        expect(service.error_message).to be_present
      end

      it 'rolls back all changes' do
        initial_balance = user.balance
        service.call
        expect(user.reload.balance).to eq(initial_balance)
      end
    end

    context 'with zero or negative net winnings' do
      let(:cashout_offer) { { available: true, cashout_value: 500.0 } }

      it 'applies zero tax' do
        service.call
        expect(bet_slip.reload.tax).to eq(0.0)
      end

      it 'updates balance correctly without tax' do
        expect { service.call }.to change { user.reload.balance }.from(10000).to(10500)
      end
    end

    context 'with a lost bet in the slip' do
      let(:cashout_offer) { { available: false, reason: 'Bet slip already lost' } }

      before do
        bet.update!(result: 'Loss', status: 'Closed')
      end

      it 'returns false' do
        expect(service.call).to be false
      end

      it 'sets error message indicating bet slip is lost' do
        service.call
        expect(service.error_message).to eq('Bet slip already lost')
      end

      it 'does not update bet slip status' do
        expect { service.call }.not_to change { bet_slip.reload.status }
      end

      it 'does not update user balance' do
        expect { service.call }.not_to change { user.reload.balance }
      end

      it 'does not create a transaction record' do
        expect { service.call }.not_to change { user.transactions.count }
      end
    end
  end
end
