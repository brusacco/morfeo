// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chartkick"
import 'flowbite';

document.addEventListener('turbo:load', function () {
  // profile - logout
  const userMenuButton = document.getElementById('user-menu-button');
  const userMenuDropdown = document.querySelector('.absolute.right-0');

  let isMenuOpen = false;

  userMenuButton.addEventListener('click', () => {
    isMenuOpen = !isMenuOpen;
    userMenuDropdown.classList.toggle('hidden', !isMenuOpen);
  });

  // Cerrar el menú si se hace clic en cualquier otro lugar de la página
  window.addEventListener('click', (event) => {
    if (isMenuOpen && !userMenuButton.contains(event.target)) {
      isMenuOpen = false;
      userMenuDropdown.classList.add('hidden');
    }
  });
});