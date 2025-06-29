import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "phone", "results", "alert"]
  static values = { url: String }

  connect() {
    this.checkTimeout = null
  }

  check() {
    clearTimeout(this.checkTimeout)
    
    const name = this.nameTarget.value.trim()
    const phone = this.phoneTarget.value.trim()
    
    if (name.length < 2 && phone.length < 10) {
      this.hideAlert()
      return
    }
    
    this.checkTimeout = setTimeout(() => {
      this.performCheck(name, phone)
    }, 500)
  }

  async performCheck(name, phone) {
    try {
      const params = new URLSearchParams()
      if (name) params.append("name", name)
      if (phone) params.append("phone", phone)
      
      const response = await fetch(`${this.urlValue}?${params}`, {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
      
      if (!response.ok) throw new Error("重複チェックエラー")
      
      const duplicates = await response.json()
      
      if (duplicates.length > 0) {
        this.displayDuplicates(duplicates)
      } else {
        this.hideAlert()
      }
    } catch (error) {
      console.error("重複チェックエラー:", error)
    }
  }

  displayDuplicates(duplicates) {
    const duplicatesList = duplicates.map(patient => `
      <li class="mb-2">
        <a href="/patients/${patient.id}" target="_blank" class="text-yellow-700 underline font-medium">
          ${patient.name} (${patient.patient_number})
        </a>
        - 電話: ${patient.phone || "なし"}, メール: ${patient.email || "なし"}
      </li>
    `).join("")
    
    this.resultsTarget.innerHTML = `
      <div class="rounded-md bg-yellow-50 p-4 mb-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-yellow-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-yellow-800">
              重複の可能性がある患者が見つかりました
            </h3>
            <div class="mt-2 text-sm text-yellow-700">
              <p>以下の患者と重複している可能性があります:</p>
              <ul class="list-disc pl-5 mt-2">
                ${duplicatesList}
              </ul>
              <p class="mt-2">
                既存の患者情報を確認するか、新規登録を続けてください。
              </p>
            </div>
          </div>
        </div>
      </div>
    `
    
    this.alertTarget.classList.remove("hidden")
  }

  hideAlert() {
    this.alertTarget.classList.add("hidden")
  }
}