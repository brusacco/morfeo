import { Controller } from "@hotwired/stimulus"

// Navigation controller for dropdown menus
// This provides fallback functionality if Alpine.js is not available
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    console.log("Navigation controller connected")
    
    // Close dropdown when clicking outside
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener('click', this.boundClickOutside)
    
    // Close dropdown on escape key
    this.boundEscapeKey = this.escapeKey.bind(this)
    document.addEventListener('keydown', this.boundEscapeKey)
  }

  disconnect() {
    document.removeEventListener('click', this.boundClickOutside)
    document.removeEventListener('keydown', this.boundEscapeKey)
  }

  toggle(event) {
    event.stopPropagation()
    const menu = event.currentTarget.nextElementSibling
    
    // Close all other open menus first
    document.querySelectorAll('.dropdown-menu').forEach(otherMenu => {
      if (otherMenu !== menu && !otherMenu.classList.contains('hidden')) {
        otherMenu.classList.add('hidden')
      }
    })
    
    // Toggle current menu
    menu.classList.toggle('hidden')
    
    // Update aria-expanded
    const isExpanded = !menu.classList.contains('hidden')
    event.currentTarget.setAttribute('aria-expanded', isExpanded)
  }

  clickOutside(event) {
    // Close all menus if click is outside
    const menus = document.querySelectorAll('.dropdown-menu')
    menus.forEach(menu => {
      const button = menu.previousElementSibling
      if (!menu.contains(event.target) && !button.contains(event.target)) {
        menu.classList.add('hidden')
        if (button) {
          button.setAttribute('aria-expanded', 'false')
        }
      }
    })
  }

  escapeKey(event) {
    if (event.key === 'Escape') {
      const menus = document.querySelectorAll('.dropdown-menu')
      menus.forEach(menu => {
        menu.classList.add('hidden')
        const button = menu.previousElementSibling
        if (button) {
          button.setAttribute('aria-expanded', 'false')
        }
      })
    }
  }
}

