import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "backdrop"]
  
  connect() {
    // Close menu when clicking outside
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
  }
  
  toggle() {
    if (this.menuTarget.classList.contains("translate-x-full")) {
      this.open()
    } else {
      this.close()
    }
  }
  
  open() {
    // Show backdrop
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove("hidden")
      setTimeout(() => {
        this.backdropTarget.classList.remove("opacity-0")
      }, 10)
    }
    
    // Slide in menu
    this.menuTarget.classList.remove("translate-x-full")
    
    // Prevent body scroll
    document.body.style.overflow = "hidden"
    
    // Add event listener for clicks outside
    setTimeout(() => {
      document.addEventListener("click", this.closeOnClickOutside)
    }, 100)
  }
  
  close() {
    // Hide backdrop
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.add("opacity-0")
      setTimeout(() => {
        this.backdropTarget.classList.add("hidden")
      }, 300)
    }
    
    // Slide out menu
    this.menuTarget.classList.add("translate-x-full")
    
    // Re-enable body scroll
    document.body.style.overflow = ""
    
    // Remove event listener
    document.removeEventListener("click", this.closeOnClickOutside)
  }
  
  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
  
  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside)
    document.body.style.overflow = ""
  }
}