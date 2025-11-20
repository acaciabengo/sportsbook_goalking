// console.log('Admin JavaScript loaded');
// import "@hotwired/turbo-rails"
// import "controllers"

// Import Rails helpers
import Rails from "@rails/ujs"
import * as ActiveStorage from "@rails/activestorage"

// Import Bootstrap
import * as bootstrap from "bootstrap"

// Make Bootstrap available globally
window.bootstrap = bootstrap

// Start Rails UJS and ActiveStorage
Rails.start()
ActiveStorage.start()

// console.log('Rails UJS started');

// Import admin modules
import "./time_picker.js"
import "./analytics.js"
import "./bets_analytics.js"
import appInit from "./angle/app.init.js"

// console.log('Modules imported');

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  // console.log('DOMContentLoaded fired');
  
  // Check if jQuery is loaded
  if (typeof $ === 'undefined') {
    console.error('jQuery is not loaded! Add jQuery CDN to your layout.');
    return;
  }
  
  // console.log('jQuery version:', $.fn.jquery);
  
  // Initialize app
  // console.log('Calling appInit...');
  appInit();
  
  // Initialize date/time pickers
  initializeDateTimePickers();
  
  // Initialize booking handlers
  initializeBookingHandlers();
  
  // Initialize broadcast counter
  initializeBroadcastCounter();
  
  // console.log('All initializations complete');
});

// Date/Time pickers
function initializeDateTimePickers() {
  // console.log('Initializing datetimepickers...');
  
  if (typeof $.fn.datetimepicker === 'undefined') {
    console.error('datetimepicker plugin not loaded!');
    return;
  }
  
  const dateFields = [
    '#kick_off_before',
    '#kick_off_after',
    '#bet_before',
    '#bet_after',
    '#broadcast_schedule'
  ];
  
  dateFields.forEach(selector => {
    const $field = $(selector);
    if ($field.length) {
      $field.datetimepicker({
        format: "YYYY-MM-DD hh:mm a"
      });
      // console.log('Initialized datetimepicker for', selector);
    }
  });
}

// Booking handlers
function initializeBookingHandlers() {
  // console.log('Initializing booking handlers...');
  
  $(document).on("ajax:complete", ".booking", function() {
    // console.log('Booking ajax completed');
    $(this).closest("tr").fadeOut();
    setTimeout(() => {
      $("#notice").html("");
    }, 2000);
  });
}

// Broadcast character counter
function initializeBroadcastCounter() {
  // console.log('Initializing broadcast counter...');
  
  const $textarea = $('#broadcast_compose_message');
  if (!$textarea.length) {
    // console.log('Broadcast textarea not found on this page');
    return;
  }
  
  const $remaining = $('#broadcast_char_count');
  const $messages = $remaining.next();
  const max = 1600;

  $textarea.on('keyup', function() {
    const chars = this.value.length;
    const messages = Math.ceil(chars / 160);
    const remaining = messages * 160 - (chars % (messages * 160) || messages * 160);
    
    if (chars >= max) {
      $('#broadcast_number_of_messages').text(' you have reached the limit');
    } else {
      $remaining.text(remaining + ' characters remaining');
      $messages.text(messages + ' message(s)');
    }
  });
  
  // console.log('Broadcast counter initialized');
}