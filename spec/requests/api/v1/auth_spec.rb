require 'rails_helper'
require 'swagger_helper'

RSpec.describe "Api::V1::Auth", type: :request do
  
  path '/api/v1/login' do
    post 'Logs in a user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          phone_number: { type: :string, example: '256700000000' },
          password: { type: :string, example: 'password123' }
        },
        required: [ 'phone_number', 'password' ]
      }

      response '200', 'successful login' do
        let(:password) { "password123" }
        let!(:user) { Fabricate(:user, phone_number: "256700000000", password: password, password_confirmation: password, first_name: "John", last_name: "Doe") }
        let(:credentials) { { phone_number: user.phone_number, password: password } }

        schema type: :object,
          properties: {
            token: { type: :string, example: 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.signature' },
            user: {
              type: :object,
              properties: {
                id: { type: :integer, example: 1 },
                phone_number: { type: :string, example: '256700000000' },
                first_name: { type: :string, example: 'John' },
                last_name: { type: :string, example: 'Doe' },
                balance: { type: :string, example: '10000.0' },
                created_at: { type: :string, format: 'date-time' }
              }
            }
          }
        
        run_test!
      end

      response '401', 'unauthorized' do
        let(:credentials) { { phone_number: 'invalid', password: 'invalid' } }
        run_test!
      end
    end
  end

  path '/api/v1/signup' do
    post 'Creates a new user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :user_params, in: :body, schema: {
        type: :object,
        properties: {
          phone_number: { type: :string, example: '256700000001' },
          password: { type: :string, example: 'password123' },
          password_confirmation: { type: :string, example: 'password123' },
          first_name: { type: :string, example: 'Jane' },
          last_name: { type: :string, example: 'Doe' }
        },
        required: [ 'phone_number', 'password', 'password_confirmation', 'first_name', 'last_name' ]
      }

      response '201', 'user created' do
        let(:user_params) { { phone_number: "256700000001", password: "password123", password_confirmation: "password123", first_name: "Jane", last_name: "Doe" } }
        
        schema type: :object,
          properties: {
            token: { type: :string, example: 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM1In0.signature' },
            user: {
              type: :object,
              properties: {
                id: { type: :integer, example: 2 },
                phone_number: { type: :string, example: '256700000001' },
                first_name: { type: :string, example: 'Jane' },
                last_name: { type: :string, example: 'Doe' },
                balance: { type: :string, example: '0.0' },
                created_at: { type: :string, format: 'date-time' }
              }
            }
          }

        run_test!
      end

      response '422', 'unprocessable entity' do
        let(:user_params) { { phone_number: "256700000001", password: "123", password_confirmation: "456" } }
        run_test!
      end
    end
  end

  describe "POST /api/v1/login" do
    let(:password) { "password123" }
    let!(:user) { Fabricate(:user, phone_number: "256700000000", password: password, password_confirmation: password, first_name: "John", last_name: "Doe") }

    context "with valid credentials" do
      it "returns http success" do
        post "/api/v1/login", params: { phone_number: user.phone_number, password: password }
        
        expect(response).to have_http_status(:ok)
      end

      it "returns a JWT token" do
        post "/api/v1/login", params: { phone_number: user.phone_number, password: password }
        json = JSON.parse(response.body)
        
        expect(json['token']).to be_present
        expect(json['token']).to be_a(String)
      end

      it "returns user data" do
        post "/api/v1/login", params: { phone_number: user.phone_number, password: password }
        json = JSON.parse(response.body)
        
        expect(json['user']).to be_present
        expect(json['user']['id']).to eq(user.id)
        expect(json['user']['phone_number']).to eq(user.phone_number)
        # expect(json['user']['balance']).to eq(user.balance)
        expect(json['user']['created_at']).to be_present
      end

      it "does not expose sensitive data" do
        post "/api/v1/login", params: { phone_number: user.phone_number, password: password }
        json = JSON.parse(response.body)
        
        expect(json['user']['password']).to be_nil
        expect(json['user']['encrypted_password']).to be_nil
        expect(json['user']['password_digest']).to be_nil
      end

      it "generates a valid JWT token with correct payload" do
        post "/api/v1/login", params: { phone_number: user.phone_number, password: password }
        json = JSON.parse(response.body)
        token = json['token']
        
        decoded_token = JWT.decode(token, ENV['DEVISE_JWT_SECRET_KEY'], true, algorithm: 'HS256').first
        
        expect(decoded_token['sub']).to eq(user.id)
        expect(decoded_token['exp']).to be > Time.now.to_i
        expect(decoded_token['iat']).to be <= Time.now.to_i
      end

      it "generates a token that expires in 24 hours" do
        post "/api/v1/login", params: { phone_number: user.phone_number, password: password }
        json = JSON.parse(response.body)
        token = json['token']
        
        decoded_token = JWT.decode(token, ENV['DEVISE_JWT_SECRET_KEY'], true, algorithm: 'HS256').first
        expiration_time = Time.at(decoded_token['exp'])
        
        expect(expiration_time).to be_within(1.minute).of(24.hours.from_now)
      end
    end

    context "with invalid credentials" do
      it "returns unauthorized with wrong password" do
        post "/api/v1/login", params: { phone_number: user.phone_number, password: "wrongpassword" }
        
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns error message with wrong password" do
        post "/api/v1/login", params: { phone_number: user.phone_number, password: "wrongpassword" }
        json = JSON.parse(response.body)
        
        expect(json['error']).to eq('Invalid credentials')
      end

      it "returns unauthorized with non-existent phone number" do
        post "/api/v1/login", params: { phone_number: "256999999999", password: password }
        
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns error message with non-existent phone number" do
        post "/api/v1/login", params: { phone_number: "256999999999", password: password }
        json = JSON.parse(response.body)
        
        expect(json['error']).to eq('Invalid credentials')
      end

      it "does not return token with invalid credentials" do
        post "/api/v1/login", params: { phone_number: user.phone_number, password: "wrongpassword" }
        json = JSON.parse(response.body)
        
        expect(json['token']).to be_nil
      end
    end

    context "with missing parameters" do
      it "returns unauthorized when phone_number is missing" do
        post "/api/v1/login", params: { password: password }
        
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized when password is missing" do
        post "/api/v1/login", params: { phone_number: user.phone_number }
        
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized when both parameters are missing" do
        post "/api/v1/login", params: {}
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/signup" do
    let(:valid_params) do
      {
        phone_number: "256700000001",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Jane",
        last_name: "Doe"
      }
    end

    context "with valid parameters" do
      it "returns http created" do
        post "/api/v1/signup", params: valid_params
        
        expect(response).to have_http_status(:created)
      end

      it "creates a new user" do
        expect {
          post "/api/v1/signup", params: valid_params
        }.to change(User, :count).by(1)
      end

      it "returns a JWT token" do
        post "/api/v1/signup", params: valid_params
        json = JSON.parse(response.body)
        
        expect(json['token']).to be_present
        expect(json['token']).to be_a(String)
      end

      it "returns user data" do
        post "/api/v1/signup", params: valid_params
        json = JSON.parse(response.body)
        
        expect(json['user']).to be_present
        expect(json['user']['phone_number']).to eq(valid_params[:phone_number])
        expect(json['user']['balance']).to be_present
        expect(json['user']['created_at']).to be_present
      end

      it "does not expose sensitive data" do
        post "/api/v1/signup", params: valid_params
        json = JSON.parse(response.body)
        
        expect(json['user']['password']).to be_nil
        expect(json['user']['encrypted_password']).to be_nil
      end

      it "generates a valid JWT token" do
        post "/api/v1/signup", params: valid_params
        json = JSON.parse(response.body)
        token = json['token']
        
        decoded_token = JWT.decode(token, ENV['DEVISE_JWT_SECRET_KEY'], true, algorithm: 'HS256').first
        user = User.find_by(phone_number: valid_params[:phone_number])
        
        expect(decoded_token['sub']).to eq(user.id)
        expect(decoded_token['exp']).to be > Time.now.to_i
      end
    end

    context "with invalid parameters" do
      it "returns unprocessable_entity when phone_number is missing" do
        post "/api/v1/signup", params: { password: "password123", password_confirmation: "password123" }
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns errors when phone_number is missing" do
        post "/api/v1/signup", params: { password: "password123", password_confirmation: "password123" }
        json = JSON.parse(response.body)
        
        expect(json['errors']).to be_present
        expect(json['errors']).to be_an(Array)
      end

      it "returns unprocessable_entity when password is missing" do
        post "/api/v1/signup", params: { phone_number: "256700000001", password_confirmation: "password123" }
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns unprocessable_entity when passwords don't match" do
        post "/api/v1/signup", params: {
          phone_number: "256700000001",
          password: "password123",
          password_confirmation: "different"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns errors when passwords don't match" do
        post "/api/v1/signup", params: {
          phone_number: "256700000001",
          password: "password123",
          password_confirmation: "different"
        }
        json = JSON.parse(response.body)
        
        expect(json['errors']).to include(match(/Password confirmation/))
      end

      it "returns unprocessable_entity when phone_number already exists" do
        existing_user = Fabricate(:user, phone_number: "256700000001")
        
        post "/api/v1/signup", params: {
          phone_number: existing_user.phone_number,
          password: "password123",
          password_confirmation: "password123"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns errors when phone_number already exists" do
        existing_user = Fabricate(:user, phone_number: "256700000001")
        
        post "/api/v1/signup", params: {
          phone_number: existing_user.phone_number,
          password: "password123",
          password_confirmation: "password123"
        }
        json = JSON.parse(response.body)
        
        expect(json['errors']).to include(match(/Phone number/))
      end

      it "does not create a user with invalid parameters" do
        expect {
          post "/api/v1/signup", params: {
            phone_number: "256700000001",
            password: "password123",
            password_confirmation: "different"
          }
        }.not_to change(User, :count)
      end

      it "does not return a token with invalid parameters" do
        post "/api/v1/signup", params: {
          phone_number: "256700000001",
          password: "password123",
          password_confirmation: "different"
        }
        json = JSON.parse(response.body)
        
        expect(json['token']).to be_nil
      end
    end

    context "with weak password" do
      it "returns unprocessable_entity when password is too short" do
        post "/api/v1/signup", params: {
          phone_number: "256700000001",
          password: "123",
          password_confirmation: "123"
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "Authentication requirement" do
    it "does not require authentication for login" do
      post "/api/v1/login", params: { phone_number: "256700000000", password: "password", first_name: "John", last_name: "Doe" }
      
      # Should not return 401 for missing auth, but 401 for invalid credentials
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json['error']).to eq('Invalid credentials')
    end

    it "does not require authentication for signup" do
      post "/api/v1/signup", params: {
        phone_number: "256700000001",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Jane",
        last_name: "Doe"
      }
      
      expect(response).to have_http_status(:created)
    end
  end
end