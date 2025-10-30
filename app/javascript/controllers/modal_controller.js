import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  connect() {
    // Bind the keyboard handler to this instance
    this.handleKeydown = this.handleKeydown.bind(this);
    
    // Add event listener when modal is visible
    if (!this.modalTarget.classList.contains('hidden')) {
      document.addEventListener('keydown', this.handleKeydown);
      this.modalTarget.focus();
    }
    
    // Observe class changes to add/remove listener dynamically
    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.attributeName === 'class') {
          if (this.modalTarget.classList.contains('hidden')) {
            document.removeEventListener('keydown', this.handleKeydown);
          } else {
            document.addEventListener('keydown', this.handleKeydown);
            // Focus the modal when it becomes visible
            setTimeout(() => this.modalTarget.focus(), 100);
          }
        }
      });
    });
    
    this.observer.observe(this.modalTarget, { attributes: true });
  }

  disconnect() {
    // Clean up event listener and observer
    document.removeEventListener('keydown', this.handleKeydown);
    if (this.observer) {
      this.observer.disconnect();
    }
  }

  handleKeydown(event) {
    // Close modal on ESC key
    if (event.key === 'Escape' || event.key === 'Esc') {
      this.closeModal(event);
    }
  }

  closeModal(event) {
    if (event) {
      event.preventDefault();
    }
    this.modalTarget.classList.add("hidden");
    // Remove the keyboard listener when closing
    document.removeEventListener('keydown', this.handleKeydown);
  }
}