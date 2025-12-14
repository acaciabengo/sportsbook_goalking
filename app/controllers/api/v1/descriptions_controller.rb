class Api::V1::DescriptionsController < Api::V1::BaseController

  skip_before_action :verify_authenticity_token

  def sports
    @pagy, @records = pagy(:offset, Sport.all, limit: 100)
    render json: {
      current_page: @pagy.page,
      total_pages: @pagy.pages,
      total_count: @pagy.count,
      data: @records.as_json(only: [:id, :ext_sport_id, :name])
    }, status: :ok
  end

  def categories
    @pagy, @records = pagy(:offset, Category.all, limit: 100)
    render json: {
      current_page: @pagy.page,
      total_pages: @pagy.pages,
      total_count: @pagy.count,
      data: @records.as_json(only: [:id, :ext_category_id, :name, :sport_id])
    }, status: :ok
  end

  def tournaments
    @pagy, @records = pagy(:offset, Tournament.all, limit: 100)
    render json: {
      current_page: @pagy.page,
      total_pages: @pagy.pages,
      total_count: @pagy.count,
      data: @records.as_json(only: [:id, :ext_tournament_id, :name, :category_id])
    }, status: :ok

  end

  def markets
    @pagy, @records = pagy(:offset, Market.all, limit: 100)
    render json: {
      current_page: @pagy.page,
      total_pages: @pagy.pages,
      total_count: @pagy.count,
      data: @records.as_json(only: [:id, :ext_market_id, :name, :sport_id])
    }, status: :ok
  end
end
