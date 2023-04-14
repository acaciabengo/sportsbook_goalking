# require 'rails_helper'
# require 'sidekiq/testing'

# RSpec.describe "Api::V1::Deposits", type: :request do
#    describe "POST /create" do
#       user = User.create(
#          {
#             email: Faker::Internet.email,
#             phone_number: '25677'+ rand(1000000..9999999).to_s,
#             first_name: Faker::Name.first_name,
#             last_name: Faker::Name.last_name,
#             password: "Jtwitw@c2016",
#             password_confirmation: "Jtwitw@c2016",
#             agreement: true
#          }
#       )
#       user.update(verified: true)

#       user_test = User.create(
#          {
#             email: Faker::Internet.email,
#             phone_number: '25677'+ rand(1000000..9999999).to_s,
#             first_name: Faker::Name.first_name,
#             last_name: Faker::Name.last_name,
#             password: "Jtwitw@c2016",
#             password_confirmation: "Jtwitw@c2016",
#             agreement: true
#          }
#       )
#       user_test.update(verified: true)


#       it "returns http success " do
#          post "/api/v1/deposits/create", params: {amount: 1000}
#          expect(response).to have_http_status(:success)
#       end

#       it "returns error 400 if phone number is incorrect " do
#          post "/api/v1/deposits/create", params: {amount: 1000}
#          expect(response).to have_http_status(:success)
#       end

#       it "returns error 400 if amount is blank " do
#          post "/api/v1/deposits/create", params: {amount: 1000}
#          expect(response).to have_http_status(:success)
#       end
#    end

# end
