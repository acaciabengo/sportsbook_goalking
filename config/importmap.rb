# Pin npm packages by running ./bin/importmap

# MUST have "application" pinned
pin "application", preload: true
pin "user_assets/application", to: "user_assets/application.js", preload: true
pin "admin_assets/application", to: "admin_assets/application.js", preload: true

# Hotwire - Turbo only
pin "@hotwired/turbo-rails", to: "https://cdn.jsdelivr.net/npm/@hotwired/turbo-rails@8.0.4/+esm", preload: true

# Pin all admin_assets
pin_all_from "app/javascript/admin_assets", under: "admin_assets"

# Rails UJS
pin "@rails/ujs", to: "https://cdn.jsdelivr.net/npm/@rails/ujs@7.1.3/+esm"

# ActiveStorage
pin "@rails/activestorage", to: "https://cdn.jsdelivr.net/npm/@rails/activestorage@7.1.3/+esm"

# Bootstrap needs Popper
pin "@popperjs/core", to: "https://cdn.jsdelivr.net/npm/@popperjs/core@2.11.8/dist/umd/popper.min.js", preload: true
pin "bootstrap", to: "https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js", preload: true

# Bootstrap needs Popper
pin "@popperjs/core", to: "https://cdn.jsdelivr.net/npm/@popperjs/core@2.11.8/dist/umd/popper.min.js", preload: true
pin "bootstrap", to: "https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js", preload: true

pin "echarts", to: "echarts/dist/echarts.js"
pin "screenfull", to: "screenfull/dist/screenfull.js"

pin "jquery", to: "https://cdn.jsdelivr.net/npm/jquery@3.7.1/dist/jquery.min.js", preload: true
