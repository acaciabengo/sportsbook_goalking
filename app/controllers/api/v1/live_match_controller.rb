class Api::V1::LiveMatchController < Api::V1::BaseController

  def index
    # find all fixtures that are live
    # show league, tournament, home and away teams, scores, match time, odds for main markets
  end

  def show
    # show details for a specific live match and all markets/odds
  end
end
