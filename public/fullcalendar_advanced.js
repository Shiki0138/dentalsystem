// 📅 FullCalendar高度拡張機能
// worker2の革新的実装支援 + 監視システム連携

class AdvancedCalendarSystem {
  constructor() {
    this.calendar = null;
    this.realtimeSync = null;
    this.qualityMonitor = {
      renderTime: [],
      eventCount: 0,
      interactionSpeed: [],
      lastUpdate: Date.now()
    };
    
    this.init();
  }

  init() {
    console.log('📅 FullCalendar高度拡張システム初期化');
    this.setupCalendar();
    this.connectRealtimeSystem();
    this.initializeAdvancedFeatures();
    this.setupQualityMonitoring();
  }

  setupCalendar() {
    const calendarEl = document.getElementById('calendar');
    if (!calendarEl) return;

    const startTime = performance.now();

    this.calendar = new FullCalendar.Calendar(calendarEl, {
      // 基本設定
      initialView: 'dayGridMonth',
      locale: 'ja',
      height: 'auto',
      
      // ヘッダーツールバー
      headerToolbar: {
        left: 'prev,next today',
        center: 'title',
        right: 'dayGridMonth,timeGridWeek,timeGridDay,listMonth'
      },
      
      // 高度な機能設定
      editable: true,
      droppable: true,
      selectable: true,
      selectMirror: true,
      eventResizableFromStart: true,
      
      // ビジネス時間設定
      businessHours: {
        daysOfWeek: [1, 2, 3, 4, 5, 6], // 月〜土
        startTime: '09:00',
        endTime: '18:00'
      },
      
      // イベント表示設定
      eventDisplay: 'block',
      eventMaxStack: 3,
      dayMaxEvents: true,
      
      // アニメーション設定
      eventAnimationDuration: 300,
      
      // イベントハンドラー
      dateClick: (info) => this.handleDateClick(info),
      select: (info) => this.handleSelect(info),
      eventClick: (info) => this.handleEventClick(info),
      eventDrop: (info) => this.handleEventDrop(info),
      eventResize: (info) => this.handleEventResize(info),
      eventMouseEnter: (info) => this.handleEventMouseEnter(info),
      eventMouseLeave: (info) => this.handleEventMouseLeave(info),
      
      // カスタムボタン
      customButtons: {
        addAppointment: {
          text: '+ 新規予約',
          click: () => this.showQuickAppointmentModal()
        },
        syncCalendar: {
          text: '🔄 同期',
          click: () => this.syncWithServer()
        },
        exportCalendar: {
          text: '📥 エクスポート',
          click: () => this.exportCalendar()
        }
      },
      
      // データソース
      events: '/appointments.json',
      
      // ローディングハンドラー
      loading: (isLoading) => {
        this.showLoadingIndicator(isLoading);
      }
    });

    this.calendar.render();
    
    // レンダリング時間記録
    const renderTime = performance.now() - startTime;
    this.qualityMonitor.renderTime.push(renderTime);
    console.log(`✅ カレンダーレンダリング完了: ${renderTime.toFixed(2)}ms`);
  }

  // 🚀 機能1: 高度な予約作成（30秒登録対応）
  handleDateClick(info) {
    const startTime = performance.now();
    
    this.showQuickAppointmentModal({
      start: info.date,
      allDay: info.allDay,
      view: info.view
    });
    
    // インタラクション速度記録
    const interactionTime = performance.now() - startTime;
    this.qualityMonitor.interactionSpeed.push(interactionTime);
  }

  handleSelect(info) {
    // 範囲選択による複数予約作成
    this.showBulkAppointmentModal({
      start: info.start,
      end: info.end,
      allDay: info.allDay
    });
  }

  // 🎯 機能2: リアルタイムドラッグ&ドロップ
  handleEventDrop(info) {
    const { event, delta, revert } = info;
    
    // 楽観的UI更新
    this.showNotification('予約時間を変更中...', 'info');
    
    // サーバー同期
    this.updateAppointment(event.id, {
      start: event.start,
      end: event.end
    }).then(response => {
      if (response.success) {
        this.showNotification('予約時間を変更しました', 'success');
        
        // リアルタイム通知
        if (window.realtimeSystem) {
          window.realtimeSystem.sendMessage({
            type: 'appointment_update',
            appointmentId: event.id,
            changes: {
              start: event.start,
              end: event.end
            }
          });
        }
      } else {
        revert();
        this.showNotification('変更に失敗しました', 'danger');
      }
    }).catch(error => {
      revert();
      this.showNotification('エラーが発生しました', 'danger');
    });
  }

