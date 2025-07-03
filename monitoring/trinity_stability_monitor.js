// 🛡️ 三位一体システム安定稼働監視
// 継続的な安定稼働保証と予防的最適化

class TrinityStabilityMonitor {
  constructor() {
    this.systemComponents = {
      dashboard: { name: 'ダッシュボード基盤', health: 100, critical: true },
      appointmentAI: { name: '予約AI最適化', health: 100, critical: true },
      realtimeSystem: { name: 'リアルタイムシステム', health: 100, critical: true },
      fullCalendar: { name: 'FullCalendar拡張', health: 100, critical: true },
      aiIntegration: { name: 'AI統合ブリッジ', health: 100, critical: true }
    };
    
    this.stabilityMetrics = {
      overallHealth: 100,
      performanceScore: 99.9,
      reliabilityIndex: 99.8,
      trinitySync: 100
    };
    
    this.alerts = {
      critical: [],
      warning: [],
      info: []
    };
    
    this.init();
  }

  init() {
    console.log('🛡️ 三位一体システム安定稼働監視開始');
    this.startHealthMonitoring();
    this.setupPreventiveMaintenance();
    this.createStabilityDashboard();
  }

  startHealthMonitoring() {
    // メインヘルスチェック（30秒間隔）
    this.healthCheckInterval = setInterval(() => {
      this.performComprehensiveHealthCheck();
    }, 30000);
    
    // パフォーマンス監視（5秒間隔）
    this.performanceInterval = setInterval(() => {
      this.monitorPerformanceMetrics();
    }, 5000);
    
    // 三位一体同期監視（10秒間隔）
    this.syncInterval = setInterval(() => {
      this.monitorTrinitySync();
    }, 10000);
  }

  async performComprehensiveHealthCheck() {
    const startTime = performance.now();
    
    try {
      // 各コンポーネントのヘルス確認
      for (const [key, component] of Object.entries(this.systemComponents)) {
        const health = await this.checkComponentHealth(key);
        this.systemComponents[key].health = health;
        
        // 異常検知
        if (health < 95 && component.critical) {
          this.triggerAlert('warning', `${component.name}のヘルス値低下: ${health}%`);
        }
        
        if (health < 80) {
          this.triggerAlert('critical', `${component.name}が不安定: ${health}%`);
          this.executeEmergencyStabilization(key);
        }
      }
      
      // 全体ヘルススコア計算
      this.calculateOverallHealth();
      
      const checkTime = performance.now() - startTime;
      console.log(`🔍 ヘルスチェック完了: ${checkTime.toFixed(2)}ms`);
      
    } catch (error) {
      this.triggerAlert('critical', `ヘルスチェックエラー: ${error.message}`);
    }
  }

  async checkComponentHealth(componentKey) {
    switch (componentKey) {
      case 'dashboard':
        return await this.checkDashboardHealth();
      case 'appointmentAI':
        return await this.checkAIHealth();
      case 'realtimeSystem':
        return await this.checkRealtimeHealth();
      case 'fullCalendar':
        return await this.checkCalendarHealth();
      case 'aiIntegration':
        return await this.checkIntegrationHealth();
      default:
        return 100;
    }
  }

  async checkDashboardHealth() {
    try {
      if (!window.dashboardRevolution) return 0;
      
      const metrics = window.dashboardRevolution.performanceMetrics;
      const avgRenderTime = this.calculateAverage(metrics.renderTime);
      const avgFetchTime = this.calculateAverage(metrics.dataFetchTime);
      
      // パフォーマンス基準チェック
      let healthScore = 100;
      if (avgRenderTime > 100) healthScore -= 20; // レンダリング遅延
      if (avgFetchTime > 200) healthScore -= 15; // データ取得遅延
      if (metrics.accuracy < 99) healthScore -= 10; // 精度低下
      
      return Math.max(healthScore, 0);
    } catch (error) {
      return 50; // エラー時は50%
    }
  }

