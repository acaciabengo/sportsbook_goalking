// app/javascript/application.js
// Configure your import map in config/importmap.rb
// console.log('Application JavaScript loaded');

import "@hotwired/turbo-rails"

import "jquery"
import "@popperjs/core"
import "bootstrap"


import jquery from "jquery"
window.jQuery = jquery
window.$ = jquery

import "chartkick"
import "Chart.bundle"