// 🚀 リアルタイムダッシュボード高度機能
class AdvancedRealtimeDashboard {
  constructor() {
    this.updateInterval = 3000; // 3秒間隔に短縮
    this.websocket = null;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 5;
    this.isConnected = false;
    
    this.init();
  }

  init() {
    this.startRealTimeUpdates();
    this.initializeWebSocket();
    this.setupEventListeners();
    this.initializeNotifications();
    console.log('🚀 Advanced Realtime Dashboard initialized');
  }

  // WebSocket接続の初期化
  initializeWebSocket() {
    try {
      // 本番環境ではWebSocketサーバーのURLを使用
      const wsUrl = `ws://${window.location.host}/cable`;
      this.websocket = new WebSocket(wsUrl);
      
      this.websocket.onopen = () => {
        console.log('✅ WebSocket connected');
        this.isConnected = true;
        this.reconnectAttempts = 0;
        this.updateConnectionStatus(true);
      };
      
      this.websocket.onmessage = (event) => {
        this.handleWebSocketMessage(JSON.parse(event.data));
      };
      
      this.websocket.onclose = () => {
        console.log('❌ WebSocket disconnected');
        this.isConnected = false;
        this.updateConnectionStatus(false);
        this.attemptReconnect();
      };
      
      this.websocket.onerror = (error) => {
        console.error('🔥 WebSocket error:', error);
        this.updateConnectionStatus(false);
      };
    } catch (error) {
      console.log('📡 WebSocket not available, using polling mode');
      this.fallbackToPolling();
    }
  }

  // WebSocketメッセージハンドラー
  handleWebSocketMessage(data) {
    switch (data.type) {
      case 'kpi_update':
        this.updateKPIsFromWebSocket(data.payload);
        break;
      case 'new_activity':
        this.addActivityFromWebSocket(data.payload);
        break;
      case 'system_alert':
        this.showSystemAlert(data.payload);
        break;
      default:
        console.log('Unknown message type:', data.type);
    }
  }

  // リアルタイム更新開始
  startRealTimeUpdates() {
    setInterval(() => {
      this.updateTime();
      this.updateSystemMetrics();
      this.updateLastUpdateTime();
      
      // WebSocketが接続されていない場合のみポーリング
      if (!this.isConnected) {
        this.updateKPIs();
        this.updateActivityFeed();
      }
    }, this.updateInterval);
  }

  // 時刻更新
  updateTime() {
    const now = new Date();
    const timeElement = document.getElementById('realtime-time');
    const dateElement = document.getElementById('realtime-date');
    
    if (timeElement) {
      timeElement.textContent = now.toLocaleTimeString('ja-JP', { 
        hour: '2-digit', 
        minute: '2-digit',
        second: '2-digit'
      });
    }
    
    if (dateElement) {
      dateElement.textContent = now.toLocaleDateString('ja-JP', { 
        month: '2-digit', 
        day: '2-digit', 
        weekday: 'short' 
      });
    }
  }

  // KPI更新（ポーリング用）
  updateKPIs() {
    const updates = this.generateMockKPIData();
    this.applyKPIUpdates(updates);
  }

  // WebSocketからのKPI更新
  updateKPIsFromWebSocket(data) {
    this.applyKPIUpdates(data);
  }

  // KPI更新の適用
  applyKPIUpdates(updates) {
    Object.keys(updates).forEach(key => {
      const element = document.getElementById(key);
      if (element) {
        this.animateValueChange(element, updates[key]);
      }
    });
  }

  // 値変更アニメーション
  animateValueChange(element, newValue) {
    element.style.transform = 'scale(1.1)';
    element.style.transition = 'transform 0.3s ease';
    
    setTimeout(() => {
      element.textContent = newValue;
      element.style.transform = 'scale(1)';
    }, 150);
  }

  // システムメトリクス更新
  updateSystemMetrics() {
    const metrics = {
      'cpu-usage': `${Math.floor(Math.random() * 30 + 20)}%`,
      'memory-usage': `${Math.floor(Math.random() * 20 + 60)}%`,
      'response-time': `${Math.floor(Math.random() * 50 + 120)}`,
      'active-users-count': Math.floor(Math.random() * 5 + 6),
      'system-performance': `${(Math.random() * 2 + 98).toFixed(1)}%`
    };

    Object.keys(metrics).forEach(key => {
      const element = document.getElementById(key);
      if (element) {
        element.textContent = metrics[key];
      }
    });
  }

