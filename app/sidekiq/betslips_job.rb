class BetslipsJob
   include Sidekiq::Job
   sidekiq_options queue: "high"
   sidekiq_options retry: false
   
   def perform()
      BetSlip.where(status: "Active").find_in_batches(batch_size: 100) do |batch|
         batch.each do |slip|
            if slip.bets.pluck(:status).all? {|status| status == "Closed"}
               #check all the bets
               bet_results = slip.bets.pluck(:result)
               #check if slip includes voids
               
               if bet_results.include?("Loss")
                  #if it includes any loss
                  #mark as a loss and close the betslip
                  slip.update(status: "Closed", result: "Loss")
                  
               elsif bet_results.all? {|res| res == "Win"}
                  #if all wins, mark as win and payup
                  user = User.find_by(id: slip.user_id)
                  #mark as a win and payout winning and top up balance all under a transaction
                  total_odds = slip.bets.pluck(:odds)&.map(&:to_f)&.inject(:*)&.round(2)
                  win_amount = (slip.stake * total_odds)
                  slip_bonus = SlipBonus.where('min_accumulator <= ? AND max_accumulator >= ?', slip.bet_count, slip.bet_count)

                  if slip_bonus.exists? && slip_bonus.last.status == "Active"
                     case slip.bet_count
                        when (slip_bonus.last.min_accumulator)..(slip_bonus.last.max_accumulator)
                           bonus_win = (slip_bonus.last.multiplier / 100) * win_amount
                        else
                           bonus_win = 0
                     end
                  else
                     bonus_win = 0
                  end

                  payout = (bonus_win.to_f + win_amount)

                  net_payout = payout - (payout * BetSlip::TAX_RATE)

                  ActiveRecord::Base.transaction do
                     slip.update(status: "Closed" ,result: "Win", payout: payout, paid: true)
                     #update the account balances through transactions under an active record transaction
                     previous_balance = user.balance
                     user.balance = (user.balance + net_payout)
                     user.save!
                     transaction = user.transactions.create!(balance_before: previous_balance, balance_after: user.balance, phone_number: user.phone_number, status: "SUCCESS", currency: "UGX", amount: net_payout, category: "Win - #{slip.id}" )
                  end
                  
               elsif bet_results.all? {|res| res == "Void"}
                  #if all voids, refund the money
                  user = User.find(slip.user_id)
                  #mark as a win and payout winning and top up balance all under a transaction
                  total_odds = 1.0
                  win_amount = (slip.stake * total_odds )
                  ActiveRecord::Base.transaction do
                     slip.update(status: "Closed" ,result: "Void", payout: win_amount, paid: true)
                     #update the account balances through transactions under an active record transaction
                     previous_balance = user.balance
                     user.balance = (user.balance + win_amount)
                     user.save!
                     transaction = user.transactions.create!(balance_before: previous_balance, balance_after: user.balance, phone_number: user.phone_number, status: "SUCCESS", currency: "UGX", amount: win_amount, category: "Win - #{slip.id}" )
                  end
                  
               else
                  #consider only the wins and ignore the voids and market the ticket
                  user = User.find(slip.user_id)
                  no_void_bet_results = slip.bets.where(result: "Win")
                  if no_void_bet_results.present?
                     total_odds = no_void_bet_results.pluck(:odds).map(&:to_f).inject(:*).round(2)
                     win_amount = (slip.stake * total_odds )

                     slip_bonus = SlipBonus.where('min_accumulator <= ? AND max_accumulator >= ?', slip.bet_count, slip.bet_count)

                     if slip_bonus.exists? && slip_bonus.last.status == "Active"
                        case slip.bet_count
                           when (slip_bonus.last.min_accumulator)..(slip_bonus.last.max_accumulator)
                              bonus_win = (slip_bonus.last.multiplier / 100) * win_amount
                           else
                              bonus_win = 0
                        end
                     else
                        bonus_win = 0
                     end

                     payout = (bonus_win.to_f + win_amount)
                     ActiveRecord::Base.transaction do
                        slip.update(status: "Closed" ,result: "Win", payout: payout, paid: true)
                        #update the account balances through transactions under an active record transaction
                        previous_balance = user.balance
                        user.balance = (user.balance + payout)
                        user.save!
                        transaction = user.transactions.create!(balance_before: previous_balance, balance_after: user.balance, phone_number: user.phone_number, status: "SUCCESS", currency: "UGX", amount: payout, category: "Win - #{slip.id}" )
                     end
                  end
                  
               end
            end
         end
      end
      
   end
end