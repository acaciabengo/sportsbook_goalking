require 'rails_helper'

RSpec.describe BetslipCreator do
  let(:user) { Fabricate(:user, balance: 10000) }
  let(:fixture) { Fabricate(:fixture) }
  let(:pre_market) { Fabricate(:pre_market, fixture: fixture, market_identifier: '1', odds: { '1' => { 'outcome_id' => 1, 'odd' => 2.5 } }) }
  let(:bets_data) do
    [{
      fixture_id: fixture.id,
      market_identifier: '1',
      odd: 2.5,
      outcome_id: 1,
      outcome: 'Home',
      specifier: nil,
      bet_type: 'PreMatch'
    }]
  end
  let(:params) { { stake: 1000, bets: bets_data, bonus: false } }
  let(:service) { described_class.new(user, params) }

  describe '#call' do
    before { pre_market }

    context 'with valid bet' do
      it 'creates bet slip successfully' do
        expect(service.call).to be true
        expect(service.bet_slip).to be_persisted
      end

      it 'deducts stake from user balance' do
        expect { service.call }.to change { user.reload.balance }.from(10000).to(9000)
      end

      it 'creates transaction record' do
        expect { service.call }.to change { user.transactions.count }.by(1)
      end

      it 'creates bets' do
        expect { service.call }.to change { Bet.count }.by(1)
      end
    end

    context 'with insufficient balance' do
      let(:params) { { stake: 20000, bets: bets_data, bonus: false } }

      it 'fails with error message' do
        expect(service.call).to be false
        expect(service.error_message).to eq('Insufficient balance')
      end
    end

    context 'with invalid stake range' do
      let(:params) { { stake: 5_000_000, bets: bets_data, bonus: false } }

      it 'fails with error message' do
        expect(service.call).to be false
        expect(service.error_message).to include('exceeds your current')
      end
    end

    context 'with bonus stake' do
      let!(:user_bonus) { Fabricate(:user_bonus, user: user, amount: 500, status: 'Active', expires_at: 1.day.from_now) }
      let(:params) { { bets: bets_data, bonus: true } }

      it 'uses bonus amount as stake' do
        service.call
        expect(service.bet_slip.stake).to eq(500)
      end

      it 'marks bonus as redeemed' do
        expect { service.call }.to change { user_bonus.reload.status }.from('Active').to('Redeemed')
      end

      it 'does not deduct from user balance' do
        expect { service.call }.not_to change { user.reload.balance }
      end
    end

    context 'with same game bets' do
      let!(:bets_data) do
        [
          { fixture_id: fixture.id, market_identifier: '1', odd: 2.0, outcome_id: 1, outcome: 'Home', specifier: nil, bet_type: 'PreMatch' },
          { fixture_id: fixture.id, market_identifier: '10', odd: 1.8, outcome_id: 2, outcome: 'Over 2.5', specifier: 'total=2.5', bet_type: 'PreMatch' }
        ]
      end
      let!(:pre_market2) { Fabricate(:pre_market, fixture: fixture, market_identifier: '10', specifier: 'total=2.5', odds: { '2' => { 'outcome_id' => 2, 'odd' => 1.8 } }) }
      let!(:params) { { stake: 5000, bets: bets_data, bonus: false } }

      before { pre_market2 }

      it 'applies discount to same game odds' do
        service.call
        bets = service.bet_slip.bets
        #puts "first bet: #{bets.first.odds}, \n second bet: #{bets.second.odds}"
        expect(bets.first.odds).to eq(1.8) # 2.0 * 0.9
        expect(bets.second.odds).to eq(1.62) # 1.8 * 0.9
      end

      it 'enforces same game stake limits' do
        invalid_service = described_class.new(user, { stake: 1000, bets: bets_data, bonus: false })
        expect(invalid_service.call).to be false
        expect(invalid_service.error_message).to include('should be between')
      end
    end

    context 'when odds change' do
      let(:pre_market) { Fabricate(:pre_market, fixture: fixture, market_identifier: '1', odds: { '1' => { 'outcome_id' => 1, 'odd' => 0.0 } }) }

      it 'fails with error message' do
        expect(service.call).to be false
        expect(service.error_message).to include('changed odds')
      end
    end
  end
end
