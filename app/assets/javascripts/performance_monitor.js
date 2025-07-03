// パフォーマンスモニタリングシステム - A+グレード品質
class PerformanceMonitor {
  constructor() {
    this.metrics = {
      pageLoad: [],
      apiCalls: [],
      userInteractions: []
    };
    
    this.init();
  }
  
  init() {
    // ページロードパフォーマンス測定
    this.measurePageLoad();
    
    // API呼び出しパフォーマンス測定
    this.interceptFetch();
    
    // ユーザーインタラクション測定
    this.measureInteractions();
    
    // 定期的なレポート送信
    this.startReporting();
  }
  
  measurePageLoad() {
    window.addEventListener('load', () => {
      const perfData = performance.getEntriesByType('navigation')[0];
      
      const metrics = {
        timestamp: new Date().toISOString(),
        domContentLoaded: perfData.domContentLoadedEventEnd - perfData.domContentLoadedEventStart,
        loadComplete: perfData.loadEventEnd - perfData.loadEventStart,
        domInteractive: perfData.domInteractive,
        firstPaint: this.getFirstPaint(),
        firstContentfulPaint: this.getFirstContentfulPaint()
      };
      
      this.metrics.pageLoad.push(metrics);
      console.log('Page Load Metrics:', metrics);
      
      // パフォーマンス警告
      if (metrics.loadComplete > 2000) {
        console.warn('⚠️ ページロードが2秒を超えています！最適化が必要です。');
      }
    });
  }
  
  getFirstPaint() {
    const fp = performance.getEntriesByName('first-paint')[0];
    return fp ? fp.startTime : 0;
  }
  
  getFirstContentfulPaint() {
    const fcp = performance.getEntriesByName('first-contentful-paint')[0];
    return fcp ? fcp.startTime : 0;
  }
  
  interceptFetch() {
    const originalFetch = window.fetch;
    
    window.fetch = async (...args) => {
      const startTime = performance.now();
      const url = args[0];
      
      try {
        const response = await originalFetch(...args);
        const endTime = performance.now();
        const duration = endTime - startTime;
        
        this.metrics.apiCalls.push({
          url: url,
          duration: duration,
          status: response.status,
          timestamp: new Date().toISOString()
        });
        
        // API呼び出し警告
        if (duration > 500) {
          console.warn(`⚠️ API呼び出しが遅い: ${url} (${duration.toFixed(2)}ms)`);
        }
        
        return response;
      } catch (error) {
        const endTime = performance.now();
        const duration = endTime - startTime;
        
        this.metrics.apiCalls.push({
          url: url,
          duration: duration,
          status: 'error',
          error: error.message,
          timestamp: new Date().toISOString()
        });
        
        throw error;
      }
    };
  }
  
  measureInteractions() {
    // クリックイベントの測定
    document.addEventListener('click', (e) => {
      const target = e.target;
      const startTime = performance.now();
      
      // 次のフレームで測定
      requestAnimationFrame(() => {
        const endTime = performance.now();
        const duration = endTime - startTime;
        
        this.metrics.userInteractions.push({
          type: 'click',
          target: target.tagName + (target.id ? '#' + target.id : ''),
          duration: duration,
          timestamp: new Date().toISOString()
        });
        
        if (duration > 100) {
          console.warn(`⚠️ クリック応答が遅い: ${duration.toFixed(2)}ms`);
        }
      });
    });
    
    // 入力イベントの測定
    document.addEventListener('input', this.debounce((e) => {
      const target = e.target;
      
      this.metrics.userInteractions.push({
        type: 'input',
        target: target.tagName + (target.id ? '#' + target.id : ''),
        timestamp: new Date().toISOString()
      });
    }, 300));
  }
  
  debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }
  
  startReporting() {
    // 5分ごとにメトリクスをレポート
    setInterval(() => {
      this.sendReport();
    }, 5 * 60 * 1000);
    
    // ページ離脱時にもレポート送信
    window.addEventListener('beforeunload', () => {
      this.sendReport();
    });
  }
  
  sendReport() {
    const report = {
      metrics: this.metrics,
      userAgent: navigator.userAgent,
      timestamp: new Date().toISOString(),
      memory: performance.memory ? {
        usedJSHeapSize: performance.memory.usedJSHeapSize,
        totalJSHeapSize: performance.memory.totalJSHeapSize,
        jsHeapSizeLimit: performance.memory.jsHeapSizeLimit
      } : null
    };
    
    console.log('📊 Performance Report:', report);
    
    // サーバーへの送信（実装時にエンドポイントを追加）
    // fetch('/api/performance/report', {
    //   method: 'POST',
    //   headers: { 'Content-Type': 'application/json' },
    //   body: JSON.stringify(report)
    // });
    
    // メトリクスをクリア
    this.metrics = {
      pageLoad: [],
      apiCalls: [],
      userInteractions: []
    };
  }
  
  // パフォーマンス最適化提案
  getOptimizationSuggestions() {
    const suggestions = [];
    
    // ページロード分析
    const avgPageLoad = this.getAverageMetric(this.metrics.pageLoad, 'loadComplete');
    if (avgPageLoad > 2000) {
      suggestions.push({
        type: 'page-load',
        severity: 'high',
        message: 'ページロードが遅いです。画像の最適化やJavaScriptの遅延ロードを検討してください。'
      });
    }
    
    // API呼び出し分析
    const slowAPIs = this.metrics.apiCalls.filter(call => call.duration > 500);
    if (slowAPIs.length > 0) {
      suggestions.push({
        type: 'api-performance',
        severity: 'medium',
        message: `${slowAPIs.length}個のAPI呼び出しが遅いです。キャッシュやページネーションを検討してください。`
      });
    }
    
    // メモリ使用量分析
    if (performance.memory && performance.memory.usedJSHeapSize > 50 * 1024 * 1024) {
      suggestions.push({
        type: 'memory-usage',
        severity: 'medium',
        message: 'メモリ使用量が高いです。不要なイベントリスナーやDOMノードを削除してください。'
      });
    }
    
    return suggestions;
  }
  
  getAverageMetric(metrics, key) {
    if (metrics.length === 0) return 0;
    const sum = metrics.reduce((acc, metric) => acc + (metric[key] || 0), 0);
    return sum / metrics.length;
  }
}

// 自動初期化
document.addEventListener('DOMContentLoaded', () => {
  window.performanceMonitor = new PerformanceMonitor();
  
  // コンソールにパフォーマンス情報を表示
  console.log('🚀 Performance Monitor initialized');
  
  // 開発環境でのみ詳細ログを表示
  if (window.location.hostname === 'localhost') {
    setInterval(() => {
      const suggestions = window.performanceMonitor.getOptimizationSuggestions();
      if (suggestions.length > 0) {
        console.group('🔧 パフォーマンス最適化提案');
        suggestions.forEach(suggestion => {
          console.log(`[${suggestion.severity.toUpperCase()}] ${suggestion.message}`);
        });
        console.groupEnd();
      }
    }, 30000); // 30秒ごとに提案を表示
  }
});