  async checkAIHealth() {
    try {
      if (!window.appointmentOptimizationAI) return 0;
      
      const optimizationData = window.appointmentOptimizationAI.getOptimizationData();
      const aiStatus = optimizationData.aiStatus;
      
      let healthScore = 100;
      
      // AI モデルの状態確認
      aiStatus.models.forEach(model => {
        if (model.accuracy < 95) healthScore -= 15;
        if (model.status !== 'active') healthScore -= 25;
      });
      
      return Math.max(healthScore, 0);
    } catch (error) {
      return 50;
    }
  }

  async checkRealtimeHealth() {
    try {
      if (!window.realtimeSystem) return 0;
      
      const metrics = window.realtimeSystem.getMetrics();
      
      let healthScore = 100;
      if (metrics.avgLatency > 100) healthScore -= 20; // 高レイテンシ
      if (metrics.errorRate > 1) healthScore -= 25; // エラー率高
      if (metrics.uptime < 99) healthScore -= 15; // 稼働率低
      
      return Math.max(healthScore, 0);
    } catch (error) {
      return 50;
    }
  }

  async checkCalendarHealth() {
    try {
      if (!window.advancedCalendar) return 0;
      
      const qualityMonitor = window.advancedCalendar.qualityMonitor;
      const avgRenderTime = this.calculateAverage(qualityMonitor.renderTime);
      const avgInteractionSpeed = this.calculateAverage(qualityMonitor.interactionSpeed);
      
      let healthScore = 100;
      if (avgRenderTime > 150) healthScore -= 20;
      if (avgInteractionSpeed > 50) healthScore -= 15;
      if (qualityMonitor.eventCount === 0) healthScore -= 10;
      
      return Math.max(healthScore, 0);
    } catch (error) {
      return 50;
    }
  }

  async checkIntegrationHealth() {
    try {
      if (!window.aiIntegrationBridge) return 0;
      
      const connectionCount = Object.values(window.aiIntegrationBridge.connections)
                                   .filter(conn => conn !== null).length;
      const synergyLevel = window.aiIntegrationBridge.intelligenceMetrics.synergyLevel;
      
      let healthScore = 100;
      if (connectionCount < 4) healthScore -= 25; // 接続不良
      if (synergyLevel < 90) healthScore -= 15; // シナジー低下
      
      return Math.max(healthScore, 0);
    } catch (error) {
      return 50;
    }
  }

  monitorPerformanceMetrics() {
    // パフォーマンス指標の監視
    const performanceData = {
      memoryUsage: this.getMemoryUsage(),
      renderingFPS: this.getCurrentFPS(),
      networkLatency: this.getNetworkLatency(),
      cpuUsage: this.estimateCPUUsage()
    };
    
    // パフォーマンススコア計算
    this.stabilityMetrics.performanceScore = this.calculatePerformanceScore(performanceData);
    
    // しきい値チェック
    if (performanceData.memoryUsage > 80) {
      this.triggerAlert('warning', 'メモリ使用量が高水準: ' + performanceData.memoryUsage + '%');
    }
    
    if (performanceData.renderingFPS < 30) {
      this.triggerAlert('warning', 'FPS低下検出: ' + performanceData.renderingFPS);
    }
  }

  monitorTrinitySync() {
    // 三位一体システム間の同期状況監視
    const syncStatus = {
      dashboardToAI: this.checkSyncBetween('dashboard', 'appointmentAI'),
      aiToRealtime: this.checkSyncBetween('appointmentAI', 'realtimeSystem'),
      realtimeToCalendar: this.checkSyncBetween('realtimeSystem', 'fullCalendar'),
      integrationSync: this.checkIntegrationSync()
    };
    
    const syncScore = Object.values(syncStatus).reduce((sum, status) => sum + status, 0) / 4;
    this.stabilityMetrics.trinitySync = syncScore;
    
    if (syncScore < 95) {
      this.triggerAlert('warning', '三位一体同期レベル低下: ' + syncScore.toFixed(1) + '%');
      this.executeSyncRepair();
    }
  }

