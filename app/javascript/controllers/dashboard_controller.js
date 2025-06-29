import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["refreshButton", "lastUpdate"]
  
  connect() {
    // Auto-refresh every 30 seconds
    this.startAutoRefresh()
    
    // Handle mobile touch events
    this.addMobileOptimizations()
  }
  
  disconnect() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }
  
  refresh() {
    // Disable button during refresh
    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.disabled = true
      this.refreshButtonTarget.classList.add("opacity-50")
    }
    
    // Refresh the dashboard frame
    Turbo.visit(window.location.href, {
      frame: "dashboard",
      action: "replace"
    })
    
    // Re-enable button after a short delay
    setTimeout(() => {
      if (this.hasRefreshButtonTarget) {
        this.refreshButtonTarget.disabled = false
        this.refreshButtonTarget.classList.remove("opacity-50")
      }
      this.updateLastRefreshTime()
    }, 1000)
  }
  
  startAutoRefresh() {
    // Refresh every 30 seconds
    this.refreshTimer = setInterval(() => {
      this.refresh()
    }, 30000)
  }
  
  updateLastRefreshTime() {
    if (this.hasLastUpdateTarget) {
      const now = new Date()
      const timeString = now.toLocaleTimeString('ja-JP', { 
        hour: '2-digit', 
        minute: '2-digit' 
      })
      this.lastUpdateTarget.textContent = `最終更新: ${timeString}`
    }
  }
  
  addMobileOptimizations() {
    // Prevent double-tap zoom on mobile
    let lastTouchEnd = 0
    document.addEventListener('touchend', (event) => {
      const now = Date.now()
      if (now - lastTouchEnd <= 300) {
        event.preventDefault()
      }
      lastTouchEnd = now
    }, false)
    
    // Add swipe-to-refresh on mobile
    let touchStartY = 0
    let touchEndY = 0
    
    document.addEventListener('touchstart', (e) => {
      touchStartY = e.changedTouches[0].screenY
    }, false)
    
    document.addEventListener('touchend', (e) => {
      touchEndY = e.changedTouches[0].screenY
      this.handleSwipe()
    }, false)
  }
  
  handleSwipe() {
    // Swipe down to refresh (pull-to-refresh)
    if (touchEndY > touchStartY + 100 && window.scrollY === 0) {
      this.refresh()
    }
  }
}