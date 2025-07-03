// 🔄 WebSocket リアルタイムシステム
// worker5の革新的実装と連携

class RealtimeSystem {
  constructor() {
    this.socket = null;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
    this.reconnectDelay = 3000;
    this.qualityMetrics = {
      latency: [],
      messageCount: 0,
      errorCount: 0,
      uptime: Date.now()
    };
    
    this.init();
  }

  init() {
    console.log('🚀 リアルタイムシステム初期化開始');
    this.connect();
    this.setupQualityMonitoring();
  }

  connect() {
    try {
      // WebSocket接続（本番環境では適切なURLに変更）
      const wsUrl = window.location.protocol === 'https:' 
        ? `wss://${window.location.host}/ws` 
        : `ws://${window.location.host}/ws`;
      
      this.socket = new WebSocket(wsUrl);
      
      this.socket.onopen = () => this.handleOpen();
      this.socket.onmessage = (event) => this.handleMessage(event);
      this.socket.onclose = () => this.handleClose();
      this.socket.onerror = (error) => this.handleError(error);
      
    } catch (error) {
      console.error('WebSocket接続エラー:', error);
      this.handleReconnect();
    }
  }

  handleOpen() {
    console.log('✅ WebSocket接続成功');
    this.reconnectAttempts = 0;
    
    // 接続成功通知
    this.showNotification('リアルタイム接続確立', 'success');
    
    // 初期同期
    this.sendMessage({
      type: 'sync',
      timestamp: Date.now()
    });
    
    // 品質メトリクス更新
    this.updateQualityMetrics('connection', 'success');
  }

  handleMessage(event) {
    const startTime = performance.now();
    
    try {
      const data = JSON.parse(event.data);
      console.log('📨 メッセージ受信:', data);
      
      // メッセージタイプ別処理
      switch (data.type) {
        case 'appointment_update':
          this.handleAppointmentUpdate(data);
          break;
          
        case 'patient_update':
          this.handlePatientUpdate(data);
          break;
          
        case 'notification':
          this.handleNotification(data);
          break;
          
        case 'calendar_sync':
          this.handleCalendarSync(data);
          break;
          
        case 'quality_check':
          this.handleQualityCheck(data);
          break;
          
        default:
          console.warn('未知のメッセージタイプ:', data.type);
      }
      
      // レイテンシ測定
      const latency = performance.now() - startTime;
      this.qualityMetrics.latency.push(latency);
      this.qualityMetrics.messageCount++;
      
    } catch (error) {
      console.error('メッセージ処理エラー:', error);
      this.qualityMetrics.errorCount++;
    }
  }

  handleAppointmentUpdate(data) {
    // 予約更新のリアルタイム反映
    const { appointmentId, status, changes } = data.payload;
    
    // カレンダー更新
    if (window.calendar) {
      const event = window.calendar.getEventById(appointmentId);
      if (event) {
        Object.keys(changes).forEach(key => {
          event.setProp(key, changes[key]);
        });
      }
    }
    
    // UI更新
    this.updateAppointmentUI(appointmentId, changes);
    
    // 通知表示
    this.showNotification(
      `予約 #${appointmentId} が更新されました`,
      'info'
    );
  }

  handlePatientUpdate(data) {
    // 患者情報のリアルタイム更新
    const { patientId, changes } = data.payload;
    
    // DOM更新
    const patientElements = document.querySelectorAll(`[data-patient-id="${patientId}"]`);
    patientElements.forEach(element => {
      Object.keys(changes).forEach(key => {
        const targetElement = element.querySelector(`[data-field="${key}"]`);
        if (targetElement) {
          targetElement.textContent = changes[key];
        }
      });
    });
  }

  handleNotification(data) {
    // リアルタイム通知処理
    const { message, type, priority } = data.payload;
    
    this.showNotification(message, type, priority);
    
    // 高優先度通知の場合は音を鳴らす
    if (priority === 'high') {
      this.playNotificationSound();
    }
  }