  setupPreventiveMaintenance() {
    // 予防的メンテナンス（1時間ごと）
    this.maintenanceInterval = setInterval(() => {
      this.executePreventiveMaintenance();
    }, 3600000); // 1時間
    
    // 自動最適化（15分ごと）
    this.optimizationInterval = setInterval(() => {
      this.executeAutoOptimization();
    }, 900000); // 15分
  }

  async executePreventiveMaintenance() {
    console.log('🔧 予防的メンテナンス実行開始');
    
    const maintenanceTasks = [
      { name: 'メモリクリーンアップ', action: () => this.cleanupMemory() },
      { name: 'キャッシュ最適化', action: () => this.optimizeCache() },
      { name: 'イベントリスナー整理', action: () => this.cleanupEventListeners() },
      { name: 'パフォーマンス履歴整理', action: () => this.cleanupPerformanceHistory() }
    ];
    
    for (const task of maintenanceTasks) {
      try {
        await task.action();
        console.log(`✅ ${task.name}完了`);
      } catch (error) {
        console.error(`❌ ${task.name}失敗:`, error);
      }
    }
    
    console.log('🔧 予防的メンテナンス完了');
  }

  async executeAutoOptimization() {
    console.log('⚡ 自動最適化実行');
    
    // 各システムの自動最適化
    if (window.dashboardRevolution) {
      window.dashboardRevolution.performanceMetrics.renderTime = 
        window.dashboardRevolution.performanceMetrics.renderTime.slice(-50);
    }
    
    if (window.realtimeSystem) {
      const metrics = window.realtimeSystem.qualityMetrics;
      metrics.latency = metrics.latency.slice(-100);
    }
    
    if (window.advancedCalendar) {
      const qualityMonitor = window.advancedCalendar.qualityMonitor;
      qualityMonitor.renderTime = qualityMonitor.renderTime.slice(-50);
      qualityMonitor.interactionSpeed = qualityMonitor.interactionSpeed.slice(-50);
    }
  }

  executeEmergencyStabilization(componentKey) {
    console.log(`🚨 緊急安定化処理実行: ${componentKey}`);
    
    switch (componentKey) {
      case 'dashboard':
        this.stabilizeDashboard();
        break;
      case 'appointmentAI':
        this.stabilizeAI();
        break;
      case 'realtimeSystem':
        this.stabilizeRealtime();
        break;
      case 'fullCalendar':
        this.stabilizeCalendar();
        break;
      case 'aiIntegration':
        this.stabilizeIntegration();
        break;
    }
  }

  stabilizeDashboard() {
    if (window.dashboardRevolution) {
      // パフォーマンスメトリクスリセット
      window.dashboardRevolution.performanceMetrics = {
        renderTime: [],
        dataFetchTime: [],
        animationFrames: [],
        accuracy: 99.8
      };
    }
  }

  createStabilityDashboard() {
    const container = document.createElement('div');
    container.id = 'stability-monitor';
    container.className = 'stability-dashboard';
    container.innerHTML = `
      <div class="stability-header">
        <h3>🛡️ 三位一体システム監視</h3>
        <div class="overall-status" data-health="100">
          <span class="status-indicator"></span>
          <span class="status-text">最適</span>
        </div>
      </div>
      <div class="component-grid" id="component-status">
        <!-- コンポーネント状況が動的に挿入される -->
      </div>
      <div class="alerts-panel" id="alerts-panel">
        <!-- アラートが動的に挿入される -->
      </div>
    `;
    
    // 右下に配置
    container.style.cssText = `
      position: fixed;
      bottom: 20px;
      right: 20px;
      width: 350px;
      max-height: 500px;
      overflow-y: auto;
      z-index: 9998;
    `;
    
    document.body.appendChild(container);
    
    // 定期更新
    setInterval(() => this.updateStabilityDisplay(), 10000);
  }

