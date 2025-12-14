require 'swagger_helper'

RSpec.describe 'Api::V1::Descriptions', type: :request do

  path '/api/v1/sports' do
    get('list sports') do
      tags 'Descriptions'
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, description: 'Page number', required: false

      response(200, 'successful') do
        schema type: :object,
          properties: {
            current_page: { type: :integer },
            total_pages: { type: :integer },
            total_count: { type: :integer },
            data: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  ext_sport_id: { type: :integer },
                  name: { type: :string }
                }
              }
            }
          }
        run_test!
      end
    end
  end

  path '/api/v1/categories' do
    get('list categories') do
      tags 'Descriptions'
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, description: 'Page number', required: false

      response(200, 'successful') do
        schema type: :object,
          properties: {
            current_page: { type: :integer },
            total_pages: { type: :integer },
            total_count: { type: :integer },
            data: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  ext_category_id: { type: :integer },
                  name: { type: :string },
                  sport_id: { type: :integer }
                }
              }
            }
          }
        run_test!
      end
    end
  end

  path '/api/v1/tournaments' do
    get('list tournaments') do
      tags 'Descriptions'
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, description: 'Page number', required: false

      response(200, 'successful') do
        schema type: :object,
          properties: {
            current_page: { type: :integer },
            total_pages: { type: :integer },
            total_count: { type: :integer },
            data: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  ext_tournament_id: { type: :integer },
                  name: { type: :string },
                  category_id: { type: :integer }
                }
              }
            }
          }
        run_test!
      end
    end
  end

  path '/api/v1/markets' do
    get('list markets') do
      tags 'Descriptions'
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, description: 'Page number', required: false

      response(200, 'successful') do
        schema type: :object,
          properties: {
            current_page: { type: :integer },
            total_pages: { type: :integer },
            total_count: { type: :integer },
            data: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  ext_market_id: { type: :integer },
                  name: { type: :string },
                  sport_id: { type: :integer }
                }
              }
            }
          }
        run_test!
      end
    end
  end
end
