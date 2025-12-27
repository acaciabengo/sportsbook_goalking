require 'rails_helper'
require 'swagger_helper'

RSpec.describe "Api::V1::Users", type: :request do
  let(:user) { Fabricate(:user, balance: 50000.0) }
  let(:auth_headers) do
    token = JWT.encode(
      { sub: user.id, exp: 24.hours.from_now.to_i, iat: Time.now.to_i },
      ENV['DEVISE_JWT_SECRET_KEY'],
      'HS256'
    )
    { 'Authorization' => "Bearer #{token}" }
  end

  path '/api/v1/users/{id}' do
    parameter name: :id, in: :path, type: :string

    get('show user') do
      tags 'Users'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :Authorization, in: :header, type: :string

      response(200, 'successful') do
        let(:id) { user.id }
        let(:Authorization) { auth_headers['Authorization'] }

        schema type: :object,
          properties: {
            user: {
              type: :object,
              properties: {
                id: { type: :integer },
                first_name: { type: :string },
                last_name: { type: :string },
                phone_number: { type: :string },
                balance: { type: :number },
                created_at: { type: :string, format: :date_time }
              }
            }
          }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['user']['id']).to eq(user.id)
        end
      end

      response(401, 'unauthorized') do
        let(:id) { user.id }
        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end
    end

    put('update user') do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :Authorization, in: :header, type: :string
      
      parameter name: :user_params, in: :body, schema: {
        type: :object,
        properties: {
          first_name: { type: :string },
          last_name: { type: :string },
          password: { type: :string },
          password_confirmation: { type: :string }
        }
      }

      response(200, 'successful') do
        let(:id) { user.id }
        let(:Authorization) { auth_headers['Authorization'] }
        let(:user_params) { { first_name: 'NewName', last_name: 'NewLast' } }

        run_test! do |response|
          expect(user.reload.first_name).to eq('NewName')
        end
      end

      response(422, 'unprocessable entity') do
        let(:id) { user.id }
        let(:Authorization) { auth_headers['Authorization'] }
        let(:user_params) { { password: '123', password_confirmation: '456' } }

        run_test!
      end

      response(401, 'unauthorized') do
        let(:id) { user.id }
        let(:Authorization) { 'Bearer invalid_token' }
        let(:user_params) { {} }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/bonuses' do
    parameter name: :id, in: :path, type: :string

    get('list user bonuses') do
      tags 'Users'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :Authorization, in: :header, type: :string

      response(200, 'successful') do
        let(:id) { user.id }
        let(:Authorization) { auth_headers['Authorization'] }
        
        before do
          Fabricate(:user_bonus, user: user, amount: 10000, expires_at: 1.day.from_now)
          Fabricate(:user_bonus, user: user, amount: 5000, expires_at: 2.days.from_now)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          puts "user bonus data: #{data}"
          expect(data['user_bonuses'].length).to eq(2)
        end
      end

      response(401, 'unauthorized') do
        let(:id) { user.id }
        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/redeem' do
    parameter name: :id, in: :path, type: :string

    post('redeem points for bonus') do
      tags 'Users'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :Authorization, in: :header, type: :string

      response(200, 'successful') do
        let(:id) { user.id }
        let(:Authorization) { auth_headers['Authorization'] }
        
        before do
          user.update(points: 120)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to eq('Success')
          expect(user.reload.points).to eq(0)
          expect(user.user_bonuses.count).to eq(1)
          expect(user.user_bonuses.last.amount).to eq(10000)
        end
      end

      response(422, 'insufficient points') do
        let(:id) { user.id }
        let(:Authorization) { auth_headers['Authorization'] }
        
        before do
          user.update(points: 50)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Insufficient points to redeem')
        end
      end

      response(401, 'unauthorized') do
        let(:id) { user.id }
        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end
    end
  end
end