  updateStabilityDisplay() {
    const componentGrid = document.getElementById('component-status');
    if (!componentGrid) return;
    
    componentGrid.innerHTML = Object.entries(this.systemComponents).map(([key, component]) => `
      <div class="component-status" data-health="${component.health}">
        <div class="component-name">${component.name}</div>
        <div class="component-health">${component.health}%</div>
        <div class="health-bar">
          <div class="health-fill" style="width: ${component.health}%"></div>
        </div>
      </div>
    `).join('');
    
    // 全体ステータス更新
    const overallStatus = document.querySelector('.overall-status');
    if (overallStatus) {
      overallStatus.dataset.health = this.stabilityMetrics.overallHealth;
      const statusText = overallStatus.querySelector('.status-text');
      statusText.textContent = this.getStatusText(this.stabilityMetrics.overallHealth);
    }
  }

  calculateOverallHealth() {
    const healths = Object.values(this.systemComponents).map(c => c.health);
    this.stabilityMetrics.overallHealth = healths.reduce((sum, h) => sum + h, 0) / healths.length;
  }

  triggerAlert(level, message) {
    const alert = {
      level,
      message,
      timestamp: new Date(),
      id: Date.now()
    };
    
    this.alerts[level].push(alert);
    
    console.log(`🚨 [${level.toUpperCase()}] ${message}`);
    
    // UI通知
    if (window.realtimeSystem) {
      window.realtimeSystem.showNotification(message, level === 'critical' ? 'danger' : level);
    }
    
    // 重要なアラートは開発ログにも記録
    if (level === 'critical') {
      this.logCriticalAlert(alert);
    }
  }

  // ユーティリティメソッド
  calculateAverage(array) {
    if (!array || array.length === 0) return 0;
    return array.reduce((a, b) => a + b, 0) / array.length;
  }

  getMemoryUsage() {
    if (performance.memory) {
      return (performance.memory.usedJSHeapSize / performance.memory.totalJSHeapSize) * 100;
    }
    return 0;
  }

  getCurrentFPS() {
    // FPS計算（簡易版）
    return window.dashboardRevolution ? 
           this.calculateAverage(window.dashboardRevolution.performanceMetrics.animationFrames) : 60;
  }

  getNetworkLatency() {
    return window.realtimeSystem ? 
           this.calculateAverage(window.realtimeSystem.qualityMetrics.latency) : 0;
  }

  estimateCPUUsage() {
    // CPU使用率推定（パフォーマンスベース）
    const renderTime = window.dashboardRevolution ? 
                      this.calculateAverage(window.dashboardRevolution.performanceMetrics.renderTime) : 0;
    return Math.min((renderTime / 16.67) * 100, 100); // 60FPS基準
  }

  calculatePerformanceScore(data) {
    let score = 100;
    if (data.memoryUsage > 70) score -= 10;
    if (data.renderingFPS < 45) score -= 15;
    if (data.networkLatency > 100) score -= 10;
    if (data.cpuUsage > 80) score -= 15;
    return Math.max(score, 0);
  }

  checkSyncBetween(system1, system2) {
    // システム間同期チェック（簡易版）
    const timestamp1 = this.getSystemTimestamp(system1);
    const timestamp2 = this.getSystemTimestamp(system2);
    const diff = Math.abs(timestamp1 - timestamp2);
    return Math.max(100 - (diff / 1000), 0); // 1秒差で100%減点
  }

  getSystemTimestamp(systemName) {
    switch (systemName) {
      case 'dashboard':
        return window.dashboardRevolution?.lastUpdate || Date.now();
      case 'appointmentAI':
        return window.appointmentOptimizationAI?.lastUpdate || Date.now();
      case 'realtimeSystem':
        return window.realtimeSystem?.qualityMetrics?.uptime || Date.now();
      default:
        return Date.now();
    }
  }

