import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form", "patientSearch", "selectedPatientInfo", "availableSlots", 
    "appointmentTime", "appointmentDate", "treatmentDuration"
  ]
  static values = { 
    searchUrl: String,
    slotsUrl: String 
  }

  connect() {
    this.searchTimeout = null
    this.selectedPatient = null
    this.selectedSlot = null
  }

  // 患者検索機能
  searchPatients(event) {
    const query = event.target.value.trim()
    
    clearTimeout(this.searchTimeout)
    
    if (query.length < 2) {
      this.hideSearchResults()
      return
    }
    
    this.searchTimeout = setTimeout(() => {
      this.performPatientSearch(query)
    }, 300)
  }

  async performPatientSearch(query) {
    try {
      const response = await fetch(`${this.searchUrlValue}?q=${encodeURIComponent(query)}`, {
        headers: {
          "Accept": "application/json"
        }
      })
      
      if (!response.ok) throw new Error("検索エラー")
      
      const patients = await response.json()
      this.displaySearchResults(patients)
    } catch (error) {
      console.error("患者検索エラー:", error)
      this.showMessage("患者検索中にエラーが発生しました", "error")
    }
  }

  displaySearchResults(patients) {
    const resultsContainer = document.getElementById('patient_search_results')
    
    if (!resultsContainer) {
      // 検索結果表示エリアを動的作成
      const searchInput = this.patientSearchTarget
      const resultsDiv = document.createElement('div')
      resultsDiv.id = 'patient_search_results'
      resultsDiv.className = 'absolute z-10 mt-1 w-full bg-white shadow-lg max-h-60 rounded-md py-1 text-base ring-1 ring-black ring-opacity-5 overflow-auto'
      
      searchInput.parentNode.appendChild(resultsDiv)
    }
    
    const container = document.getElementById('patient_search_results')
    
    if (patients.length === 0) {
      container.innerHTML = `
        <div class="p-4 text-sm text-gray-500 text-center">
          該当する患者が見つかりません
        </div>
      `
    } else {
      container.innerHTML = patients.map(patient => `
        <div class="p-3 hover:bg-gray-100 cursor-pointer border-b border-gray-100 patient-result"
             data-patient='${JSON.stringify(patient)}'>
          <div class="font-medium text-gray-900">${patient.name} (${patient.name_kana})</div>
          <div class="text-sm text-gray-500">
            ${patient.patient_number} | ${patient.phone || "電話番号なし"} 
            ${patient.has_line ? '<span class="text-green-600">LINE連携</span>' : ''}
          </div>
          <div class="text-xs text-gray-400">
            予約歴: ${patient.appointments_count}件 | 最終来院: ${patient.last_visit || "なし"}
          </div>
        </div>
      `).join("")
      
      // クリックイベントを追加
      container.querySelectorAll(".patient-result").forEach(element => {
        element.addEventListener("click", () => {
          const patientData = JSON.parse(element.dataset.patient)
          this.selectPatient(patientData)
        })
      })
    }
    
    container.classList.remove("hidden")
  }

  selectPatient(patient) {
    this.selectedPatient = patient
    
    // 検索フィールドを更新
    if (this.hasPatientSearchTarget) {
      this.patientSearchTarget.value = patient.name
    }
    
    // 選択された患者情報を表示
    const infoDiv = document.getElementById('selected_patient_info')
    const nameElement = document.getElementById('selected_patient_name')
    const detailsElement = document.getElementById('selected_patient_details')
    
    if (infoDiv && nameElement && detailsElement) {
      nameElement.textContent = `${patient.name} (${patient.name_kana})`
      detailsElement.textContent = `${patient.patient_number} | ${patient.phone || '電話番号なし'} | 予約歴: ${patient.appointments_count}件`
      
      infoDiv.classList.remove('hidden')
    }
    
    // hidden fieldを更新
    const selectedPatientIdField = document.getElementById('selected_patient_id')
    const appointmentPatientIdField = document.getElementById('appointment_patient_id')
    
    if (selectedPatientIdField) selectedPatientIdField.value = patient.id
    if (appointmentPatientIdField) appointmentPatientIdField.value = patient.id
    
    this.hideSearchResults()
    
    // カスタムイベントを発火
    this.element.dispatchEvent(new CustomEvent("patient:selected", {
      detail: patient,
      bubbles: true
    }))
  }

  hideSearchResults() {
    const container = document.getElementById('patient_search_results')
    if (container) {
      container.classList.add("hidden")
    }
  }

  // 空き時間枠の取得と表示
  async loadAvailableSlots() {
    if (!this.hasAppointmentDateTarget || !this.hasTreatmentDurationTarget) {
      return
    }
    
    const date = this.appointmentDateTarget.value
    const duration = this.treatmentDurationTarget.value
    
    if (!date) return
    
    try {
      const response = await fetch(
        `${this.slotsUrlValue}?date=${date}&treatment_duration=${duration}`,
        {
          headers: {
            "Accept": "application/json"
          }
        }
      )
      
      if (!response.ok) throw new Error("空き枠取得エラー")
      
      const data = await response.json()
      this.displayAvailableSlots(data.available_slots)
    } catch (error) {
      console.error("空き枠取得エラー:", error)
      this.showMessage("空き枠の取得中にエラーが発生しました", "error")
    }
  }

  displayAvailableSlots(slots) {
    const container = document.getElementById('available_slots')
    
    if (slots.length === 0) {
      container.innerHTML = `
        <div class="col-span-full text-center py-8">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">空き枠なし</h3>
          <p class="mt-1 text-sm text-gray-500">この日は予約できる時間がありません</p>
        </div>
      `
    } else {
      container.innerHTML = slots.map(slot => `
        <button type="button" 
                class="p-3 text-sm border border-gray-300 rounded-lg hover:bg-blue-50 hover:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500 slot-button"
                data-time="${slot.time}"
                data-datetime="${slot.datetime}">
          <div class="font-medium">${slot.time}</div>
          <div class="text-xs text-gray-500">${slot.display_time}</div>
        </button>
      `).join("")
      
      // クリックイベントを追加
      container.querySelectorAll(".slot-button").forEach(button => {
        button.addEventListener("click", () => this.selectTimeSlot(button))
      })
    }
  }

  selectTimeSlot(button) {
    // 既存の選択をクリア
    const allSlots = document.querySelectorAll('.slot-button')
    allSlots.forEach(slot => {
      slot.classList.remove('bg-blue-100', 'border-blue-500', 'text-blue-700')
      slot.classList.add('border-gray-300')
    })
    
    // 新しい選択をハイライト
    button.classList.remove('border-gray-300')
    button.classList.add('bg-blue-100', 'border-blue-500', 'text-blue-700')
    
    // データを保存
    this.selectedSlot = {
      time: button.dataset.time,
      datetime: button.dataset.datetime
    }
    
    // hidden fieldを更新
    if (this.hasAppointmentTimeTarget) {
      this.appointmentTimeTarget.value = button.dataset.datetime
    }
  }

  // フォーム送信処理
  async submitBooking(event) {
    event.preventDefault()
    
    if (!this.validateForm()) {
      return
    }
    
    const formData = new FormData(this.formTarget)
    
    try {
      const response = await fetch(this.formTarget.action, {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json'
        }
      })
      
      const result = await response.json()
      
      if (result.success) {
        this.showMessage(result.message, "success")
        this.resetForm()
        
        // 今日の予約リストを更新
        this.refreshTodayAppointments()
      } else {
        this.showMessage(result.error || "予約の登録に失敗しました", "error")
      }
    } catch (error) {
      console.error("予約登録エラー:", error)
      this.showMessage("予約登録中にエラーが発生しました", "error")
    }
  }

  validateForm() {
    const requiredFields = [
      { element: this.selectedPatient, message: "患者を選択してください" },
      { element: this.selectedSlot, message: "時間枠を選択してください" },
      { element: this.appointmentDateTarget?.value, message: "予約日を選択してください" }
    ]
    
    for (const field of requiredFields) {
      if (!field.element) {
        this.showMessage(field.message, "error")
        return false
      }
    }
    
    return true
  }

  resetForm() {
    this.formTarget.reset()
    this.selectedPatient = null
    this.selectedSlot = null
    
    // UI要素をリセット
    const infoDiv = document.getElementById('selected_patient_info')
    if (infoDiv) infoDiv.classList.add('hidden')
    
    const slotsContainer = document.getElementById('available_slots')
    if (slotsContainer) {
      slotsContainer.innerHTML = '<p class="col-span-full text-sm text-gray-500 text-center py-4">予約日を選択してください</p>'
    }
    
    this.hideSearchResults()
  }

  async refreshTodayAppointments() {
    // 今日の予約リストを再取得して更新
    try {
      const response = await fetch(window.location.pathname, {
        headers: {
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        // ページ全体をリロードするか、部分的に更新
        window.location.reload()
      }
    } catch (error) {
      console.error("予約リスト更新エラー:", error)
    }
  }

  showMessage(message, type = 'success') {
    // グローバル関数を呼び出し
    if (typeof showFlashMessage === 'function') {
      showFlashMessage(message, type)
    } else {
      alert(message)
    }
  }
}