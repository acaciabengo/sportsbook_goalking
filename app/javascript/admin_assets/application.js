// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
import "core-js/stable";
import "regenerator-runtime/runtime";

// require("modernizr/modernizr.custom.js");

require("@rails/ujs").start();
// //require("turbolinks").start()
require("@rails/activestorage").start();
// require("channels")

//-- Date Timepicker
import "./time_picker.js";

//-- Graphs
import "./analytics.js.erb";
import "./bets_analytics.js.erb";

//--- Bootstrap
import "bootstrap";

import appInit from "./angle/app.init.js";
document.addEventListener("DOMContentLoaded", appInit);

// Uncomment to copy all static images under ../images to the output folder and reference
// them with the image_pack_tag helper in views (e.g <%= image_pack_tag 'rails.png' %>)
// or the `imagePath` JavaScript helper below.
//
// const images = require.context('../images', true)
// const imagePath = (name) => images(name, true)

$(document).ready(function () {
  $("#kick_off_before").datetimepicker({
    format: "YYYY-MM-DD hh:mm a",
  });
  $("#kick_off_after").datetimepicker({
    format: "YYYY-MM-DD hh:mm a",
  });

  $("#bet_before").datetimepicker({
    format: "YYYY-MM-DD hh:mm a",
  });
  $("#bet_after").datetimepicker({
    format: "YYYY-MM-DD hh:mm a",
  });
  $("#broadcast_schedule").datetimepicker({
    format: "YYYY-MM-DD hh:mm a",
  });
});

$(".booking").click("ajax:complete", function () {
  $(this).closest("tr").fadeOut();
  setTimeout(function () {
    $("#notice").html("");
  }, 2000);
});



$(document).ready(function(){
  var $remaining = $('#broadcast_char_count'),
  $messages = $remaining.next();
  var max = 1600;

  $('#broadcast_compose_message').keyup(function(){
     var chars = this.value.length,
     messages = Math.ceil(chars / 160),
     remaining =  messages * 160 - (chars  % (messages * 160) || messages * 160);
     if (chars >= max) {
        $('#broadcast_number_of_messages').text(' you have reached the limit');
     }
     else{
        $remaining.text(remaining + ' characters remaining');
        $messages.text(messages + ' message(s)');
     }

  });
});


