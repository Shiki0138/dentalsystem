// 歯科医院予約管理システム - Turbo Calendar Controller
// Hotwire(Turbo/Stimulus)によるSPA並みUX実現
// リアルタイム更新・即座のフィードバック・オフライン対応

import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { 
    eventsUrl: String,
    createUrl: String,
    updateUrl: String,
    deleteUrl: String,
    websocketUrl: String
  }

  static targets = [
    "calendar", 
    "notification", 
    "loadingOverlay",
    "offlineIndicator",
    "syncIndicator"
  ]

  connect() {
    this.initializeTurboStreams()
    this.initializeWebSocket()
    this.initializeOfflineSupport()
    this.initializeOptimisticUpdates()
    this.setupKeyboardShortcuts()
    this.startPerformanceMonitoring()
  }

  disconnect() {
    this.cleanup()
  }

  // Turbo Streams初期化
  initializeTurboStreams() {
    // カスタムTurbo Stream アクション定義
    Turbo.StreamActions.calendar_update = function() {
      const calendarEl = document.getElementById('calendar')
      if (calendarEl && window.calendar) {
        window.calendar.refetchEvents()
        this.showSuccess('カレンダーが更新されました')
      }
    }

    Turbo.StreamActions.appointment_created = function() {
      this.hideCreateModal()
      this.showSuccess('予約が作成されました')
      this.refreshCalendar()
    }

    Turbo.StreamActions.appointment_updated = function() {
      this.hideEditModal()
      this.showSuccess('予約が更新されました')
      this.refreshCalendar()
    }

    Turbo.StreamActions.appointment_deleted = function() {
      this.hideDetailModal()
      this.showSuccess('予約が削除されました')
      this.refreshCalendar()
    }

    // リアルタイム通知
    Turbo.StreamActions.show_notification = function() {
      const message = this.getAttribute('data-message')
      const type = this.getAttribute('data-type') || 'info'
      this.showNotification(message, type)
    }
  }

  // WebSocket接続初期化
  initializeWebSocket() {
    if (!this.websocketUrlValue) return

    this.websocket = new WebSocket(this.websocketUrlValue)
    
    this.websocket.onopen = () => {
      console.log('WebSocket connected')
      this.updateConnectionStatus(true)
    }

    this.websocket.onmessage = (event) => {
      this.handleWebSocketMessage(JSON.parse(event.data))
    }

    this.websocket.onclose = () => {
      console.log('WebSocket disconnected')
      this.updateConnectionStatus(false)
      // 自動再接続
      setTimeout(() => this.initializeWebSocket(), 5000)
    }

    this.websocket.onerror = (error) => {
      console.error('WebSocket error:', error)
      this.updateConnectionStatus(false)
    }
  }

  // WebSocketメッセージ処理
  handleWebSocketMessage(data) {
    switch (data.type) {
      case 'appointment_created':
      case 'appointment_updated':
      case 'appointment_deleted':
        this.refreshCalendar()
        this.showNotification(data.message, 'info')
        break
        
      case 'reminder_sent':
        this.showNotification(`リマインダーが送信されました: ${data.patient_name}`, 'success')
        break
        
      case 'system_notification':
        this.showNotification(data.message, data.level || 'info')
        break
        
      case 'calendar_sync':
        this.syncCalendarData(data.events)
        break
    }
  }

  // オフライン対応初期化
  initializeOfflineSupport() {
    // オンライン/オフライン状態監視
    window.addEventListener('online', () => {
      this.updateOfflineStatus(false)
      this.syncPendingChanges()
    })

    window.addEventListener('offline', () => {
      this.updateOfflineStatus(true)
    })

    // ページ可視性変化時の同期
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden && navigator.onLine) {
        this.syncCalendarData()
      }
    })

    // 初期状態設定
    this.updateOfflineStatus(!navigator.onLine)
  }

  // 楽観的UI更新初期化
  initializeOptimisticUpdates() {
    this.pendingOperations = new Map()
    this.operationId = 0
  }

  // キーボードショートカット設定
  setupKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      // Ctrl/Cmd + N: 新規予約
      if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
        e.preventDefault()
        this.showCreateModal()
      }
      
      // Ctrl/Cmd + F: 検索
      if ((e.ctrlKey || e.metaKey) && e.key === 'f') {
        e.preventDefault()
        document.getElementById('patientSearch')?.focus()
      }
      
      // ESC: モーダル閉じる
      if (e.key === 'Escape') {
        this.closeAllModals()
      }
    })
  }

  // パフォーマンス監視開始
  startPerformanceMonitoring() {
    this.performanceMetrics = {
      calendarLoadTime: 0,
      lastUpdateTime: Date.now(),
      operationCount: 0
    }

    // 定期的にメトリクス送信
    this.metricsInterval = setInterval(() => {
      this.sendPerformanceMetrics()
    }, 30000) // 30秒間隔
  }

  // 楽観的予約作成
  async optimisticCreateAppointment(appointmentData) {
    const operationId = ++this.operationId
    
    try {
      // 即座にUI更新
      this.addOptimisticAppointment(appointmentData, operationId)
      this.showLoadingState('予約を作成中...')

      // サーバーに送信
      const response = await fetch(this.createUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCsrfToken(),
          'Accept': 'text/vnd.turbo-stream.html'
        },
        body: JSON.stringify({ appointment: appointmentData })
      })

      if (response.ok) {
        // Turbo Streamレスポンス処理
        const streamData = await response.text()
        Turbo.renderStreamMessage(streamData)
        
        this.confirmOptimisticOperation(operationId)
      } else {
        throw new Error(`Server error: ${response.status}`)
      }

    } catch (error) {
      console.error('Create appointment failed:', error)
      this.revertOptimisticOperation(operationId)
      this.showError('予約の作成に失敗しました')
      
      // オフライン時はローカルに保存
      if (!navigator.onLine) {
        this.saveToLocalStorage('pending_appointments', appointmentData)
        this.showInfo('オフラインのため、オンライン復帰時に同期されます')
      }
    } finally {
      this.hideLoadingState()
    }
  }

  // 楽観的予約更新
  async optimisticUpdateAppointment(appointmentId, updateData) {
    const operationId = ++this.operationId
    
    try {
      this.updateOptimisticAppointment(appointmentId, updateData, operationId)
      this.showLoadingState('予約を更新中...')

      const response = await fetch(`${this.updateUrlValue}/${appointmentId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCsrfToken(),
          'Accept': 'text/vnd.turbo-stream.html'
        },
        body: JSON.stringify({ appointment: updateData })
      })

      if (response.ok) {
        const streamData = await response.text()
        Turbo.renderStreamMessage(streamData)
        this.confirmOptimisticOperation(operationId)
      } else {
        throw new Error(`Server error: ${response.status}`)
      }

    } catch (error) {
      console.error('Update appointment failed:', error)
      this.revertOptimisticOperation(operationId)
      this.showError('予約の更新に失敗しました')
    } finally {
      this.hideLoadingState()
    }
  }

  // 楽観的予約削除
  async optimisticDeleteAppointment(appointmentId) {
    const operationId = ++this.operationId
    
    try {
      this.removeOptimisticAppointment(appointmentId, operationId)
      this.showLoadingState('予約を削除中...')

      const response = await fetch(`${this.deleteUrlValue}/${appointmentId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.getCsrfToken(),
          'Accept': 'text/vnd.turbo-stream.html'
        }
      })

      if (response.ok) {
        const streamData = await response.text()
        Turbo.renderStreamMessage(streamData)
        this.confirmOptimisticOperation(operationId)
      } else {
        throw new Error(`Server error: ${response.status}`)
      }

    } catch (error) {
      console.error('Delete appointment failed:', error)
      this.revertOptimisticOperation(operationId)
      this.showError('予約の削除に失敗しました')
    } finally {
      this.hideLoadingState()
    }
  }

  // ローディング状態表示
  showLoadingState(message = '処理中...') {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.textContent = message
      this.loadingOverlayTarget.classList.remove('hidden')
    }
  }

  hideLoadingState() {
    if (this.hasLoadingOverlayTarget) {
      this.loadingOverlayTarget.classList.add('hidden')
    }
  }

  // 通知システム
  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    const bgColor = this.getNotificationColor(type)
    
    notification.className = `fixed top-4 right-4 ${bgColor} text-white px-6 py-3 rounded-lg shadow-lg z-50 transform transition-all duration-300 ease-in-out translate-x-full`
    notification.innerHTML = `
      <div class="flex items-center">
        ${this.getNotificationIcon(type)}
        <span class="ml-2">${message}</span>
        <button class="ml-4 text-white hover:text-gray-200" onclick="this.parentElement.parentElement.remove()">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
    `
    
    document.body.appendChild(notification)
    
    // アニメーション表示
    requestAnimationFrame(() => {
      notification.style.transform = 'translateX(0)'
    })
    
    // 自動削除
    setTimeout(() => {
      notification.style.transform = 'translateX(100%)'
      setTimeout(() => notification.remove(), 300)
    }, 5000)
  }

  // 通知タイプ別カラー
  getNotificationColor(type) {
    switch (type) {
      case 'success': return 'bg-green-500'
      case 'error': return 'bg-red-500'
      case 'warning': return 'bg-yellow-500'
      default: return 'bg-blue-500'
    }
  }

  // 通知タイプ別アイコン
  getNotificationIcon(type) {
    const icons = {
      success: '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>',
      error: '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>',
      warning: '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path></svg>',
      info: '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>'
    }
    return icons[type] || icons.info
  }

  // 便利メソッド
  showSuccess(message) { this.showNotification(message, 'success') }
  showError(message) { this.showNotification(message, 'error') }
  showWarning(message) { this.showNotification(message, 'warning') }
  showInfo(message) { this.showNotification(message, 'info') }

  // オフライン状態更新
  updateOfflineStatus(isOffline) {
    if (this.hasOfflineIndicatorTarget) {
      if (isOffline) {
        this.offlineIndicatorTarget.classList.remove('hidden')
      } else {
        this.offlineIndicatorTarget.classList.add('hidden')
      }
    }
  }

  // 接続状態更新
  updateConnectionStatus(isConnected) {
    if (this.hasSyncIndicatorTarget) {
      const indicator = this.syncIndicatorTarget
      if (isConnected) {
        indicator.className = 'w-3 h-3 bg-green-400 rounded-full'
        indicator.title = 'リアルタイム同期中'
      } else {
        indicator.className = 'w-3 h-3 bg-red-400 rounded-full'
        indicator.title = '同期停止中'
      }
    }
  }

  // ローカルストレージ操作
  saveToLocalStorage(key, data) {
    try {
      const existing = JSON.parse(localStorage.getItem(key) || '[]')
      existing.push({ ...data, timestamp: Date.now() })
      localStorage.setItem(key, JSON.stringify(existing))
    } catch (error) {
      console.error('Failed to save to localStorage:', error)
    }
  }

  // 保留中の変更の同期
  async syncPendingChanges() {
    try {
      const pending = JSON.parse(localStorage.getItem('pending_appointments') || '[]')
      
      for (const appointment of pending) {
        await this.optimisticCreateAppointment(appointment)
      }
      
      localStorage.removeItem('pending_appointments')
      this.showSuccess('オフライン中の変更を同期しました')
      
    } catch (error) {
      console.error('Failed to sync pending changes:', error)
      this.showError('変更の同期に失敗しました')
    }
  }

  // CSRFトークン取得
  getCsrfToken() {
    return document.querySelector('[name="csrf-token"]')?.content
  }

  // パフォーマンスメトリクス送信
  sendPerformanceMetrics() {
    if (!navigator.onLine) return

    const metrics = {
      ...this.performanceMetrics,
      timestamp: Date.now(),
      user_agent: navigator.userAgent,
      page_url: window.location.href
    }

    fetch('/api/metrics', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCsrfToken()
      },
      body: JSON.stringify(metrics)
    }).catch(() => {
      // メトリクス送信失敗は無視
    })
  }

  // クリーンアップ
  cleanup() {
    if (this.websocket) {
      this.websocket.close()
    }
    
    if (this.metricsInterval) {
      clearInterval(this.metricsInterval)
    }
  }

  // 楽観的UI更新の実装
  addOptimisticAppointment(data, operationId) {
    this.pendingOperations.set(operationId, { type: 'create', data })
    // カレンダーに一時的にイベント追加
    if (window.calendar) {
      const tempEvent = {
        id: `temp-${operationId}`,
        title: `${data.patient_name} (処理中...)`,
        start: data.appointment_date,
        backgroundColor: '#9CA3AF',
        classNames: ['optimistic-event']
      }
      window.calendar.addEvent(tempEvent)
    }
  }

  confirmOptimisticOperation(operationId) {
    this.pendingOperations.delete(operationId)
    // 一時的なイベントを削除し、正式なイベントを表示
    if (window.calendar) {
      const tempEvent = window.calendar.getEventById(`temp-${operationId}`)
      if (tempEvent) tempEvent.remove()
    }
  }

  revertOptimisticOperation(operationId) {
    const operation = this.pendingOperations.get(operationId)
    if (operation && window.calendar) {
      const tempEvent = window.calendar.getEventById(`temp-${operationId}`)
      if (tempEvent) tempEvent.remove()
    }
    this.pendingOperations.delete(operationId)
  }
}