# require 'rails_helper'
# require 'sidekiq/testing'

# RSpec.describe User, type: :system, js: true do



# 	describe "withdraw" do
# 		#include_context 'Withdraw_Api_Generation'

# 		user = User.create({
# 					email: Faker::Internet.email,
# 					phone_number: '25677'+ rand(1000000..9999999).to_s,
# 					first_name: Faker::Name.first_name,
# 					last_name: Faker::Name.last_name,
# 					password: "Jtwitw@c2016",
# 					password_confirmation: "Jtwitw@c2016",
# 					balance: 10000,
# 					agreement: true
# 				})
# 		user.update(verified: true)

# 		reference = SecureRandom.uuid
# 		reference1 = SecureRandom.uuid
# 		reference2 = SecureRandom.uuid

# 		random_amount = 1000*rand(1..8)

# 		def login_form(phone_number, password)
# 			fill_in 'phone_number', with: phone_number
# 			fill_in 'password', with: password
# 			click_button 'Login'
# 		end


# 		it "should allow successful login and withdraw money from a user's account" do
# 			deposit = Deposit.create({
# 				amount: 10000,
# 				network: "MTN Uganda",
# 				payment_method: 'Mobile Money',
# 				balance_before: 0,
# 				balance_after: 10000,
# 				ext_transaction_id:reference,
# 				transaction_id:reference1,
# 				resource_id:reference2,
# 				status: 'SUCCESS',
# 				message:'',
# 				currency: 'UGX',
# 				phone_number:user.phone_number,
# 				user_id: user.id
# 			})

# 			withdraw_count = Withdraw.count
# 			transaction_count = Transaction.count


# 			visit '/'
# 			click_link('login')
# 			login_form(user.phone_number, user.password)
# 			expect(page.current_path).to eq('/')
# 			expect(page).to have_content 'DEPOSIT'
# 			expect(page).to have_content user.balance

# 			visit '/transfer'
# 			fill_in 'amount', with: random_amount


# 			expect{
# 			 	click_button 'Withdraw Money'
# 			  }.to change(WithdrawsWorker.jobs, :size).by(1)

# 			expect(page).to have_content "Please wait while we process your payment.."

# 			Sidekiq::Testing.inline! do
# 				WithdrawsWorker.drain
# 			end

# 			expect(Withdraw.last.status).to eq('SUCCESS')
# 			expect(Transaction.last.status).to eq('COMPLETED')

# 			expect(Withdraw.count).to eq(withdraw_count+1)
# 			expect(Transaction.count).to eq(transaction_count+1)


# 			#sleep(2)
# 		end


# 		it 'should fail on low account balance' do

# 			deposit = Deposit.create({
# 					amount: 1000,
# 					network: "MTN Uganda",
# 					payment_method: 'Mobile Money',
# 					balance_before: 0,
# 					balance_after: 10000,
# 					ext_transaction_id:reference,
# 					transaction_id:reference1,
# 					resource_id:reference2,
# 					status: 'FAILED',
# 					message:'',
# 					currency: 'UGX',
# 					phone_number:user.phone_number,
# 					user_id: user.id
# 				})

# 			visit '/'
# 			click_link('login')
# 			login_form(user.phone_number, user.password)
# 			expect(page.current_path).to eq('/')
# 			expect(page).to have_content 'DEPOSIT'
# 			expect(page).to have_content user.balance
# 			visit '/transfer'
# 			fill_in 'amount', with: 20000
# 			expect{
# 			 	click_button 'Withdraw Money'
# 			 }.to change(WithdrawsWorker.jobs, :size).by(0)
# 			expect(page).to have_content "You have insufficient funds on your account."
# 		 end


# 		it "should fail on zero deposits." do
# 			visit '/'
# 			click_link('login')
# 			login_form(user.phone_number, user.password)
# 			expect(page.current_path).to eq('/')
# 			expect(page).to have_content 'DEPOSIT'
# 			expect(page).to have_content user.balance
# 			visit '/transfer'
# 			fill_in 'amount', with: random_amount
# 			click_button 'Withdraw Money'
# 			expect(page).to have_content "You need to make a Deposit or place a bet before any withdraw."

# 			#sleep(2)
# 		end


# 	end
# end
