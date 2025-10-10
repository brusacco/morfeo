// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chartkick"
// import "Chart.bundle"

// Highcharts is loaded globally from CDN in layout
// No need to import it as a module

document.addEventListener("turbo:load", function () {
  // Toggle para el menú de usuario (Cerrar Sesión)
  var userMenuButton = document.getElementById('user-menu-button');
  var userMenu = document.getElementById('user-menu');

  userMenuButton.addEventListener('click', function (event) {
    userMenu.classList.toggle('hidden');
    event.stopPropagation();
  });

  // Toggle para el menú de tópicos
  var topicsMenuButton = document.getElementById('topics-menu-button');
  var topicsMenu = document.getElementById('topics-menu');

  if (topicsMenuButton && topicsMenu) {
    topicsMenuButton.addEventListener('click', function (event) {
      topicsMenu.classList.toggle('hidden');
      event.stopPropagation();
    });

    topicsMenu.addEventListener('click', function (event) {
      event.stopPropagation();
    });
  }

  // Toggle para el menú de tópicos de Facebook
  var facebookTopicsMenuButton = document.getElementById('facebook-topics-menu-button');
  var facebookTopicsMenu = document.getElementById('facebook-topics-menu');

  if (facebookTopicsMenuButton && facebookTopicsMenu) {
    facebookTopicsMenuButton.addEventListener('click', function (event) {
      facebookTopicsMenu.classList.toggle('hidden');
      event.stopPropagation();
    });

    facebookTopicsMenu.addEventListener('click', function (event) {
      event.stopPropagation();
    });
  }

  // Ocultar menús cuando se hace clic fuera de ellos
  document.addEventListener('click', function () {
    if (userMenu && !userMenu.classList.contains('hidden')) {
      userMenu.classList.add('hidden');
    }
    if (topicsMenu && !topicsMenu.classList.contains('hidden')) {
      topicsMenu.classList.add('hidden');
    }
    if (facebookTopicsMenu && !facebookTopicsMenu.classList.contains('hidden')) {
      facebookTopicsMenu.classList.add('hidden');
    }
  });
});