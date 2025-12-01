Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  devise_for :admin_users, ActiveAdmin::Devise.config
  root to: "backend/admin_landing#index"
  
  ##React routes
  match "cart_fixtures" => "line_bets#cart_fixtures", :via => [:get]
  match "check_bonus" => "line_bets#check_bonus", :via => [:get]
  namespace :api do
    namespace :v1 do
      match "/transactions" => "transactions#index", :via => [:get]
      match '/transactions/deposit' => 'transactions#deposit', :via => [:post]
      match '/transactions/withdraw' => 'transactions#withdraw', :via => [:post]
      match "/betslips" => "betslips#index", :via => [:get]
      match "/betslips" => "betslips#create", :via => [:post]
      match "/betslips/:id" => "betslips#show", :via => [:get]
      match "/pre_match" => "pre_match#index", :via => [:get]
      match "/pre_match/:id" => "pre_match#show", :via => [:get]
      match "/live_match" => "live_match#index", :via => [:get]
      match "/live_match/:id" => "live_match#show", :via => [:get]
      match "login" => "auth#login", :via => [:post, :get]
      match "signup" => "auth#signup", :via => [:post]

      match "check_user" => "current_user#check_current_user", :via => [:get]
      match "verification" => "current_user#user_verification", :via => [:get]
      match "home" => "home#index", :via => [:get]
      match "home_basket_ball" => "home#basket_ball", :via => [:get]
      match "home_tennis" => "home#tennis", :via => [:get]
      match "transactions" => "transactions#index", :via => [:get]
      match "bets" => "bets#index", :via => [:get]
      match "deposit" => "deposits#create", :via => [:post]
      match "withdraw" => "withdraws#create", :via => [:post]
      namespace :fixtures do
        namespace :soccer do
          match "live" => "live_match#index", :via => [:get]
          match "pre" => "pre_match#index", :via => [:get]
          match "pre_fixture" => "pre_match#show", :via => [:get]
          match "live_fixture" => "live_match#show", :via => [:get]
        end
        namespace :virtual_soccer do
          match "virtual_live" => "live_match#index", :via => [:get]
          match "virtual_pre" => "pre_match#index", :via => [:get]
          match "pre_fixture" => "pre_match#show", :via => [:get]
          match "live_fixture" => "live_match#show", :via => [:get]
        end

        match "search" => "search#index", :via => [:get]

        namespace :basketball do
          match "pre" => "pre_match#index", :via => [:get]
          match "pre_fixture" => "pre_match#show", :via => [:get]
          match "live" => "live_match#index", :via => [:get]
          match "live_fixture" => "live_match#show", :via => [:get]
        end

        namespace :tennis do
          match "pre" => "pre_match#index", :via => [:get]
          match "pre_fixture" => "pre_match#show", :via => [:get]
          match "live" => "live_match#index", :via => [:get]
          match "live_fixture" => "live_match#show", :via => [:get]
        end
      end
    end
  end

  match "sign_up_bonuses" => "auto_jobs#check_signup_bonuses", :via => [:post]
  match "deposit_bonuses" => "auto_jobs#check_first_deposit_bonuses",
        :via => [:post]
  match "/about", to: "footer_tabs#faqs", via: [:get]
  match "/rules", to: "footer_tabs#rules", via: [:get]
  match "/contacts", to: "footer_tabs#contacts", via: [:get]
  match "/terms", to: "footer_tabs#terms", via: [:get]
  match "/responsible_gambling", to: "footer_tabs#privacy", via: [:get]
  # Serve websocket cable requests in-process
  mount ActionCable.server => "/cable"

  namespace :confirmation do
    match "airtel/payment" => "airtel_uganda#create", :via => %i[post get]
    match "mtn/payment" => "mtn_uganda#create", :via => %i[post get]
  end

  resources :bet_slips, only: %i[index create show]
  match "/refresh_slip", to: "line_bets#refresh", via: [:post]
  match "/page_refresh",
        to: "fixtures/soccer/pre_match#page_refresh",
        via: [:get]
  match "/virtual_page_refresh",
        to: "fixtures/virtual_soccer/pre_match#page_refresh",
        via: [:get]
  match "/home_page_refresh", to: "home#page_refresh", via: [:get]
  match "/add_bet", to: "line_bets#create", via: [:post]
  match "/clear_slip", to: "line_bets#destroy", via: [:delete]
  match "/clear_bet", to: "line_bets#line_bet_delete", via: [:delete]
  match "/button_display",
        to: "line_bets#close_betslip_button_display",
        via: [:get]

  match "password_reset" => "password_reset#new", :via => [:get]
  match "reset" => "password_reset#create", :via => [:post]
  match "verify_reset" => "password_reset#edit", :via => [:get]
  match "password_update" => "password_reset#update", :via => [:post]

  namespace :fixtures do
    match "search" => "search#index", :via => [:get]
    namespace :soccer do
      match "pres" => "pre_match#index", :via => [:get]
      match "pre" => "pre_match#show", :via => [:get]
      match "lives" => "live_match#index", :via => [:get]
      match "live" => "live_match#show", :via => [:get]
      match "featured" => "pre_match#featured", :via => [:get]
    end
    namespace :virtual_soccer do
      match "pres" => "pre_match#index", :via => [:get]
      match "pre" => "pre_match#show", :via => [:get]
      match "lives" => "live_match#index", :via => [:get]
      match "live" => "live_match#show", :via => [:get]
    end
    namespace :basketball do
      match "pres" => "pre_match#index", :via => [:get]
      match "pre" => "pre_match#show", :via => [:get]
      match "lives" => "live_match#index", :via => [:get]
      match "live" => "live_match#show", :via => [:get]
    end
    namespace :tennis do
      match "pres" => "pre_match#index", :via => [:get]
      match "pre" => "pre_match#show", :via => [:get]
      match "lives" => "live_match#index", :via => [:get]
      match "live" => "live_match#show", :via => [:get]
    end
  end

  resources :transactions, only: [:index]
  match "deposit" => "transactions#deposit", :via => [:get]
  match "perform_deposit" => "transactions#perform_deposit", :via => [:post]
  match "withdraw" => "transactions#withdraw", :via => [:get]
  match "perform_withdraw" => "transactions#perform_withdraw", :via => [:post]
  match "resend_verify" => "verify#create", :via => [:post]
  match "new_verify" => "verify#new", :via => [:get]
  match "send_verification" => "verify#verify_via_email", :via => [:get]
  match "verify" => "verify#update", :via => [:post]

  namespace :backend do
    namespace :fixtures do
      match "soccer_fixtures" => "soccer_fixtures#index", :via => [:get]
      match "soccer_fixtures" => "soccer_fixtures#update", :via => [:put]
      match "fixture_recovery" => "recover_messages#index", :via => [:get]
      match "fixture_recovery" => "recover_messages#update", :via => [:put]
      match "soccer_fixtures_feature" => "soccer_fixtures#feature_update",
            :via => [:put]
      match "virtual_soccer_fixtures" => "virtual_soccer_fixtures#index",
            :via => [:get]
      patch "virtual_soccer_fixtures" => "virtual_soccer_fixtures#update",
            :via => [:update]
      match "basketball_fixtures" => "basketball_fixtures#index", :via => [:get]
      match "basketball_fixtures" => "basketball_fixtures#update",
            :via => [:put]
      match "basketball_fixtures_feature" =>
              "basketball_fixtures#feature_update",
            :via => [:put]
      match "tennis_fixtures" => "tennis_fixtures#index", :via => [:get]
      match "tennis_fixtures" => "tennis_fixtures#update", :via => [:put]
      match "tennis_fixtures_feature" => "tennis_fixtures#feature_update",
            :via => [:put]
    end
    resources :deposits, only: [:index]
    resources :withdraws, only: [:index]
    get "/api_user_keys/:id", to: "api_users#generate_api_keys", as: "user_keys"
    resources :api_users, only: %i[new index create]
    resources :sign_up_bonuses, only: %i[new index create]
    resources :topup_bonuses, only: %i[new index create]
    resources :slip_bonuses, only: %i[new index create]
    match "users" => "bet_users#index", :via => [:get]
    match "users" => "bet_users#create", :via => [:post]
    match "user" => "bet_users#show", :via => [:get]
    match "users/new" => "bet_users#new", :via => [:get]
    match "users" => "bet_users#create", :via => [:post]
    match "betstop_reasons" => "betstop_reasons#index", :via => [:get]
    match "betting_statuses" => "betting_statuses#index", :via => [:get]
    match "void_reasons" => "void_reasons#index", :via => [:get]
    match "match_statuses" => "match_statuses#index", :via => [:get]
    match "transactions_analytics" => "transactions_analytics#index",
          :via => [:get]
    match "suspend" => "bet_users#deactivate_account", :via => [:post]
    match "activate" => "bet_users#activate_account", :via => [:post]
    match "bet_slips" => "bet_slips#index", :via => [:get]
    # match 'bet_slips/cancel' => "bet_slips#cancel", via: [:post]
    match "bet_slip" => "bet_slips#show", :via => [:get]
    match "bets" => "bets#index", :via => [:get]
    resources :broadcasts
  end

  devise_for :users,
             path: "users",
             controllers: {
               sessions: "users/sessions",
               registrations: "users/registrations",
               passwords: "users/passwords"
             }

  devise_for :admins,
             skip: [:registrations],
             path: "admins",
             controllers: {
               sessions: "admins/sessions"
             }
  get "/404.html" => "users/registrations#edit"
  #get 'users/sessions/edit' => redirect('/404.html')
  get "admins/sign_up" => redirect("/404.html")
  devise_scope :admin do
    authenticated :admin do
      get "/backend" => "backend/admin_landing#index",
          :as => :authenticated_admins_root
    end
    unauthenticated :admin do
      get "/backend",
          to: "admins/sessions#new",
          as: :unauthenticated_admins_root
    end
  end
 
  #   devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  
  require "sidekiq/web"
  mount Sidekiq::Web => "/rabbit"

  get "*path" => redirect("/")
end
