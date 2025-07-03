import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="calendar"
export default class extends Controller {
  static values = { 
    eventsUrl: String,
    createUrl: String,
    searchPatientsUrl: String,
    aiOptimizationUrl: String,
    dashboardIntegrationUrl: String
  }
  static values = { 
    eventsUrl: String,
    createUrl: String,
    searchPatientsUrl: String,
    aiOptimizationUrl: String,
    dashboardIntegrationUrl: String
  }

  static targets = []

  connect() {
    this.initializeCalendar()
    this.initializeModals()
    this.initializePatientSearch()
    this.initializeViewControls()
    this.initializeAIOptimization()
    this.initializeDashboardIntegration()
  }

  disconnect() {
    if (this.calendar) {
      this.calendar.destroy()
    }
  }

  initializeCalendar() {
    const calendarEl = document.getElementById('calendar')
    
    this.calendar = new FullCalendar.Calendar(calendarEl, {
      
      // 初期表示設定
      initialView: 'dayGridMonth',
      height: 'auto',
      
      // ヘッダー設定（カスタムコントロールを使用するため非表示）
      headerToolbar: false,
      
      // 日本語ローカライゼーション
      locale: 'ja',
      firstDay: 1, // 月曜日を週の最初に
      
      // 時間設定
      slotMinTime: '09:00:00',
      slotMaxTime: '18:00:00',
      slotDuration: '01:00:00',
      
      // 営業日設定
      businessHours: [
        {
          daysOfWeek: [1, 2, 3, 4, 5], // 月-金
          startTime: '09:00',
          endTime: '18:00'
        },
        {
          daysOfWeek: [6], // 土曜日
          startTime: '09:00',
          endTime: '17:00'
        }
      ],
      
      // 週末表示設定
      weekends: true,
      hiddenDays: [0], // 日曜日を非表示
      
      // イベント設定
      events: {
        url: this.eventsUrlValue,
        method: 'GET',
        failure: (error) => {
          console.error('カレンダーイベントの読み込みに失敗しました:', error)
          this.showNotification('予約データの読み込みに失敗しました', 'error')
        }
      },
      
      // イベントクリック時の処理
      eventClick: (info) => {
        this.showAppointmentDetail(info.event)
        info.jsEvent.preventDefault()
      },
      
      // 日付クリック時の処理（新規予約作成）
      dateClick: (info) => {
        this.showCreateAppointmentModal(info.date)
      },
      
      // イベントドラッグ&ドロップ
      editable: true,
      eventDrop: (info) => {
        this.updateAppointmentDateTime(info.event, info.event.start)
      },
      
      // イベントリサイズ
      eventResize: (info) => {
        this.updateAppointmentDateTime(info.event, info.event.start, info.event.end)
      },
      
      // 時間軸のクリック（週・日表示時）
      selectable: true,
      selectMirror: true,
      select: (info) => {
        this.showCreateAppointmentModal(info.start)
        this.calendar.unselect()
      },
      
      // イベント表示カスタマイズ
      eventDisplay: 'block',
      displayEventTime: true,
      displayEventEnd: false,
      
      // モバイル対応
      aspectRatio: window.innerWidth < 768 ? 1.0 : 1.35,
      
      // 現在時刻表示
      nowIndicator: true,
      
      // イベントマウスオーバー時のツールチップ
      eventMouseEnter: (info) => {
        this.showEventTooltip(info.event, info.el)
      },
      
      eventMouseLeave: (info) => {
        this.hideEventTooltip()
      }
    })

    this.calendar.render()
    this.updateCurrentDateDisplay()
  }

  initializeViewControls() {
    // ビューボタンの制御
    const monthBtn = document.getElementById('monthViewBtn')
    const weekBtn = document.getElementById('weekViewBtn')
    const dayBtn = document.getElementById('dayViewBtn')
    const todayBtn = document.getElementById('todayBtn')
    const prevBtn = document.getElementById('prevBtn')
    const nextBtn = document.getElementById('nextBtn')

    monthBtn?.addEventListener('click', () => {
      this.calendar.changeView('dayGridMonth')
      this.updateViewButtons('month')
      this.updateCurrentDateDisplay()
    })

    weekBtn?.addEventListener('click', () => {
      this.calendar.changeView('timeGridWeek')
      this.updateViewButtons('week')
      this.updateCurrentDateDisplay()
    })

    dayBtn?.addEventListener('click', () => {
      this.calendar.changeView('timeGridDay')
      this.updateViewButtons('day')
      this.updateCurrentDateDisplay()
    })

    todayBtn?.addEventListener('click', () => {
      this.calendar.today()
      this.updateCurrentDateDisplay()
    })

    prevBtn?.addEventListener('click', () => {
      this.calendar.prev()
      this.updateCurrentDateDisplay()
    })

    nextBtn?.addEventListener('click', () => {
      this.calendar.next()
      this.updateCurrentDateDisplay()
    })
  }

