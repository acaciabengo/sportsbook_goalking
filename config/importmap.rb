# config/importmap.rb
# Pin npm packages by running ./bin/importmap

# jQuery - MUST load first
pin "jquery", to: "https://ga.jspm.io/npm:jquery@3.7.1/dist/jquery.js", preload: true

# # Bootstrap needs Popper (use ESM version for importmaps)
pin "@popperjs/core", to: "https://cdn.jsdelivr.net/npm/@popperjs/core@2.11.8/dist/esm/index.js", preload: true
pin "bootstrap", to: "https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.esm.min.js", preload: true

# MUST have "application" pinned
pin "application", preload: true
pin "user_assets/application", to: "user_assets/application.js", preload: true
pin "admin_assets/application", to: "admin_assets/application.js", preload: true

# Pin all admin_assets modules (angle, modules, etc.)
pin_all_from "app/javascript/admin_assets", under: "admin_assets"

pin "controllers", to: "controllers/index.js"

# Hotwire - Turbo only
pin "@hotwired/turbo-rails", to: "https://cdn.jsdelivr.net/npm/@hotwired/turbo-rails@8.0.4/+esm", preload: true

# Rails UJS
pin "@rails/ujs", to: "https://cdn.jsdelivr.net/npm/@rails/ujs@7.1.3/+esm"

# ActiveStorage
pin "@rails/activestorage", to: "https://cdn.jsdelivr.net/npm/@rails/activestorage@7.1.3/+esm"

# Other libraries
pin "echarts", to: "echarts/dist/echarts.js"
pin "screenfull", to: "screenfull/index.js"

pin "chartkick", to: "chartkick.js"
pin "Chart.bundle", to: "Chart.bundle.js"