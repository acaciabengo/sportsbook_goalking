# require 'rails_helper'
# require 'sidekiq/testing'


# RSpec.describe User, type: :system, js: true do
# 	describe 'Place bet' do
# 		fixture = Fixture.joins(:market1_pre).where("fixtures.status = ?
# 			AND fixtures.sport_id = ? AND fixtures.category_id NOT IN (?)
# 			AND fixtures.scheduled_time >= ? AND fixtures.scheduled_time <= ?
# 			AND market1_pres.status = ?", "not_started", "sr:sport:1",
# 			["sr:category:1033","sr:category:2123"], (Date.today.beginning_of_day),
# 			 (Date.today.end_of_day + 1.days),"Active").limit(1)[0]

# 		user = User.create({
# 					email: Faker::Internet.email,
# 					phone_number: '25677'+ rand(1000000..9999999).to_s,
# 					first_name: Faker::Name.first_name,
# 					last_name: Faker::Name.last_name,
# 					password: "Jtwitw@c2016",
# 					password_confirmation: "Jtwitw@c2016",
# 					agreement: true
# 				})
# 		user.update(verified: true)
# 		user.update(balance:5000)


# 		def login_form(phone_number, password)
# 			visit '/users/sign_in'
# 			fill_in 'phone_number', with: phone_number
# 			fill_in 'password', with: password
# 			click_button 'Login'
# 		end

# 		##place bet test for soccer games
# 		it '(Soccer)should be successful when a user is logged in' do
# 			slip_count = BetSlip.count
# 			puts slip_count
# 			login_form(user.phone_number, user.password)
# 			expect(page).to have_content('Upcoming Fixtures - Soccer')
# 			expect(page).to have_content('Betslip')
# 			# first("#pre_2_#{fixture.id}").click
# 			first('a', :class => "intialise_input").click
# 			stake = 2000
# 			fill_in 'stake', with: stake
# 			expect(stake).to be <= user.balance
# 			expect(stake).to be > 0
# 			expect('total-wins'.to_f).to eq('total-odds'.to_f * 'stake-input'.to_i)
# 			click_button('Place Bet')
# 			expect(page).to have_content 'Thank You! Bets have been placed.'
# 			new_balance = user.balance-stake
# 			user.update(balance:new_balance)
# 			expect(user.balance).to eq(new_balance)
# 			expect(page.current_path).to eq '/'

# 			expect(BetSlip.count).to eq(slip_count+1)
# 			 puts BetSlip.count

# 		end

# 			##place bet test for virtual soccer games
# 			it '(Virtual Soccer)should be successful when a user is logged in' do
# 			slip_count = BetSlip.count
# 			puts slip_count
# 			login_form(user.phone_number, user.password)
# 			expect(page).to have_content('Upcoming Fixtures - Soccer')
# 			expect(page).to have_content('Betslip')
# 			click_link("Virtual Soccer")
# 			# first("#pre_2_#{fixture.id}").click
# 			first('a', :class => "intialise_input").click
# 			stake = 2000
# 			fill_in 'stake', with: stake
# 			expect(stake).to be <= user.balance
# 			expect(stake).to be > 0
# 			expect('total-wins'.to_f).to eq('total-odds'.to_f * 'stake-input'.to_i)
# 			click_button('Place Bet')
# 			expect(page).to have_content 'Thank You! Bets have been placed.'
# 			new_balance = user.balance-stake
# 			user.update(balance:new_balance)
# 			expect(user.balance).to eq(new_balance)
# 			expect(page.current_path).to eq '/fixtures/virtual_soccer/pres'

# 			expect(BetSlip.count).to eq(slip_count+1)
# 			 puts BetSlip.count

# 		end

# 		##uncomment this block below if you have live games.

# 		# it '(Live Soccer)should be successful when a user is logged in' do
# 		# 	slip_count = BetSlip.count
# 		# 	puts slip_count
# 		# 	login_form(user.phone_number, user.password)
# 		# 	expect(page).to have_content('Upcoming Fixtures - Soccer')
# 		# 	expect(page).to have_content('Betslip')
# 		# 	click_link("Live Games")
# 		# 	# first("#pre_2_#{fixture.id}").click
# 		# 	first('a', :class => "intialise_input").click
# 		# 	stake = 2000
# 		# 	fill_in 'stake', with: stake
# 		# 	expect(stake).to be <= user.balance
# 		# 	expect(stake).to be > 0
# 		# 	expect('total-wins'.to_f).to eq('total-odds'.to_f * 'stake-input'.to_i)
# 		# 	click_button('Place Bet')
# 		# 	expect(page).to have_content 'Thank You! Bets have been placed.'
# 		# 	new_balance = user.balance-stake
# 		# 	user.update(balance:new_balance)
# 		# 	expect(user.balance).to eq(new_balance)
# 		# 	expect(page.current_path).to eq '/fixtures/soccer/lives'

# 		# 	expect(BetSlip.count).to eq(slip_count+1)
# 		# 	 puts BetSlip.count

# 		# end



# 		##place bet test with low balance
# 		 it 'should fail on low balance' do
# 			login_form(user.phone_number, user.password)
# 		 	expect(page).to have_content('Upcoming Fixtures - Soccer')
# 		 	expect(page).to have_content('Betslip')
# 		 	first('a', :class => "intialise_input").click
# 		 	stake = 20000
# 		 	fill_in 'stake', with: stake
# 		 	expect('total-wins'.to_f).to eq('total-odds'.to_f * 'stake-input'.to_i)
# 		 	click_button('Place Bet')
# 		 	expect(page).to have_content'You have insufficient balance on your account. Please deposit some money.'
# 		 end

# 		##place bet test on user not logged in scenario
# 		 it 'User can login after choosing games' do
# 		 	visit '/'
# 		 	expect(page).to have_content('Upcoming Fixtures - Soccer')
# 		 	expect(page).to have_content('Betslip')
# 		 	first('a', :class => "intialise_input").click
# 		 	stake = 2000
# 		 	fill_in 'stake', with: stake
# 		 	expect('total-wins'.to_f).to eq('total-odds'.to_f * 'stake-input'.to_i)
# 		 	sleep(1)
# 		 	expect(page).to_not have_content 'Place bet'
# 		 	click_link('slip_login')
# 		 	login_form(user.phone_number, user.password)
# 			sleep (1)
# 		 end

# 	end
# end
