// TOGGLE STATE
// -----------------------------------

// import $ from "jquery";

function initToggleState() {
  console.log('initToggleState called, jQuery available:', typeof $ !== 'undefined');
  
  if (typeof $ === 'undefined') {
    console.error('jQuery not available in toggle-state.js');
    return;
  }
  
  var $body = $("body");
  var toggle = new StateToggler();

  console.log('Found toggle-state elements:', $("[data-toggle-state]").length);

  $("[data-toggle-state]").on("click", function (e) {
    console.log('Toggle state clicked!');
    e.preventDefault();
    e.stopPropagation();
    var element = $(this),
      classname = element.data("toggleState"),
      target = element.data("target"),
      noPersist = !!element.attr("data-no-persist");

    console.log('Classname to toggle:', classname);
    console.log('Target:', target);

    // Specify a target selector to toggle classname
    // use body by default
    var $target = target ? $(target) : $body;

    console.log('Target element:', $target[0]);
    console.log('Has class before:', $target.hasClass(classname));

    if (classname) {
      if ($target.hasClass(classname)) {
        console.log('Removing class:', classname);
        $target.removeClass(classname);
        if (!noPersist) toggle.removeState(classname);
      } else {
        console.log('Adding class:', classname);
        $target.addClass(classname);
        if (!noPersist) toggle.addState(classname);
      }
    }

    console.log('Has class after:', $target.hasClass(classname));

    // some elements may need this when toggled class change the content size
    if (typeof Event === "function") {
      // modern browsers
      window.dispatchEvent(new Event("resize"));
    } else {
      // old browsers and IE
      var resizeEvent = window.document.createEvent("UIEvents");
      resizeEvent.initUIEvent("resize", true, false, window, 0);
      window.dispatchEvent(resizeEvent);
    }
  });
}

// Handle states to/from localstorage using native localStorage
function StateToggler() {
  var STORAGE_KEY_NAME = "jq-toggleState";

  /** Add a state to the browser storage to be restored later */
  this.addState = function (classname) {
    var data = JSON.parse(localStorage.getItem(STORAGE_KEY_NAME) || '[]');
    if (data instanceof Array) data.push(classname);
    else data = [classname];
    localStorage.setItem(STORAGE_KEY_NAME, JSON.stringify(data));
  };
  
  /** Remove a state from the browser storage */
  this.removeState = function (classname) {
    var data = JSON.parse(localStorage.getItem(STORAGE_KEY_NAME) || '[]');
    if (data) {
      var index = data.indexOf(classname);
      if (index !== -1) data.splice(index, 1);
      localStorage.setItem(STORAGE_KEY_NAME, JSON.stringify(data));
    }
  };
  
  /** Load the state string and restore the classlist */
  this.restoreState = function ($elem) {
    var data = JSON.parse(localStorage.getItem(STORAGE_KEY_NAME) || '[]');
    if (data instanceof Array) $elem.addClass(data.join(" "));
  };
}

export { StateToggler, initToggleState };