  // アクティビティフィード更新
  updateActivityFeed() {
    const activities = [
      { 
        icon: '👤', 
        message: '新規患者が登録されました', 
        patient: this.getRandomPatientName(), 
        type: 'success',
        importance: 'normal'
      },
      { 
        icon: '📅', 
        message: '予約が確定されました', 
        patient: this.getRandomPatientName(), 
        type: 'info',
        importance: 'normal'
      },
      { 
        icon: '✅', 
        message: '診療が完了しました', 
        patient: this.getRandomPatientName(), 
        type: 'success',
        importance: 'high'
      },
      { 
        icon: '📞', 
        message: 'リコール通知を送信', 
        patient: `${Math.floor(Math.random() * 20 + 10)}名の患者`, 
        type: 'warning',
        importance: 'normal'
      },
      { 
        icon: '💰', 
        message: '会計処理が完了', 
        patient: this.getRandomPatientName(), 
        type: 'success',
        importance: 'normal'
      },
      { 
        icon: '🚨', 
        message: 'システム最適化実行', 
        patient: 'システム管理者', 
        type: 'info',
        importance: 'high'
      }
    ];

    // 20%の確率で新しいアクティビティを追加
    if (Math.random() < 0.2) {
      const activity = activities[Math.floor(Math.random() * activities.length)];
      this.addActivityToFeed(activity);
    }
  }

  // アクティビティをフィードに追加
  addActivityToFeed(activity) {
    const feed = document.getElementById('realtime-activity-feed');
    if (!feed) return;

    const timestamp = new Date().toLocaleTimeString('ja-JP');
    const typeColors = {
      'success': 'green',
      'warning': 'yellow',
      'info': 'blue',
      'error': 'red'
    };

    const activityElement = document.createElement('div');
    activityElement.className = `flex items-start space-x-3 p-4 bg-${typeColors[activity.type]}-50 rounded-xl border-l-4 border-${typeColors[activity.type]}-400 transform transition-all duration-500 hover:scale-102`;
    
    activityElement.innerHTML = `
      <div class="text-2xl animate-bounce">${activity.icon}</div>
      <div class="flex-1">
        <div class="flex items-center justify-between">
          <p class="text-sm font-medium text-gray-900">${activity.message}</p>
          ${activity.importance === 'high' ? '<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">重要</span>' : ''}
        </div>
        <p class="text-xs text-gray-500 mt-1">${activity.patient} • ${timestamp}</p>
      </div>
    `;

    // 新しいアクティビティをフェードインで追加
    activityElement.style.opacity = '0';
    activityElement.style.transform = 'translateY(-20px)';
    feed.insertBefore(activityElement, feed.firstChild);
    
    setTimeout(() => {
      activityElement.style.opacity = '1';
      activityElement.style.transform = 'translateY(0)';
    }, 100);

    // 最大15件まで表示
    while (feed.children.length > 15) {
      const lastChild = feed.lastChild;
      lastChild.style.opacity = '0';
      setTimeout(() => {
        if (lastChild.parentNode) {
          lastChild.parentNode.removeChild(lastChild);
        }
      }, 300);
    }

    // 重要なアクティビティの場合は通知
    if (activity.importance === 'high') {
      this.showNotification(activity.message, activity.type);
    }
  }

  // WebSocketからのアクティビティ追加
  addActivityFromWebSocket(activity) {
    this.addActivityToFeed(activity);
  }

  // 最終更新時刻の更新
  updateLastUpdateTime() {
    const lastUpdateElement = document.getElementById('last-update-time');
    if (lastUpdateElement) {
      lastUpdateElement.textContent = new Date().toLocaleTimeString('ja-JP');
    }
  }

  // 接続状態の更新
  updateConnectionStatus(isConnected) {
    const statusElement = document.getElementById('connection-status');
    const textElement = document.getElementById('connection-text');
    
    if (statusElement && textElement) {
      if (isConnected) {
        statusElement.className = 'w-3 h-3 bg-green-500 rounded-full animate-pulse';
        textElement.textContent = 'LIVE';
        textElement.className = 'text-sm font-medium text-green-700';
      } else {
        statusElement.className = 'w-3 h-3 bg-red-500 rounded-full animate-pulse';
        textElement.textContent = 'OFFLINE';
        textElement.className = 'text-sm font-medium text-red-700';
      }
    }
  }

