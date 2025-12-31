require 'rails_helper'

RSpec.describe Fixture, type: :model do
  # test that the check_scores method is called after create or update
  # text that the TwoUpFeatureJob is enqueued when the score difference is exactly 2 for soccer fixtures
  
  context 'after commit callbacks' do
    let!(:fixture) { Fabricate(:fixture, sport_id: "1", home_score: 0, away_score: 0) }

    before do
      allow(TwoUpFeatureJob).to receive(:perform_async)
    end
    
    it 'enqueues TwoUpFeatureJob when score difference is exactly 2 for soccer' do
      fixture.update(home_score: "2", away_score: "0")
      
      expect(TwoUpFeatureJob).to have_received(:perform_async).with(fixture.id, 2, 0).once

      fixture.update(home_score: "1", away_score: "3")
      expect(TwoUpFeatureJob).to have_received(:perform_async).with(fixture.id, 1, 3).once
      
    end

    it 'does not enqueue TwoUpFeatureJob when score difference is not 2' do
      fixture.update(home_score: "1", away_score: "0")
      expect(TwoUpFeatureJob).not_to have_received(:perform_async)

      fixture.update(home_score: "3", away_score: "0")
      expect(TwoUpFeatureJob).not_to have_received(:perform_async)
    end 
  end
end
