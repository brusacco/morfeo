// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chartkick"
// import "Chart.bundle"

// Highcharts is loaded globally from CDN in layout
// No need to import it as a module

// Navigation is now handled by Alpine.js in _nav.html.erb
// No manual event listeners needed here