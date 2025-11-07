class Backend::AdminLandingController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"

  def index
    ##Dates
    dates = []

    ##Values for bet values
    stake = []
    amount_won = []

    ##values for bet counts
    bets = []

    ((Date.today - 21)..Date.today).each do |date|
      ##Push dates to the dates Array
      dates.push(date.to_s)

      ##Get stake totals per day
      stake_totals =
        BetSlip.where(
          "created_at >= ? and created_at <= ?",
          date.beginning_of_day,
          date.end_of_day
        ).sum(:stake)

      ##Get amounts won totals per day
      amount_won_totals =
        BetSlip.where(
          "created_at >= ? and created_at <= ?",
          date.beginning_of_day,
          date.end_of_day
        ).sum(:payout)

      ##Get total bets placed per day
      bets_totals =
        BetSlip.where(
          "created_at >= ? and created_at <= ?",
          date.beginning_of_day,
          date.end_of_day
        ).count

      ##Push all values in the respective arrays
      stake.push(stake_totals)
      amount_won.push(amount_won_totals)
      bets.push(bets_totals)
    end

    gon.stake = stake
    gon.amount_won = amount_won
    gon.bets = bets
    gon.dates = dates
  end
end
