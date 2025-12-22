// Start Bootstrap JS
// -----------------------------------

// import $ from "jquery";

function initBootstrap() {
  // Bootstrap 5 doesn't require jQuery
  // Initialize tooltips using Bootstrap 5 API
  const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
  const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl, {
    container: 'body'
  }));

  // Initialize popovers using Bootstrap 5 API
  const popoverTriggerList = document.querySelectorAll('[data-bs-toggle="popover"]');
  const popoverList = [...popoverTriggerList].map(popoverTriggerEl => new bootstrap.Popover(popoverTriggerEl));

  // DROPDOWN INPUTS
  // -----------------------------------
  $(".dropdown input").on("click focus", function (event) {
    event.stopPropagation();
  });
}

export default initBootstrap;
