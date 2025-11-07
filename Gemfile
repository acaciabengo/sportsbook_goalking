source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.4"

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem "rails", "~> 7.0" #, '>= 6.0.2.2'
# Use sqlite3 as the database for Active Record
#gem 'sqlite3'
# Use the postgres database with ActiveRecord
gem "pg"
# Use Puma as the app server
# gem 'puma', '~> 3.11'
gem "puma", "~> 6.4", ">= 6.4.2"
# Use SCSS for stylesheets
gem "sass-rails", "~> 5.0"
# Use Uglifier as compressor for JavaScript assets
gem "uglifier", ">= 1.3.0"
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'mini_racer', platforms: :ruby

# Use CoffeeScript for .coffee assets and views
gem "coffee-rails", "~> 5.0.0"
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem "turbolinks", "~> 5"
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem "jbuilder", "~> 2.5"
# Use Redis adapter to run Action Cable in production
gem "redis", "~> 4.0"
# Use ActiveModel has_secure_password
gem "bcrypt", "~> 3.1.7"

# Use ActiveStorage variant
# gem 'mini_magick', '~> 4.8'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", ">= 1.1.0", require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem "byebug", platforms: %i[mri mingw x64_mingw]
  gem "action-cable-testing"
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem "web-console", ">= 3.3.0"
  gem "listen" #, '>= 3.0.5', '< 3.2'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem "spring"
  gem "spring-watcher-listen", "~> 2.0.0"
  gem "capistrano", "~> 3.10", require: false
  gem "capistrano-rails", "~> 1.3", require: false
  gem "capistrano-ext"
  gem "capistrano-passenger"
  gem "capistrano-rvm"
  gem "capistrano-bundler"
  gem "capistrano-rbenv", "~> 2.1"
end

group :test do
  gem "rspec-rails"

  # Adds support for Capybara system testing and selenium driver
  gem "capybara", ">= 2.15"
  gem "selenium-webdriver"

  # Easy installation and use of chromedriver to run system tests with Chrome
  # gem 'chromedriver-helper'
  gem "webdrivers"
  gem "factory_bot"
  gem "faker"
  gem "shoulda-matchers"
  gem "rspec-sidekiq"
  gem "database_cleaner-active_record"
  gem "factory_bot_rails"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

gem "dotenv-rails"
gem "activeadmin" #, '~> 2.7'
gem "inherited_resources",
    git: "https://github.com/activeadmin/inherited_resources"
gem "devise"
gem "draper"
gem "pundit"
gem "sidekiq"
gem "cancancan"
gem "ransack" #, '~> 2.3', '>= 2.3.2'
gem "gon"
gem "kaminari"
gem "jwt"
gem "openssl"
gem "audited", "~> 5.0"
gem "roo", "~> 2.8.0"
gem "brakeman"
# gem 'sentry-raven'
gem "webpacker" #, '~> 4.0'
gem "bunny", ">= 2.16.1"
gem "sneakers"
# gem 'httparty', '~> 0.13.7'
# gem 'rb-readline'
#gem 'active_model_serializers', '~> 0.10.0'
gem "jquery-rails"
gem "jquery-ui-rails"
gem "momentjs-rails", ">= 2.9.0"
gem "pagy", "~> 3.5"
gem "flag-icons-rails"
gem "browser"
gem "pg_search"
gem "newrelic_rpm"
gem "local_time"
gem "anycable"
gem "anycable-rails", "~> 1.0"
gem "webmock", "~> 2.1"
gem "mimemagic",
    github: "mimemagicrb/mimemagic",
    ref: "01f92d86d15d85cfd0f20dabd025dcbd36a8a60f"
gem "will_paginate"
gem "prettier"
gem "fabrication", "~> 2.15", ">= 2.15.2"
gem "pry", "~> 0.15.0"
gem "font-awesome-rails"
gem "importmap-rails"
gem "stringio", "3.1.7"

gem "tailwindcss-ruby", "~> 4.1"

gem "tailwindcss-rails", "~> 4.3"
gem "faraday", "~> 2.14"
