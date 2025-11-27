class Api::V1::PreMatchController < Api::V1::BaseController
  def index
    # find all fixtures that are not started yet
    # show league, tournament, home and away teams, scores, match time, odds for main markets
  end

  def show
    # show details for a specific pre-match and all markets/odds
  end
end
