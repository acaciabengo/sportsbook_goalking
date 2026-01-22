require 'rails_helper'

RSpec.describe CashoutCalculator do
  let(:user) { Fabricate(:user) }
  let(:fixture) { Fabricate(:fixture) }
  let(:bet_slip) { Fabricate(:bet_slip, user: user, status: 'Active', stake: 1000, payout: 5000, odds: 5.0) }
  let(:bet) { Fabricate(:bet, bet_slip: bet_slip, fixture: fixture, market_identifier: '1', specifier: nil, outcome: 1, odds: 2.5, status: 'Active', bet_type: 'PreMatch') }
  let(:service) { described_class.new(bet_slip) }

  describe '#call' do
    context 'when cashout is available' do
      let!(:pre_market) { Fabricate(:pre_market, fixture: fixture, market_identifier: '1', odds: { '1' => { 'outcome_id' => 1, 'odd' => 3.0 } }, status: 'active') }

      before { bet }

      it 'returns available with cashout value' do
        result = service.call
        expect(result[:available]).to be true
        expect(result[:cashout_value]).to be > 0
      end

      it 'calculates cashout with margin' do
        result = service.call
        expected = ((1000 *( 5/3.0)) * 0.80).round(2)
        expect(result[:cashout_value]).to eq(expected)
      end

      it 'includes potential win and stake' do
        result = service.call
        expect(result[:potential_win]).to eq(5000.0)
        expect(result[:stake]).to eq(1000.0)
      end
    end

    context 'when bet slip is not active' do
      let(:bet_slip) { Fabricate(:bet_slip, user: user, status: 'Closed', stake: 1000, payout: 5000) }

      it 'returns unavailable' do
        result = service.call
        expect(result[:available]).to be false
        expect(result[:reason]).to eq('Bet slip already settled')
      end
    end

    context 'when market is no longer available' do
      before { bet }

      it 'returns unavailable' do
        result = service.call
        expect(result[:available]).to be false
        expect(result[:reason]).to include('no longer available')
      end
    end

    context 'when fixture is cancelled' do
      let(:fixture) { Fabricate(:fixture, status: 'cancelled') }
      let!(:pre_market) { Fabricate(:pre_market, fixture: fixture, market_identifier: '1', odds: { '1' => { 'outcome_id' => 1, 'odd' => 3.0 } }) }

      before { bet }

      it 'returns unavailable' do
        result = service.call
        expect(result[:available]).to be false
        expect(result[:reason]).to eq('One or more fixtures cancelled')
      end
    end

    context 'with closed bet in slip' do
      let(:bet) { Fabricate(:bet, bet_slip: bet_slip, fixture: fixture, status: 'Closed', odds: 2.5) }
      let(:bet2) { Fabricate(:bet, bet_slip: bet_slip, fixture: fixture, market_identifier: '10', outcome: 2, odds: 2.0, status: 'Active', bet_type: 'PreMatch') }
      let!(:pre_market) { Fabricate(:pre_market, fixture: fixture, market_identifier: '10', odds: { '2' => { 'outcome_id' => 2, 'odd' => 2.5 } }) }

      before do
        bet
        bet2
      end

      it 'uses stored odds for closed bets' do
        result = service.call
        expect(result[:available]).to be true
        # Should multiply closed bet odds (2.5) with current odds (2.5)
        expect(result[:current_odds]).to eq(6.25)
      end
    end

    context 'with a lost bet in the slip' do
      let(:bet4) { Fabricate(:bet, bet_slip: bet_slip, fixture: fixture, status: 'Closed', odds: 2.5, result: 'Loss') }
      let(:bet5) { Fabricate(:bet, bet_slip: bet_slip, fixture: fixture, market_identifier: '10', outcome: 2, odds: 2.0, status: 'Active', bet_type: 'PreMatch') }
      
      before do
        bet4
        bet5
      end

      it 'returns unavailable' do
        result = service.call
        expect(result[:available]).to be false
      end
    end

    

    # context 'when cashout value is too low' do
    #   let(:bet_slip) { Fabricate(:bet_slip, user: user, status: 'Active', stake: 5000, payout: 5100, odds: 1.02) }
    #   let!(:pre_market) { Fabricate(:pre_market, fixture: fixture, market_identifier: '1', odds: { '1' => { 'outcome_id' => 1, 'odd' => 1.01 } }, status: 'active') }

    #   before { bet }

    #   it 'returns unavailable' do
    #     result = service.call
    #     expect(result[:available]).to be false
    #     expect(result[:reason]).to eq('Cashout value too low')
    #   end
    # end
  end
end
