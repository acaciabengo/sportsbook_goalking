require 'rails_helper'
RSpec.describe TwoUpFeatureJob, type: :worker do
  # test that the job updates bets correctly
  # create bets with multiple markets, outcomes, and statuses
  # 2 status closed, 5 status active
  # only 2 status active, market 1X2, outcome home win or away win should be updated to won
  # the rest should remain unchanged and different sports or markets or outcomes
  
  let!(:soccer_fixture) { Fabricate(:fixture, sport_id: "1") }
  let!(:other_fixture) { Fabricate(:fixture, sport_id: "2") }

  let!(:worker) { described_class.new }

  let!(:bet1) { Fabricate(:bet, fixture: soccer_fixture, market_identifier: "1", outcome: "1", status: "Active", bet_type: "PreMatch") } # should be won
  let!(:bet2) { Fabricate(:bet, fixture: soccer_fixture, market_identifier: "1", outcome: "3", status: "Active", bet_type: "PreMatch") } # should be won
  let!(:other_bets) { Fabricate.times( 5, :bet, fixture: soccer_fixture, market_identifier: "1", outcome: "1", status: "closed") } # closed bets
  let!(:bet3) { Fabricate(:bet, fixture: soccer_fixture, market_identifier: "2", outcome: "1", status: "Active", bet_type: "PreMatch") } # different market,
  let!(:bet4) { Fabricate(:bet, fixture: other_fixture, market_identifier: "1", outcome: "1", status: "Active", bet_type: "PreMatch") } # different sport
  let!(:bet5) { Fabricate(:bet, fixture: soccer_fixture, market_identifier: "1", outcome: "1", status: "Active", bet_type: "Live") } # should be won
  

  context 'performing the job' do
    it 'updates the correct bets as won and settled' do
      home_score = 3
      away_score = 1

      worker.perform(soccer_fixture.id, home_score, away_score)

      bet1.reload
      bet2.reload
      bet3.reload
      bet4.reload

      expect(bet1.result).to eq('Win')
      expect(bet1.status).to eq('Closed')

      expect(bet2.result).to be_nil
      expect(bet2.status).to eq('Active')

      # other bets should remain unchanged
      expect(bet3.result).to be_nil
      expect(bet3.status).to eq('Active')

      expect(bet4.result).to be_nil
      expect(bet4.status).to eq('Active')
    end

    it "updates the bests for away team win" do
      home_score = 1
      away_score = 3

      worker.perform(soccer_fixture.id, home_score, away_score)

      bet1.reload
      bet2.reload

      expect(bet1.result).to be_nil
      expect(bet1.status).to eq('Active')

      expect(bet2.result).to eq('Win')
      expect(bet2.status).to eq('Closed')
    end
  end

end
