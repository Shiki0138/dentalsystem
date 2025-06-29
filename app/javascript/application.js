// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Configure Turbo for better mobile experience
import { Turbo } from "@hotwired/turbo-rails"

// Disable Turbo cache for better real-time updates
Turbo.session.drive = true

// Handle network errors gracefully
document.addEventListener("turbo:fetch-request-error", (event) => {
  if (event.detail.error.message === "Failed to fetch") {
    console.error("Network error - showing offline message")
    const offlineMessage = document.createElement("div")
    offlineMessage.className = "fixed top-4 right-4 bg-red-500 text-white px-4 py-2 rounded-lg shadow-lg z-50"
    offlineMessage.textContent = "ネットワークエラー：接続を確認してください"
    document.body.appendChild(offlineMessage)
    
    setTimeout(() => {
      offlineMessage.remove()
    }, 5000)
  }
})