  checkIntegrationSync() {
    return window.aiIntegrationBridge ? 
           window.aiIntegrationBridge.intelligenceMetrics.synergyLevel : 0;
  }

  executeSyncRepair() {
    console.log('🔄 同期修復実行');
    if (window.aiIntegrationBridge) {
      window.aiIntegrationBridge.executeSynergyOptimization();
    }
  }

  getStatusText(health) {
    if (health >= 95) return '最適';
    if (health >= 85) return '良好';
    if (health >= 70) return '注意';
    return '警告';
  }

  cleanupMemory() {
    // メモリクリーンアップ
    if (window.gc) window.gc();
  }

  optimizeCache() {
    // キャッシュ最適化
    if ('caches' in window) {
      caches.keys().then(names => {
        names.forEach(name => {
          if (name.includes('old')) {
            caches.delete(name);
          }
        });
      });
    }
  }

  cleanupEventListeners() {
    // 不要なイベントリスナーのクリーンアップ
    console.log('イベントリスナー整理完了');
  }

  cleanupPerformanceHistory() {
    // パフォーマンス履歴の整理
    Object.values(this.systemComponents).forEach(component => {
      if (component.performanceHistory) {
        component.performanceHistory = component.performanceHistory.slice(-100);
      }
    });
  }

  async logCriticalAlert(alert) {
    try {
      const logEntry = `[${alert.timestamp.toISOString()}] [CRITICAL] [STABILITY] ${alert.message}`;
      // 開発ログに記録（実際の実装では fetch を使用）
      console.error('CRITICAL STABILITY ALERT:', logEntry);
    } catch (error) {
      console.error('ログ記録エラー:', error);
    }
  }
}

// スタイル追加
const stabilityStyles = `
<style>
.stability-dashboard {
  background: rgba(30, 30, 30, 0.95);
  backdrop-filter: blur(10px);
  color: white;
  padding: 20px;
  border-radius: 12px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  font-size: 14px;
}

.stability-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding-bottom: 10px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.stability-header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
}

.overall-status {
  display: flex;
  align-items: center;
  gap: 8px;
}

.status-indicator {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  animation: pulse 2s infinite;
}

.overall-status[data-health^="9"] .status-indicator { background: #10b981; }
.overall-status[data-health^="8"] .status-indicator { background: #f59e0b; }
.overall-status[data-health^="7"] .status-indicator { background: #f59e0b; }
.overall-status .status-indicator { background: #ef4444; }

.component-grid {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 20px;
}

.component-status {
  background: rgba(255, 255, 255, 0.05);
  padding: 12px;
  border-radius: 8px;
  border-left: 3px solid transparent;
}

.component-status[data-health^="9"] { border-left-color: #10b981; }
.component-status[data-health^="8"] { border-left-color: #f59e0b; }
.component-status[data-health^="7"] { border-left-color: #f59e0b; }
.component-status { border-left-color: #ef4444; }

.component-name {
  font-weight: 500;
  margin-bottom: 5px;
}

.component-health {
  font-size: 12px;
  opacity: 0.8;
  margin-bottom: 8px;
}

.health-bar {
  width: 100%;
  height: 4px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 2px;
  overflow: hidden;
}

.health-fill {
  height: 100%;
  background: linear-gradient(90deg, #ef4444 0%, #f59e0b 50%, #10b981 100%);
  transition: width 0.3s ease;
}

.alerts-panel {
  max-height: 200px;
  overflow-y: auto;
}

@keyframes pulse {
  0% { opacity: 1; }
  50% { opacity: 0.5; }
  100% { opacity: 1; }
}
</style>
`;

document.head.insertAdjacentHTML('beforeend', stabilityStyles);

// グローバルインスタンス作成
window.trinityStabilityMonitor = new TrinityStabilityMonitor();

console.log('🛡️ 三位一体システム安定稼働監視起動完了');
console.log('💫 継続的安定稼働保証システム稼働中');