  updateViewButtons(activeView) {
    const buttons = ['monthViewBtn', 'weekViewBtn', 'dayViewBtn']
    
    buttons.forEach(buttonId => {
      const button = document.getElementById(buttonId)
      if (button) {
        const isActive = (
          (buttonId === 'monthViewBtn' && activeView === 'month') ||
          (buttonId === 'weekViewBtn' && activeView === 'week') ||
          (buttonId === 'dayViewBtn' && activeView === 'day')
        )
        
        if (isActive) {
          button.className = 'px-3 py-1 text-sm font-medium text-indigo-600 bg-indigo-100 rounded-md hover:bg-indigo-200 focus:outline-none focus:ring-2 focus:ring-indigo-500'
        } else {
          button.className = 'px-3 py-1 text-sm font-medium text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200 focus:outline-none focus:ring-2 focus:ring-gray-500'
        }
      }
    })
  }

  updateCurrentDateDisplay() {
    const currentDateElement = document.getElementById('currentDate')
    if (currentDateElement && this.calendar) {
      const currentDate = this.calendar.getDate()
      const viewType = this.calendar.view.type
      
      let dateText = ''
      
      if (viewType === 'dayGridMonth') {
        dateText = currentDate.toLocaleDateString('ja-JP', { year: 'numeric', month: 'long' })
      } else if (viewType === 'timeGridWeek') {
        const startOfWeek = new Date(currentDate)
        startOfWeek.setDate(currentDate.getDate() - currentDate.getDay() + 1)
        const endOfWeek = new Date(startOfWeek)
        endOfWeek.setDate(startOfWeek.getDate() + 6)
        
        dateText = `${startOfWeek.toLocaleDateString('ja-JP', { month: 'short', day: 'numeric' })} - ${endOfWeek.toLocaleDateString('ja-JP', { month: 'short', day: 'numeric' })}`
      } else if (viewType === 'timeGridDay') {
        dateText = currentDate.toLocaleDateString('ja-JP', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' })
      }
      
      currentDateElement.textContent = dateText
    }
  }

  initializeModals() {
    // 予約作成モーダル
    const createModal = document.getElementById('createAppointmentModal')
    const closeCreateBtn = document.getElementById('closeCreateModal')
    const cancelCreateBtn = document.getElementById('cancelCreateBtn')

    closeCreateBtn?.addEventListener('click', () => this.hideCreateAppointmentModal())
    cancelCreateBtn?.addEventListener('click', () => this.hideCreateAppointmentModal())

    // 予約詳細モーダル
    const detailModal = document.getElementById('appointmentDetailModal')
    const closeDetailBtn = document.getElementById('closeDetailModal')

    closeDetailBtn?.addEventListener('click', () => this.hideAppointmentDetailModal())

    // モーダル外クリックで閉じる
    createModal?.addEventListener('click', (e) => {
      if (e.target === createModal) this.hideCreateAppointmentModal()
    })

    detailModal?.addEventListener('click', (e) => {
      if (e.target === detailModal) this.hideAppointmentDetailModal()
    })

    // ESCキーで閉じる
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        this.hideCreateAppointmentModal()
        this.hideAppointmentDetailModal()
      }
    })
  }

  initializePatientSearch() {
    const searchInput = document.getElementById('patientSearch')
    const searchResults = document.getElementById('patientSearchResults')
    let searchTimeout

    searchInput?.addEventListener('input', (e) => {
      clearTimeout(searchTimeout)
      const query = e.target.value.trim()

      if (query.length < 2) {
        this.hidePatientSearchResults()
        return
      }

      searchTimeout = setTimeout(() => {
        this.searchPatients(query)
      }, 300)
    })

    // 検索結果外クリックで閉じる
    document.addEventListener('click', (e) => {
      if (!searchInput?.contains(e.target) && !searchResults?.contains(e.target)) {
        this.hidePatientSearchResults()
      }
    })
  }

  async searchPatients(query) {
    try {
      const response = await fetch(`${this.searchPatientsUrlValue}?q=${encodeURIComponent(query)}`)
      const patients = await response.json()

      this.displayPatientSearchResults(patients)
    } catch (error) {
      console.error('患者検索エラー:', error)
      this.showNotification('患者検索に失敗しました', 'error')
    }
  }

  displayPatientSearchResults(patients) {
    const resultsContainer = document.getElementById('patientSearchResults')
    
    if (!resultsContainer) return

    if (patients.length === 0) {
      resultsContainer.innerHTML = '<div class="p-2 text-sm text-gray-500">該当する患者が見つかりません</div>'
    } else {
      resultsContainer.innerHTML = patients.map(patient => `
        <div class="p-2 hover:bg-gray-100 cursor-pointer border-b border-gray-100 last:border-b-0" data-patient-id="${patient.id}">
          <div class="font-medium text-gray-900">${patient.name}</div>
          <div class="text-sm text-gray-500">${patient.phone} ${patient.email || ''}</div>
        </div>
      `).join('')

      // 患者選択のイベントリスナー
      resultsContainer.querySelectorAll('[data-patient-id]').forEach(element => {
        element.addEventListener('click', (e) => {
          const patientId = e.currentTarget.dataset.patientId
          const patientName = e.currentTarget.querySelector('.font-medium').textContent
          const patientInfo = e.currentTarget.querySelector('.text-sm').textContent

          this.selectPatient(patientId, patientName, patientInfo)
        })
      })
    }

    resultsContainer.classList.remove('hidden')
  }

  selectPatient(patientId, patientName, patientInfo) {
    const searchInput = document.getElementById('patientSearch')
    const hiddenInput = document.getElementById('selectedPatientId')
    const infoDiv = document.getElementById('selectedPatientInfo')

    if (searchInput) searchInput.value = patientName
    if (hiddenInput) hiddenInput.value = patientId
    if (infoDiv) {
      infoDiv.textContent = patientInfo
      infoDiv.classList.remove('hidden')
    }

    this.hidePatientSearchResults()
  }

  hidePatientSearchResults() {
    const resultsContainer = document.getElementById('patientSearchResults')
    resultsContainer?.classList.add('hidden')
  }

  showCreateAppointmentModal(selectedDate = null) {
    const modal = document.getElementById('createAppointmentModal')
    const form = document.getElementById('createAppointmentForm')
    const dateInput = document.getElementById('appointmentDateTime')

    // フォームリセット
    form?.reset()
    document.getElementById('selectedPatientId').value = ''
    document.getElementById('selectedPatientInfo')?.classList.add('hidden')
    this.hidePatientSearchResults()

    // 選択された日時を設定
    if (selectedDate && dateInput) {
      const localDateTime = new Date(selectedDate.getTime() - selectedDate.getTimezoneOffset() * 60000)
        .toISOString()
        .slice(0, 16)
      dateInput.value = localDateTime
    }

    modal?.classList.remove('hidden')
    document.body.style.overflow = 'hidden'

    // 患者検索にフォーカス
    setTimeout(() => {
      document.getElementById('patientSearch')?.focus()
    }, 100)
  }

  hideCreateAppointmentModal() {
    const modal = document.getElementById('createAppointmentModal')
    modal?.classList.add('hidden')
    document.body.style.overflow = 'auto'
  }

  showAppointmentDetail(event) {
    const modal = document.getElementById('appointmentDetailModal')
    const content = document.getElementById('appointmentDetailContent')

    if (!content) return

    const props = event.extendedProps
    const startTime = event.start.toLocaleString('ja-JP')
    const endTime = event.end ? event.end.toLocaleString('ja-JP') : ''

    content.innerHTML = `
      <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
        <dt class="text-sm font-medium text-gray-500">患者名</dt>
        <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">${props.patientName}</dd>
      </div>
      <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
        <dt class="text-sm font-medium text-gray-500">電話番号</dt>
        <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">${props.patientPhone || 'なし'}</dd>
      </div>
      <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
        <dt class="text-sm font-medium text-gray-500">予約日時</dt>
        <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">${startTime}${endTime ? ' - ' + endTime : ''}</dd>
      </div>
      <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
        <dt class="text-sm font-medium text-gray-500">治療内容</dt>
        <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">${props.treatmentType || '一般診療'}</dd>
      </div>
      <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
        <dt class="text-sm font-medium text-gray-500">ステータス</dt>
        <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${this.getStatusBadgeClass(props.status)}">
            ${this.getStatusText(props.status)}
          </span>
        </dd>
      </div>
      ${props.notes ? `
        <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
          <dt class="text-sm font-medium text-gray-500">備考</dt>
          <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">${props.notes}</dd>
        </div>
      ` : ''}
    `

    // ボタンのイベントリスナー設定
    const editBtn = document.getElementById('editAppointmentBtn')
    const cancelBtn = document.getElementById('cancelAppointmentBtn')

    editBtn?.replaceWith(editBtn.cloneNode(true))
    cancelBtn?.replaceWith(cancelBtn.cloneNode(true))

    document.getElementById('editAppointmentBtn')?.addEventListener('click', () => {
      window.location.href = `/appointments/${event.id}/edit`
    })

    document.getElementById('cancelAppointmentBtn')?.addEventListener('click', () => {
      this.cancelAppointment(event.id)
    })

    modal?.classList.remove('hidden')
    document.body.style.overflow = 'hidden'
  }

  hideAppointmentDetailModal() {
    const modal = document.getElementById('appointmentDetailModal')
    modal?.classList.add('hidden')
    document.body.style.overflow = 'auto'
  }

  async updateAppointmentDateTime(event, newStart, newEnd = null) {
    try {
      const response = await fetch(`/appointments/${event.id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          appointment: {
            appointment_date: newStart.toISOString()
          }
        })
      })

      if (response.ok) {
        this.showNotification('予約時間を更新しました', 'success')
      } else {
        throw new Error('更新に失敗しました')
      }
    } catch (error) {
      console.error('予約更新エラー:', error)
      this.showNotification('予約時間の更新に失敗しました', 'error')
      // 変更を元に戻す
      event.setProp('start', event.extendedProps.originalStart)
      if (newEnd) event.setProp('end', event.extendedProps.originalEnd)
    }
  }

  async cancelAppointment(appointmentId) {
    if (!confirm('この予約をキャンセルしますか？')) return

    try {
      const response = await fetch(`/appointments/${appointmentId}/cancel`, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        this.showNotification('予約をキャンセルしました', 'success')
        this.calendar.refetchEvents()
        this.hideAppointmentDetailModal()
      } else {
        throw new Error('キャンセルに失敗しました')
      }
    } catch (error) {
      console.error('予約キャンセルエラー:', error)
      this.showNotification('予約のキャンセルに失敗しました', 'error')
    }
  }

  getStatusBadgeClass(status) {
    switch (status) {
      case 'booked':
        return 'bg-blue-100 text-blue-800'
      case 'visited':
        return 'bg-green-100 text-green-800'
      case 'completed':
        return 'bg-gray-100 text-gray-800'
      case 'cancelled':
        return 'bg-red-100 text-red-800'
      case 'no_show':
        return 'bg-amber-100 text-amber-800'
      default:
        return 'bg-indigo-100 text-indigo-800'
    }
  }

  getStatusText(status) {
    switch (status) {
      case 'booked':
        return '予約済み'
      case 'visited':
        return '確認済み'
      case 'completed':
        return '完了'
      case 'cancelled':
        return 'キャンセル'
      case 'no_show':
        return '無断キャンセル'
      default:
        return 'その他'
    }
  }

  showEventTooltip(event, element) {
    // 簡単なツールチップ実装
    const tooltip = document.createElement('div')
    tooltip.className = 'absolute z-50 bg-gray-800 text-white text-xs rounded py-1 px-2 pointer-events-none'
    tooltip.textContent = `${event.extendedProps.patientName} - ${event.extendedProps.treatmentType || '診療'}`
    
    document.body.appendChild(tooltip)
    
    const rect = element.getBoundingClientRect()
    tooltip.style.left = rect.left + 'px'
    tooltip.style.top = (rect.top - tooltip.offsetHeight - 5) + 'px'
    
    this.currentTooltip = tooltip
  }

  hideEventTooltip() {
    if (this.currentTooltip) {
      this.currentTooltip.remove()
      this.currentTooltip = null
    }
  }

  showNotification(message, type = 'info') {
    // 簡単な通知システム
    const notification = document.createElement('div')
    const bgColor = type === 'success' ? 'bg-green-500' : type === 'error' ? 'bg-red-500' : 'bg-blue-500'
    
    notification.className = `fixed top-4 right-4 ${bgColor} text-white px-4 py-2 rounded-md shadow-lg z-50 transition-all duration-300`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.style.opacity = '0'
      setTimeout(() => notification.remove(), 300)
    }, 3000)
  }

  // AI最適化システムの初期化
  initializeAIOptimization() {
    this.aiOptimizationEngine = {
      // 最適な予約時間をAIが提案
      async suggestOptimalTime(patientId, treatmentType) {
        try {
          const response = await fetch('/api/ai/suggest_appointment_time', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
            },
            body: JSON.stringify({ patient_id: patientId, treatment_type: treatmentType })
          })
          return await response.json()
        } catch (error) {
          console.error('AI最適化エラー:', error)
        }
      },

      // 予約競合のAI予測
      async predictConflicts(appointmentData) {
        try {
          const response = await fetch('/api/ai/predict_conflicts', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
            },
            body: JSON.stringify(appointmentData)
          })
          return await response.json()
        } catch (error) {
          console.error('競合予測エラー:', error)
        }
      },

      // 繰り返し予約の最適化
      async optimizeRecurringAppointments(patientId, pattern) {
        try {
          const response = await fetch('/api/ai/optimize_recurring', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
            },
            body: JSON.stringify({ patient_id: patientId, pattern: pattern })
          })
          return await response.json()
        } catch (error) {
          console.error('繰り返し予約最適化エラー:', error)
        }
      }
    }
  }

  // ダッシュボードとのリアルタイム統合
  initializeDashboardIntegration() {
    // WebSocket接続でリアルタイム同期
    if (this.dashboardIntegrationUrlValue) {
      this.dashboardSocket = new WebSocket(this.dashboardIntegrationUrlValue)
      
      this.dashboardSocket.onmessage = (event) => {
        const data = JSON.parse(event.data)
        if (data.type === 'appointment_update') {
          this.calendar.refetchEvents()
          this.showAIInsight(data.insight)
        }
      }

      this.dashboardSocket.onerror = (error) => {
        console.error('Dashboard WebSocket エラー:', error)
      }
    }
  }

  // AI洞察の表示
  showAIInsight(insight) {
    const insightElement = document.createElement('div')
    insightElement.className = 'fixed bottom-4 right-4 bg-gradient-to-r from-purple-500 to-indigo-600 text-white px-6 py-3 rounded-lg shadow-lg z-50 transition-all duration-300'
    insightElement.innerHTML = `
      <div class="flex items-center">
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"></path>
        </svg>
        <span class="font-medium">AI洞察: ${insight}</span>
      </div>
    `
    
    document.body.appendChild(insightElement)
    
    setTimeout(() => {
      insightElement.style.opacity = '0'
      setTimeout(() => insightElement.remove(), 300)
    }, 5000)
  }

  // 予約作成時のAI最適化
  async handleAIOptimizedAppointmentCreation(patientId, treatmentType) {
    // AI最適時間の提案を取得
    const aiSuggestion = await this.aiOptimizationEngine.suggestOptimalTime(patientId, treatmentType)
    
    if (aiSuggestion && aiSuggestion.suggested_times) {
      // 提案された時間をカレンダーにハイライト表示
      aiSuggestion.suggested_times.forEach(time => {
        this.highlightOptimalSlot(time)
      })
      
      // ダッシュボードに通知
      if (this.dashboardSocket && this.dashboardSocket.readyState === WebSocket.OPEN) {
        this.dashboardSocket.send(JSON.stringify({
          type: 'ai_optimization',
          data: aiSuggestion
        }))
      }
    }
  }

  // 最適なスロットをハイライト
  highlightOptimalSlot(timeSlot) {
    const slotElement = this.calendar.getEventById(timeSlot.id)
    if (slotElement) {
      slotElement.setProp('backgroundColor', '#10B981')
      slotElement.setProp('borderColor', '#059669')
      slotElement.setProp('classNames', ['ai-optimal-slot'])
    }
  }
}