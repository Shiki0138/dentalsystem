import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "selected"]
  static values = { 
    url: String,
    minLength: { type: Number, default: 2 }
  }

  connect() {
    this.timeout = null
    this.hideResultsOnClickOutside()
  }

  search(event) {
    const query = event.target.value.trim()
    
    clearTimeout(this.timeout)
    
    if (query.length < this.minLengthValue) {
      this.hideResults()
      return
    }
    
    this.timeout = setTimeout(() => {
      this.performSearch(query)
    }, 300)
  }

  async performSearch(query) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`, {
        headers: {
          "Accept": "application/json"
        }
      })
      
      if (!response.ok) throw new Error("検索エラー")
      
      const patients = await response.json()
      this.displayResults(patients)
    } catch (error) {
      console.error("検索エラー:", error)
      this.displayError()
    }
  }

  displayResults(patients) {
    if (patients.length === 0) {
      this.resultsTarget.innerHTML = `
        <div class="p-4 text-sm text-gray-500">
          該当する患者が見つかりません
        </div>
      `
    } else {
      this.resultsTarget.innerHTML = patients.map(patient => `
        <div class="p-2 hover:bg-gray-100 cursor-pointer patient-result" 
             data-patient-id="${patient.id}"
             data-patient-name="${patient.name}"
             data-patient-kana="${patient.name_kana}"
             data-patient-phone="${patient.phone}"
             data-patient-email="${patient.email}">
          <div class="font-medium">${patient.name} (${patient.name_kana})</div>
          <div class="text-sm text-gray-500">
            ${patient.patient_number} | ${patient.phone || "電話番号なし"} | ${patient.email || "メールなし"}
          </div>
        </div>
      `).join("")
      
      this.resultsTarget.querySelectorAll(".patient-result").forEach(element => {
        element.addEventListener("click", () => this.selectPatient(element))
      })
    }
    
    this.showResults()
  }

  selectPatient(element) {
    const patientData = {
      id: element.dataset.patientId,
      name: element.dataset.patientName,
      name_kana: element.dataset.patientKana,
      phone: element.dataset.patientPhone,
      email: element.dataset.patientEmail
    }
    
    this.selectedTarget.value = patientData.id
    this.inputTarget.value = patientData.name
    
    const event = new CustomEvent("patient:selected", {
      detail: patientData,
      bubbles: true
    })
    this.element.dispatchEvent(event)
    
    this.hideResults()
  }

  displayError() {
    this.resultsTarget.innerHTML = `
      <div class="p-4 text-sm text-red-600">
        検索中にエラーが発生しました
      </div>
    `
    this.showResults()
  }

  showResults() {
    this.resultsTarget.classList.remove("hidden")
  }

  hideResults() {
    this.resultsTarget.classList.add("hidden")
  }

  hideResultsOnClickOutside() {
    document.addEventListener("click", (event) => {
      if (!this.element.contains(event.target)) {
        this.hideResults()
      }
    })
  }

  clear() {
    this.inputTarget.value = ""
    this.selectedTarget.value = ""
    this.hideResults()
  }
}