  // 再接続試行
  attemptReconnect() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      console.log(`🔄 Attempting to reconnect (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
      
      setTimeout(() => {
        this.initializeWebSocket();
      }, 5000 * this.reconnectAttempts); // 指数バックオフ
    } else {
      console.log('❌ Max reconnection attempts reached. Falling back to polling.');
      this.fallbackToPolling();
    }
  }

  // ポーリングモードにフォールバック
  fallbackToPolling() {
    console.log('📡 Using polling mode for updates');
    this.updateConnectionStatus(false);
  }

  // イベントリスナーの設定
  setupEventListeners() {
    // ページの可視性変更時の処理
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        console.log('📱 Page hidden, reducing update frequency');
        this.updateInterval = 10000; // 10秒に延長
      } else {
        console.log('📱 Page visible, restoring update frequency');
        this.updateInterval = 3000; // 3秒に復元
      }
    });

    // ウィンドウフォーカス時の処理
    window.addEventListener('focus', () => {
      console.log('🎯 Window focused, forcing immediate update');
      this.updateKPIs();
      this.updateSystemMetrics();
    });
  }

  // 通知機能の初期化
  initializeNotifications() {
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission();
    }
  }

  // 通知表示
  showNotification(message, type = 'info') {
    if ('Notification' in window && Notification.permission === 'granted') {
      const notification = new Notification('クリニック管理システム', {
        body: message,
        icon: '/favicon.ico',
        badge: '/favicon.ico'
      });

      setTimeout(() => {
        notification.close();
      }, 5000);
    }

    // インページ通知も表示
    this.showInPageNotification(message, type);
  }

  // ページ内通知
  showInPageNotification(message, type) {
    const notification = document.createElement('div');
    notification.className = `fixed top-4 right-4 z-50 p-4 bg-${type === 'success' ? 'green' : type === 'warning' ? 'yellow' : 'blue'}-100 border border-${type === 'success' ? 'green' : type === 'warning' ? 'yellow' : 'blue'}-200 rounded-lg shadow-lg transform transition-all duration-500`;
    notification.innerHTML = `
      <div class="flex items-center">
        <div class="text-lg mr-3">${type === 'success' ? '✅' : type === 'warning' ? '⚠️' : 'ℹ️'}</div>
        <p class="text-sm font-medium">${message}</p>
      </div>
    `;

    document.body.appendChild(notification);

    // フェードイン
    setTimeout(() => {
      notification.style.transform = 'translateX(0)';
    }, 100);

    // 5秒後にフェードアウト
    setTimeout(() => {
      notification.style.transform = 'translateX(400px)';
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification);
        }
      }, 500);
    }, 5000);
  }

  // システムアラート表示
  showSystemAlert(alert) {
    console.log('🚨 System Alert:', alert);
    this.showNotification(alert.message, alert.type);
  }

  // モックKPIデータ生成
  generateMockKPIData() {
    return {
      'realtime-bookings': Math.floor(Math.random() * 5 + 20),
      'realtime-checkins': Math.floor(Math.random() * 3 + 13),
      'realtime-revenue': `¥${Math.floor(Math.random() * 200 + 800)}K`,
      'booking-progress': `${Math.floor(Math.random() * 20 + 70)}%`,
      'revenue-progress': `${Math.floor(Math.random() * 15 + 80)}%`,
      'waiting-count': Math.floor(Math.random() * 5 + 1),
      'today-new-bookings': Math.floor(Math.random() * 3 + 6),
      'today-completed': Math.floor(Math.random() * 5 + 10),
      'today-cancelled': Math.floor(Math.random() * 2),
      'activity-score': Math.floor(Math.random() * 10 + 90)
    };
  }

  // ランダム患者名生成
  getRandomPatientName() {
    const names = [
      '田中太郎', '佐藤花子', '鈴木一郎', '高橋美咲', '渡辺健太',
      '山田由美', '中村翔太', '小林恵美', '加藤大輔', '吉田香織',
      '松本拓也', '井上真理', '木村雄介', '斎藤彩子', '清水和彦'
    ];
    return names[Math.floor(Math.random() * names.length)];
  }
}

// ページ読み込み完了後にリアルタイム機能を開始
document.addEventListener('DOMContentLoaded', () => {
  window.realtimeDashboard = new AdvancedRealtimeDashboard();
  console.log('🚀 Advanced Realtime Dashboard ready!');
});

// エクスポート（モジュール使用時）
if (typeof module !== 'undefined' && module.exports) {
  module.exports = AdvancedRealtimeDashboard;
}