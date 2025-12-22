require("@rails/ujs").start();
// require("turbolinks").start();
// we don't use animated progress
// Turbolinks.ProgressBar.prototype.refresh = function() {}
// // custom css
// Turbolinks.ProgressBar.defaultCSS = ""
//
// // creates progress bar with custom markup
// Turbolinks.ProgressBar.prototype.installProgressElement = function() {
//   return $('body').before($('<div class="overlay"></div><div class="wait" style="text-align: center; background-color: green;height: 20px;"><i class="far fa-hourglass fa-spin"></i></div>'));
// }
//
// // removes progress bar with custom markup
// Turbolinks.ProgressBar.prototype.uninstallProgressElement = function() {
//   $(document).find('.wait, .overlay').remove();
// }
//
// // changes the default 500ms threshold to show progress bar
// Turbolinks.BrowserAdapter.prototype.showProgressBarAfterDelay = function() {
//   return this.progressBarTimeout = setTimeout(this.showProgressBar, 5);
// };

// import "controllers";
import LocalTime from "local-time";
LocalTime.start();

// require("@rails/activestorage").start();
// import "@fortawesome/fontawesome-free/js/all";
require("src/App");