  handleEventResize(info) {
    const { event, endDelta, revert } = info;
    
    this.updateAppointment(event.id, {
      duration: event.end - event.start
    }).then(response => {
      if (!response.success) {
        revert();
      }
    });
  }

  // 📊 機能3: 監視システム連携
  connectRealtimeSystem() {
    if (window.realtimeSystem) {
      // リアルタイムイベント購読
      window.realtimeSystem.socket.addEventListener('message', (event) => {
        const data = JSON.parse(event.data);
        
        if (data.type === 'calendar_update') {
          this.handleRealtimeUpdate(data.payload);
        }
      });
      
      console.log('✅ リアルタイムシステム連携完了');
    }
  }

  handleRealtimeUpdate(payload) {
    const { action, eventData } = payload;
    
    switch (action) {
      case 'add':
        this.calendar.addEvent(eventData);
        this.showNotification('新しい予約が追加されました', 'info');
        break;
        
      case 'update':
        const event = this.calendar.getEventById(eventData.id);
        if (event) {
          Object.keys(eventData).forEach(key => {
            if (key !== 'id') {
              event.setProp(key, eventData[key]);
            }
          });
        }
        break;
        
      case 'remove':
        const eventToRemove = this.calendar.getEventById(eventData.id);
        if (eventToRemove) {
          eventToRemove.remove();
          this.showNotification('予約がキャンセルされました', 'warning');
        }
        break;
    }
    
    this.qualityMonitor.lastUpdate = Date.now();
  }

  // 🎨 機能4: 高度なUI/UX機能
  initializeAdvancedFeatures() {
    // カラーコーディング
    this.setupColorCoding();
    
    // ツールチップ
    this.setupTooltips();
    
    // コンテキストメニュー
    this.setupContextMenu();
    
    // キーボードショートカット
    this.setupKeyboardShortcuts();
    
    // ドラッグ可能な外部イベント
    this.setupExternalEvents();
  }

  setupColorCoding() {
    // ステータス別カラーコード
    const statusColors = {
      'confirmed': '#3b82f6', // 青
      'pending': '#f59e0b',   // 黄
      'completed': '#10b981', // 緑
      'cancelled': '#ef4444', // 赤
      'no_show': '#6b7280'    // グレー
    };
    
    // イベントレンダリングフック
    this.calendar.setOption('eventDidMount', (info) => {
      const status = info.event.extendedProps.status;
      if (statusColors[status]) {
        info.el.style.backgroundColor = statusColors[status];
        info.el.style.borderColor = statusColors[status];
      }
      
      // 優先度表示
      if (info.event.extendedProps.priority === 'high') {
        info.el.classList.add('high-priority');
      }
    });
  }

  setupTooltips() {
    // Bootstrap Tooltipインテグレーション
    this.calendar.setOption('eventMouseEnter', (info) => {
      const event = info.event;
      const tooltip = `
        <div class="calendar-tooltip">
          <strong>${event.title}</strong><br>
          時間: ${event.start.toLocaleTimeString('ja-JP', {hour: '2-digit', minute: '2-digit'})}<br>
          患者: ${event.extendedProps.patientName || '未設定'}<br>
          状態: ${this.getStatusLabel(event.extendedProps.status)}
        </div>
      `;
      
      // Tooltipを表示
      this.showTooltip(info.el, tooltip);
    });
    
    this.calendar.setOption('eventMouseLeave', (info) => {
      this.hideTooltip();
    });
  }

  setupContextMenu() {
    // 右クリックメニュー
    document.addEventListener('contextmenu', (e) => {
      const eventEl = e.target.closest('.fc-event');
      if (eventEl) {
        e.preventDefault();
        this.showContextMenu(e, eventEl);
      }
    });
  }

  setupKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      // Ctrl/Cmd + N: 新規予約
      if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
        e.preventDefault();
        this.showQuickAppointmentModal();
      }
      
      // Ctrl/Cmd + R: リフレッシュ
      if ((e.ctrlKey || e.metaKey) && e.key === 'r') {
        e.preventDefault();
        this.syncWithServer();
      }
      
      // ESC: モーダルを閉じる
      if (e.key === 'Escape') {
        this.closeAllModals();
      }
    });
  }

  setupExternalEvents() {
    // ドラッグ可能な予約テンプレート
    const externalEventsEl = document.getElementById('external-events');
    if (!externalEventsEl) return;
    
    new FullCalendar.Draggable(externalEventsEl, {
      itemSelector: '.fc-event-template',
      eventData: (eventEl) => {
        return {
          title: eventEl.innerText,
          duration: eventEl.dataset.duration || '01:00',
          color: eventEl.dataset.color || '#3b82f6'
        };
      }
    });
  }

  // 📈 品質監視システム
  setupQualityMonitoring() {
    setInterval(() => {
      const metrics = {
        avgRenderTime: this.calculateAverage(this.qualityMonitor.renderTime),
        avgInteractionSpeed: this.calculateAverage(this.qualityMonitor.interactionSpeed),
        eventCount: this.calendar.getEvents().length,
        lastUpdateAge: Date.now() - this.qualityMonitor.lastUpdate
      };
      
      // 品質レポート送信
      if (window.realtimeSystem) {
        window.realtimeSystem.sendMessage({
          type: 'calendar_quality_report',
          metrics: metrics
        });
      }
      
      // パフォーマンス警告
      if (metrics.avgRenderTime > 100) {
        console.warn('⚠️ レンダリング性能低下:', metrics.avgRenderTime + 'ms');
      }
      
    }, 10000); // 10秒ごと
  }

  // ユーティリティメソッド
  showQuickAppointmentModal(options = {}) {
    // 30秒登録対応モーダル
    const modal = document.createElement('div');
    modal.className = 'modal fade show';
    modal.style.display = 'block';
    modal.innerHTML = `
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              <i class="bi bi-lightning-fill text-warning me-2"></i>
              30秒クイック予約
            </h5>
            <button type="button" class="btn-close" onclick="this.closest('.modal').remove()"></button>
          </div>
          <div class="modal-body">
            <form id="quick-appointment-form">
              <div class="mb-3">
                <label class="form-label">患者名</label>
                <input type="text" class="form-control" id="patient-name" autocomplete="off" required>
                <div id="patient-suggestions" class="suggestions-list"></div>
              </div>
              <div class="row">
                <div class="col-md-6 mb-3">
                  <label class="form-label">日付</label>
                  <input type="date" class="form-control" id="appointment-date" value="${options.start ? options.start.toISOString().split('T')[0] : ''}" required>
                </div>
                <div class="col-md-6 mb-3">
                  <label class="form-label">時間</label>
                  <select class="form-control" id="appointment-time" required>
                    ${this.generateTimeOptions()}
                  </select>
                </div>
              </div>
              <div class="mb-3">
                <label class="form-label">診療内容</label>
                <select class="form-control" id="treatment-type" required>
                  <option value="一般診療">一般診療</option>
                  <option value="検診">検診</option>
                  <option value="クリーニング">クリーニング</option>
                  <option value="治療">治療</option>
                  <option value="相談">相談</option>
                </select>
              </div>
            </form>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" onclick="this.closest('.modal').remove()">キャンセル</button>
            <button type="button" class="btn btn-primary" onclick="advancedCalendar.saveQuickAppointment()">
              <i class="bi bi-check-circle me-2"></i>
              予約登録
            </button>
          </div>
        </div>
      </div>
    `;
    
    document.body.appendChild(modal);
    
    // オートコンプリート設定
    this.setupPatientAutocomplete();
    
    // フォーカス
    document.getElementById('patient-name').focus();
  }

  setupPatientAutocomplete() {
    const input = document.getElementById('patient-name');
    const suggestions = document.getElementById('patient-suggestions');
    
    input.addEventListener('input', async (e) => {
      const query = e.target.value;
      if (query.length < 2) {
        suggestions.innerHTML = '';
        return;
      }
      
      // 患者検索API呼び出し
      const results = await this.searchPatients(query);
      
      suggestions.innerHTML = results.map(patient => `
        <div class="suggestion-item" onclick="advancedCalendar.selectPatient(${patient.id}, '${patient.name}')">
          <strong>${patient.name}</strong>
          <small class="text-muted ms-2">${patient.phone}</small>
        </div>
      `).join('');
    });
  }

  async searchPatients(query) {
    try {
      const response = await fetch(`/patients/search?q=${encodeURIComponent(query)}`);
      return await response.json();
    } catch (error) {
      console.error('患者検索エラー:', error);
      return [];
    }
  }

  selectPatient(id, name) {
    document.getElementById('patient-name').value = name;
    document.getElementById('patient-name').dataset.patientId = id;
    document.getElementById('patient-suggestions').innerHTML = '';
  }

  async saveQuickAppointment() {
    const form = document.getElementById('quick-appointment-form');
    if (!form.checkValidity()) {
      form.reportValidity();
      return;
    }
    
    const startTime = performance.now();
    
    const appointmentData = {
      patient_name: document.getElementById('patient-name').value,
      patient_id: document.getElementById('patient-name').dataset.patientId,
      date: document.getElementById('appointment-date').value,
      time: document.getElementById('appointment-time').value,
      treatment_type: document.getElementById('treatment-type').value
    };
    
    try {
      const response = await this.createAppointment(appointmentData);
      
      if (response.success) {
        // カレンダーに追加
        this.calendar.addEvent({
          id: response.appointment.id,
          title: appointmentData.patient_name,
          start: `${appointmentData.date}T${appointmentData.time}`,
          extendedProps: {
            patientName: appointmentData.patient_name,
            treatmentType: appointmentData.treatment_type,
            status: 'confirmed'
          }
        });
        
        // 登録時間計測
        const registrationTime = performance.now() - startTime;
        console.log(`✅ 予約登録完了: ${registrationTime.toFixed(0)}ms`);
        
        // 成功通知
        this.showNotification(
          `予約登録完了 (${(registrationTime / 1000).toFixed(1)}秒)`,
          'success'
        );
        
        // モーダルを閉じる
        document.querySelector('.modal').remove();
      }
    } catch (error) {
      console.error('予約登録エラー:', error);
      this.showNotification('予約登録に失敗しました', 'danger');
    }
  }

  async createAppointment(data) {
    const response = await fetch('/appointments', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ appointment: data })
    });
    
    return await response.json();
  }

  async updateAppointment(id, changes) {
    const response = await fetch(`/appointments/${id}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ appointment: changes })
    });
    
    return await response.json();
  }

  async syncWithServer() {
    this.showLoadingIndicator(true);
    
    try {
      const response = await fetch('/appointments.json?sync=true');
      const events = await response.json();
      
      // カレンダーリフレッシュ
      this.calendar.removeAllEvents();
      this.calendar.addEventSource(events);
      
      this.showNotification('カレンダーを同期しました', 'success');
    } catch (error) {
      console.error('同期エラー:', error);
      this.showNotification('同期に失敗しました', 'danger');
    } finally {
      this.showLoadingIndicator(false);
    }
  }

  exportCalendar() {
    // iCal形式でエクスポート
    const events = this.calendar.getEvents();
    let icalContent = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Dental Clinic//Calendar Export//JP
CALSCALE:GREGORIAN
METHOD:PUBLISH
`;

    events.forEach(event => {
      icalContent += `BEGIN:VEVENT
UID:${event.id}@dentalclinic.jp
DTSTART:${this.formatDateToICal(event.start)}
DTEND:${this.formatDateToICal(event.end || event.start)}
SUMMARY:${event.title}
DESCRIPTION:${event.extendedProps.treatmentType || ''}
STATUS:CONFIRMED
END:VEVENT
`;
    });

    icalContent += 'END:VCALENDAR';

    // ダウンロード
    const blob = new Blob([icalContent], { type: 'text/calendar' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `appointments_${new Date().toISOString().split('T')[0]}.ics`;
    a.click();
    URL.revokeObjectURL(url);
    
    this.showNotification('カレンダーをエクスポートしました', 'success');
  }

  formatDateToICal(date) {
    return date.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';
  }

  generateTimeOptions() {
    const options = [];
    for (let hour = 9; hour < 18; hour++) {
      for (let minute = 0; minute < 60; minute += 30) {
        const time = `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
        options.push(`<option value="${time}">${time}</option>`);
      }
    }
    return options.join('');
  }

  showNotification(message, type = 'info') {
    if (window.realtimeSystem) {
      window.realtimeSystem.showNotification(message, type);
    } else {
      console.log(`[${type.toUpperCase()}] ${message}`);
    }
  }

  showLoadingIndicator(show) {
    const indicator = document.getElementById('calendar-loading');
    if (indicator) {
      indicator.style.display = show ? 'block' : 'none';
    }
  }

  showTooltip(element, content) {
    const tooltip = document.createElement('div');
    tooltip.className = 'calendar-tooltip-popup';
    tooltip.innerHTML = content;
    
    const rect = element.getBoundingClientRect();
    tooltip.style.position = 'absolute';
    tooltip.style.left = rect.left + 'px';
    tooltip.style.top = (rect.bottom + 5) + 'px';
    tooltip.style.zIndex = '9999';
    
    document.body.appendChild(tooltip);
    this.currentTooltip = tooltip;
  }

  hideTooltip() {
    if (this.currentTooltip) {
      this.currentTooltip.remove();
      this.currentTooltip = null;
    }
  }

  showContextMenu(event, eventEl) {
    const menu = document.createElement('div');
    menu.className = 'context-menu';
    menu.innerHTML = `
      <div class="context-menu-item" onclick="advancedCalendar.editAppointment('${eventEl.dataset.eventId}')">
        <i class="bi bi-pencil me-2"></i>編集
      </div>
      <div class="context-menu-item" onclick="advancedCalendar.duplicateAppointment('${eventEl.dataset.eventId}')">
        <i class="bi bi-copy me-2"></i>複製
      </div>
      <div class="context-menu-item text-danger" onclick="advancedCalendar.cancelAppointment('${eventEl.dataset.eventId}')">
        <i class="bi bi-x-circle me-2"></i>キャンセル
      </div>
    `;
    
    menu.style.position = 'absolute';
    menu.style.left = event.pageX + 'px';
    menu.style.top = event.pageY + 'px';
    
    document.body.appendChild(menu);
    
    // クリックで閉じる
    document.addEventListener('click', () => menu.remove(), { once: true });
  }

  closeAllModals() {
    document.querySelectorAll('.modal').forEach(modal => modal.remove());
  }

  calculateAverage(array) {
    if (array.length === 0) return 0;
    const sum = array.reduce((a, b) => a + b, 0);
    return sum / array.length;
  }

  getStatusLabel(status) {
    const labels = {
      'confirmed': '確定',
      'pending': '保留',
      'completed': '完了',
      'cancelled': 'キャンセル',
      'no_show': '未来院'
    };
    return labels[status] || status;
  }
}

// スタイル追加
const styles = `
<style>
.high-priority {
  border: 2px solid #ef4444 !important;
  box-shadow: 0 0 10px rgba(239, 68, 68, 0.3);
}

.suggestions-list {
  position: absolute;
  background: white;
  border: 1px solid #ddd;
  border-radius: 4px;
  max-height: 200px;
  overflow-y: auto;
  z-index: 1000;
  width: 100%;
  box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

.suggestion-item {
  padding: 10px;
  cursor: pointer;
  border-bottom: 1px solid #f0f0f0;
}

.suggestion-item:hover {
  background: #f8f9fa;
}

.calendar-tooltip-popup {
  background: rgba(0, 0, 0, 0.9);
  color: white;
  padding: 10px;
  border-radius: 6px;
  font-size: 13px;
  max-width: 250px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.2);
}

.context-menu {
  background: white;
  border: 1px solid #ddd;
  border-radius: 6px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.1);
  padding: 5px 0;
  min-width: 150px;
  z-index: 10000;
}

.context-menu-item {
  padding: 8px 15px;
  cursor: pointer;
  font-size: 14px;
}

.context-menu-item:hover {
  background: #f8f9fa;
}

.fc-event-template {
  margin: 5px;
  padding: 8px;
  background: #3b82f6;
  color: white;
  border-radius: 4px;
  cursor: move;
  text-align: center;
}

#calendar-loading {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  background: rgba(255, 255, 255, 0.9);
  padding: 20px;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.1);
  display: none;
}
</style>
`;

document.head.insertAdjacentHTML('beforeend', styles);

// グローバルインスタンス作成
window.advancedCalendar = new AdvancedCalendarSystem();

console.log('✨ FullCalendar高度拡張システム起動完了');