// Import jQuery FIRST and make it globally available
import jquery from "jquery"
window.jQuery = jquery
window.$ = jquery

// Import and setup Bootstrap (needs jQuery to be available first)
import * as bootstrap from "bootstrap"
window.bootstrap = bootstrap

// Import Turbo Rails
import "@hotwired/turbo-rails"

// Import Popper (Bootstrap dependency)
import "@popperjs/core"

// Import Chartkick and Chart.js
import "chartkick"
import "Chart.bundle"

// Import app.init (doesn't use jQuery at import time)
import appInit from "./angle/app.init.js"


// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  // Check if jQuery is loaded
  if (typeof $ === 'undefined') {
    console.error('jQuery is not loaded!');
    return;
  }
  
  console.log('jQuery version:', $.fn.jquery);

  // Initialize app
  console.log('Calling appInit...');
  appInit();
  
  // Now import modules that use jQuery at import time, then initialize
  Promise.all([
    import("./time_picker.js"),
    import("./analytics.js"),
    import("./bets_analytics.js")
  ]).then(() => {
    console.log('All jQuery-dependent modules loaded');
    
    // Initialize date/time pickers AFTER time_picker.js is loaded
    initializeDateTimePickers();
    
    // Initialize booking handlers
    initializeBookingHandlers();
    
    // Initialize broadcast counter
    initializeBroadcastCounter();
  }).catch(err => {
    console.error('Failed to load modules:', err);
  });
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