# require 'rails_helper'
# require 'sidekiq/testing'


# RSpec.describe "the betslip cancel process", type: :feature do
#    before :each do
#       @admin = create(:admin)
#       @user = create(:user)
#       @fixture = create(:fixture)
#       @market = create(:market)
#       @outcome = create(:outcome)
#       @betslip = create(:bet_slip, bet_count: 2, status: "Pending", odds: 5, potential_win_amount: 5000, stake: 1000, user_id: @user.id, created_at: (Time.now - 5.minutes))
#       @bet_one = create(:bet, fixture_id: @fixture.id, bet_slip_id: @betslip.id, odds: 2.5, user_id: @user.id, market_id: @market.id, outcome_id: @outcome.id, status: "Pending")
#       @bet_two = create(:bet, fixture_id: @fixture.id, bet_slip_id: @betslip.id, odds: 2.0, user_id: @user.id, market_id: @market.id, outcome_id: @outcome.id, status: "Pending")
#    end

#    it "logs in and cancels the ticket" do
#       visit '/backend'
#       within('#new_admin') do
#          fill_in "Email",	with: "acaciabengo@skylinesms.com"
#          fill_in "Password",	with: "jtwiqotbs@1Just"
#       end
#       click_button 'Login'

#       #then reach the betslip page
#       click_link 'BetSlips'
#       expect(page).to have_content 'Cancel'


#    end

#    it "logs in and cancels the ticket" do
#       visit '/backend'
#       within('#new_admin') do
#          fill_in "Email",	with: "acaciabengo@skylinesms.com"
#          fill_in "Password",	with: "jtwiqotbs@1Just"
#       end
#       click_button 'Login'

#       #then reach the betslip page
#       click_link 'BetSlips'
#       click_link 'Cancel'
#       expect(page).to have_content "BetSlip ##{@betslip.id}"


#    end
# end