  handleCalendarSync(data) {
    // カレンダーの完全同期
    const { events } = data.payload;
    
    if (window.calendar) {
      // 既存イベントクリア
      window.calendar.removeAllEvents();
      
      // 新イベント追加
      window.calendar.addEventSource(events);
      
      console.log('📅 カレンダー同期完了:', events.length, '件');
    }
  }

  handleQualityCheck(data) {
    // 品質保証システムとの連携
    const { metrics } = data.payload;
    
    console.log('🛡️ 品質チェック受信:', metrics);
    
    // メトリクス表示更新
    this.updateQualityDisplay(metrics);
    
    // 品質基準未達の場合はアラート
    if (metrics.score < 95) {
      this.showNotification(
        `品質スコア低下: ${metrics.score}%`,
        'warning',
        'high'
      );
    }
  }

  handleClose() {
    console.log('🔌 WebSocket接続終了');
    this.showNotification('リアルタイム接続が切断されました', 'warning');
    this.handleReconnect();
  }

  handleError(error) {
    console.error('❌ WebSocketエラー:', error);
    this.qualityMetrics.errorCount++;
  }

  handleReconnect() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      console.log(`🔄 再接続試行 ${this.reconnectAttempts}/${this.maxReconnectAttempts}`);
      
      setTimeout(() => {
        this.connect();
      }, this.reconnectDelay);
    } else {
      console.error('❌ 再接続失敗: 最大試行回数到達');
      this.showNotification('リアルタイム接続を確立できません', 'danger');
    }
  }

  sendMessage(message) {
    if (this.socket && this.socket.readyState === WebSocket.OPEN) {
      this.socket.send(JSON.stringify({
        ...message,
        timestamp: Date.now(),
        clientId: this.getClientId()
      }));
    } else {
      console.warn('WebSocket未接続: メッセージ送信失敗');
    }
  }

  // 品質監視システム
  setupQualityMonitoring() {
    // 5秒ごとに品質メトリクスを計算・送信
    setInterval(() => {
      const avgLatency = this.calculateAverageLatency();
      const errorRate = this.calculateErrorRate();
      const uptime = this.calculateUptime();
      
      const qualityReport = {
        type: 'quality_report',
        metrics: {
          avgLatency,
          errorRate,
          uptime,
          messageCount: this.qualityMetrics.messageCount,
          timestamp: Date.now()
        }
      };
      
      // サーバーに品質レポート送信
      this.sendMessage(qualityReport);
      
      // ローカル表示更新
      this.updateLocalQualityDisplay(qualityReport.metrics);
      
    }, 5000);
  }

  calculateAverageLatency() {
    const latencies = this.qualityMetrics.latency;
    if (latencies.length === 0) return 0;
    
    const sum = latencies.reduce((a, b) => a + b, 0);
    const avg = sum / latencies.length;
    
    // 直近100件のみ保持
    if (latencies.length > 100) {
      this.qualityMetrics.latency = latencies.slice(-100);
    }
    
    return Math.round(avg * 100) / 100;
  }

  calculateErrorRate() {
    const total = this.qualityMetrics.messageCount + this.qualityMetrics.errorCount;
    if (total === 0) return 0;
    
    return Math.round((this.qualityMetrics.errorCount / total) * 10000) / 100;
  }

  calculateUptime() {
    const uptimeMs = Date.now() - this.qualityMetrics.uptime;
    return Math.floor(uptimeMs / 1000); // 秒単位
  }

  // UI更新メソッド
  updateAppointmentUI(appointmentId, changes) {
    const appointmentRow = document.querySelector(`tr[data-appointment-id="${appointmentId}"]`);
    if (appointmentRow) {
      // アニメーション効果
      appointmentRow.classList.add('highlight-update');
      setTimeout(() => {
        appointmentRow.classList.remove('highlight-update');
      }, 2000);
      
      // データ更新
      Object.keys(changes).forEach(key => {
        const cell = appointmentRow.querySelector(`td[data-field="${key}"]`);
        if (cell) {
          cell.textContent = changes[key];
        }
      });
    }
  }

  showNotification(message, type = 'info', priority = 'normal') {
    // 既存の通知システムと連携
    const notification = document.createElement('div');
    notification.className = `notification ${type} fade-in`;
    notification.innerHTML = `
      <i class="bi bi-${this.getIconForType(type)} me-2"></i>
      ${message}
    `;
    
    const container = document.querySelector('.notification-container') || 
                     this.createNotificationContainer();
    
    container.appendChild(notification);
    
    // 自動削除
    setTimeout(() => {
      notification.style.opacity = '0';
      setTimeout(() => notification.remove(), 300);
    }, priority === 'high' ? 10000 : 5000);
  }

  createNotificationContainer() {
    const container = document.createElement('div');
    container.className = 'notification-container';
    container.style.cssText = `
      position: fixed;
      top: 80px;
      right: 20px;
      z-index: 9999;
      max-width: 400px;
    `;
    document.body.appendChild(container);
    return container;
  }

  getIconForType(type) {
    const icons = {
      'success': 'check-circle',
      'info': 'info-circle',
      'warning': 'exclamation-triangle',
      'danger': 'x-circle'
    };
    return icons[type] || 'info-circle';
  }

  playNotificationSound() {
    // 通知音再生（オプション）
    const audio = new Audio('/notification.mp3');
    audio.volume = 0.5;
    audio.play().catch(e => console.log('通知音再生エラー:', e));
  }

  updateQualityDisplay(metrics) {
    // 品質メトリクス表示更新
    const qualityWidget = document.getElementById('quality-widget');
    if (qualityWidget) {
      qualityWidget.innerHTML = `
        <div class="quality-metrics">
          <div class="metric">
            <span class="label">品質スコア</span>
            <span class="value ${metrics.score >= 95 ? 'good' : 'warning'}">${metrics.score}%</span>
          </div>
          <div class="metric">
            <span class="label">応答時間</span>
            <span class="value">${metrics.responseTime}ms</span>
          </div>
          <div class="metric">
            <span class="label">稼働率</span>
            <span class="value">${metrics.uptime}%</span>
          </div>
        </div>
      `;
    }
  }

  updateLocalQualityDisplay(metrics) {
    // ローカル品質表示
    console.log('📊 品質メトリクス:', {
      '平均レイテンシ': `${metrics.avgLatency}ms`,
      'エラー率': `${metrics.errorRate}%`,
      '稼働時間': `${metrics.uptime}秒`,
      'メッセージ数': metrics.messageCount
    });
  }

  getClientId() {
    // クライアント識別子（セッションストレージに保存）
    let clientId = sessionStorage.getItem('clientId');
    if (!clientId) {
      clientId = 'client_' + Math.random().toString(36).substr(2, 9);
      sessionStorage.setItem('clientId', clientId);
    }
    return clientId;
  }

  // 公開API
  disconnect() {
    if (this.socket) {
      this.socket.close();
    }
  }

  getMetrics() {
    return {
      ...this.qualityMetrics,
      avgLatency: this.calculateAverageLatency(),
      errorRate: this.calculateErrorRate(),
      uptime: this.calculateUptime()
    };
  }
}

// グローバルインスタンス作成
window.realtimeSystem = new RealtimeSystem();

// スタイル追加
const style = document.createElement('style');
style.textContent = `
  .highlight-update {
    animation: highlightPulse 2s ease-in-out;
  }
  
  @keyframes highlightPulse {
    0% { background-color: transparent; }
    50% { background-color: rgba(59, 130, 246, 0.2); }
    100% { background-color: transparent; }
  }
  
  .quality-metrics {
    display: flex;
    gap: 20px;
    padding: 10px;
    background: #f8f9fa;
    border-radius: 8px;
  }
  
  .quality-metrics .metric {
    text-align: center;
  }
  
  .quality-metrics .label {
    display: block;
    font-size: 12px;
    color: #666;
  }
  
  .quality-metrics .value {
    display: block;
    font-size: 24px;
    font-weight: bold;
    margin-top: 5px;
  }
  
  .quality-metrics .value.good {
    color: #10b981;
  }
  
  .quality-metrics .value.warning {
    color: #f59e0b;
  }
`;
document.head.appendChild(style);

console.log('✨ WebSocketリアルタイムシステム起動完了');