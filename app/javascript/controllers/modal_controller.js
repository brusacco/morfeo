import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  closeModal(event) {
    event.preventDefault();
    this.modalTarget.classList.add("hidden");
  }
}