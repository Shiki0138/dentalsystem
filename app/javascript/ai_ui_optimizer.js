// 🤖✨ AI UI最適化システム - worker2との協調実装
class AIUIOptimizer {
  constructor() {
    this.aiActive = true;
    this.animationSpeed = 300;
    this.userPreferences = {};
    this.init();
  }

  init() {
    console.log('🤖 AI UI Optimizer initializing...');
    this.setupAIElements();
    this.initializeGestures();
    this.startIntelligentAssistant();
    this.setupAdaptiveUI();
  }

  // AI要素のセットアップ
  setupAIElements() {
    // AI提案カードのアニメーション
    document.querySelectorAll('.ai-suggestion-card').forEach(card => {
      card.addEventListener('mouseenter', () => this.animateAICard(card));
      card.addEventListener('click', () => this.executeAISuggestion(card));
    });

    // AI最適化ボタン
    const aiButtons = document.querySelectorAll('.ai-optimize-btn');
    aiButtons.forEach(btn => {
      this.addAIGlow(btn);
      btn.addEventListener('click', (e) => this.optimizeWithAI(e));
    });
  }

  // AIカードアニメーション
  animateAICard(card) {
    card.style.transform = 'translateY(-5px) scale(1.02)';
    card.style.boxShadow = '0 10px 30px rgba(99, 102, 241, 0.3)';
    
    // パーティクルエフェクト
    this.createAIParticles(card);
    
    // 振動フィードバック（モバイル）
    if ('vibrate' in navigator) {
      navigator.vibrate(10);
    }
  }

  // AIパーティクルエフェクト
  createAIParticles(element) {
    const particles = 5;
    const rect = element.getBoundingClientRect();
    
    for (let i = 0; i < particles; i++) {
      const particle = document.createElement('div');
      particle.className = 'ai-particle';
      particle.style.cssText = `
        position: fixed;
        width: 4px;
        height: 4px;
        background: linear-gradient(45deg, #6366f1, #8b5cf6);
        border-radius: 50%;
        pointer-events: none;
        z-index: 9999;
        left: ${rect.left + rect.width / 2}px;
        top: ${rect.top + rect.height / 2}px;
      `;
      
      document.body.appendChild(particle);
      
      // アニメーション
      const angle = (Math.PI * 2 * i) / particles;
      const distance = 50 + Math.random() * 50;
      
      particle.animate([
        { 
          transform: 'translate(0, 0) scale(1)',
          opacity: 1 
        },
        { 
          transform: `translate(${Math.cos(angle) * distance}px, ${Math.sin(angle) * distance}px) scale(0)`,
          opacity: 0 
        }
      ], {
        duration: 800,
        easing: 'cubic-bezier(0.4, 0, 0.2, 1)'
      }).onfinish = () => particle.remove();
    }
  }

  // AIグロー効果
  addAIGlow(element) {
    element.style.position = 'relative';
    element.style.overflow = 'hidden';
    
    const glow = document.createElement('div');
    glow.className = 'ai-glow';
    glow.style.cssText = `
      position: absolute;
      top: -2px;
      left: -2px;
      right: -2px;
      bottom: -2px;
      background: linear-gradient(45deg, #6366f1, #8b5cf6, #ec4899);
      border-radius: inherit;
      opacity: 0;
      z-index: -1;
      filter: blur(10px);
      transition: opacity 0.3s ease;
    `;
    
    element.appendChild(glow);
    
    // ホバー時のグロー
    element.addEventListener('mouseenter', () => {
      glow.style.opacity = '0.6';
    });
    
    element.addEventListener('mouseleave', () => {
      glow.style.opacity = '0';
    });
  }

  // ジェスチャー初期化
  initializeGestures() {
    // スワイプでAI提案を切り替え
    let touchStartX = 0;
    let touchEndX = 0;
    
    document.addEventListener('touchstart', (e) => {
      touchStartX = e.touches[0].clientX;
    });
    
    document.addEventListener('touchend', (e) => {
      touchEndX = e.changedTouches[0].clientX;
      this.handleSwipe();
    });
  }

  // スワイプハンドリング
  handleSwipe() {
    const swipeDistance = touchEndX - touchStartX;
    
    if (Math.abs(swipeDistance) > 50) {
      if (swipeDistance > 0) {
        this.showPreviousAISuggestion();
      } else {
        this.showNextAISuggestion();
      }
    }
  }

  // インテリジェントアシスタント開始
  startIntelligentAssistant() {
    // ユーザーの操作パターンを学習
    this.trackUserBehavior();
    
    // 最適なタイミングでヒントを表示
    setTimeout(() => {
      this.showAIHint('💡 ヒント: AIボタンをクリックすると自動最適化が始まります');
    }, 5000);
  }

  // ユーザー行動追跡
  trackUserBehavior() {
    document.addEventListener('click', (e) => {
      const element = e.target;
      const action = element.dataset.action;
      
      if (action) {
        this.recordUserAction(action);
        this.adaptUIBasedOnBehavior();
      }
    });
  }

  // UI適応システム
  setupAdaptiveUI() {
    // 画面サイズに応じた最適化
    this.optimizeForDevice();
    
    // ダークモード対応
    this.detectAndApplyTheme();
    
    // アクセシビリティ最適化
    this.enhanceAccessibility();
  }

  // デバイス最適化
  optimizeForDevice() {
    const isMobile = window.innerWidth < 768;
    
    if (isMobile) {
      // モバイル用最適化
      document.querySelectorAll('.ai-card').forEach(card => {
        card.classList.add('mobile-optimized');
      });
    }
  }

  // AI提案実行
  executeAISuggestion(card) {
    const suggestionId = card.dataset.suggestionId;
    const type = card.dataset.suggestionType;
    
    // 実行アニメーション
    this.showExecutionAnimation(card);
    
    // AI処理
    this.processAISuggestion(suggestionId, type).then(result => {
      this.showSuccessAnimation(card);
      this.updateUIWithResult(result);
    });
  }

  // 実行アニメーション
  showExecutionAnimation(element) {
    const loader = document.createElement('div');
    loader.className = 'ai-loader';
    loader.innerHTML = `
      <div class="ai-spinner"></div>
      <div class="ai-text">AI処理中...</div>
    `;
    
    element.appendChild(loader);
    
    // パルスアニメーション
    element.animate([
      { transform: 'scale(1)', opacity: 1 },
      { transform: 'scale(1.05)', opacity: 0.8 },
      { transform: 'scale(1)', opacity: 1 }
    ], {
      duration: 1000,
      iterations: Infinity
    });
  }

  // 成功アニメーション
  showSuccessAnimation(element) {
    const success = document.createElement('div');
    success.className = 'ai-success';
    success.innerHTML = '✅';
    success.style.cssText = `
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%) scale(0);
      font-size: 48px;
      z-index: 9999;
    `;
    
    element.appendChild(success);
    
    success.animate([
      { transform: 'translate(-50%, -50%) scale(0)', opacity: 0 },
      { transform: 'translate(-50%, -50%) scale(1.2)', opacity: 1 },
      { transform: 'translate(-50%, -50%) scale(1)', opacity: 1 }
    ], {
      duration: 600,
      easing: 'cubic-bezier(0.34, 1.56, 0.64, 1)'
    }).onfinish = () => {
      setTimeout(() => success.remove(), 1000);
    };
  }

  // AIヒント表示
  showAIHint(message) {
    const hint = document.createElement('div');
    hint.className = 'ai-hint';
    hint.innerHTML = `
      <div class="ai-hint-content">
        <span class="ai-hint-icon">🤖</span>
        <span class="ai-hint-text">${message}</span>
        <button class="ai-hint-close">✕</button>
      </div>
    `;
    
    hint.style.cssText = `
      position: fixed;
      bottom: 20px;
      right: 20px;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 16px 20px;
      border-radius: 12px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
      z-index: 9999;
      transform: translateY(100px);
      opacity: 0;
      transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
    `;
    
    document.body.appendChild(hint);
    
    // アニメーション表示
    requestAnimationFrame(() => {
      hint.style.transform = 'translateY(0)';
      hint.style.opacity = '1';
    });
    
    // 閉じるボタン
    hint.querySelector('.ai-hint-close').addEventListener('click', () => {
      hint.style.transform = 'translateY(100px)';
      hint.style.opacity = '0';
      setTimeout(() => hint.remove(), 300);
    });
    
    // 自動非表示
    setTimeout(() => {
      if (hint.parentNode) {
        hint.style.transform = 'translateY(100px)';
        hint.style.opacity = '0';
        setTimeout(() => hint.remove(), 300);
      }
    }, 5000);
  }

  // AI最適化実行
  async optimizeWithAI(event) {
    const button = event.target;
    const targetElement = button.dataset.target;
    
    // ローディング状態
    button.classList.add('ai-optimizing');
    button.textContent = 'AI最適化中...';
    
    try {
      // AI処理シミュレーション
      await this.simulateAIProcessing();
      
      // 最適化結果適用
      this.applyOptimization(targetElement);
      
      // 成功表示
      button.classList.remove('ai-optimizing');
      button.classList.add('ai-optimized');
      button.textContent = '最適化完了！';
      
      // 効果音
      this.playSuccessSound();
      
    } catch (error) {
      console.error('AI optimization failed:', error);
      button.classList.add('ai-error');
      button.textContent = 'エラー発生';
    }
  }

  // AI処理シミュレーション
  simulateAIProcessing() {
    return new Promise(resolve => {
      setTimeout(resolve, 1500);
    });
  }

  // 最適化適用
  applyOptimization(targetElement) {
    const elements = document.querySelectorAll(targetElement);
    
    elements.forEach((el, index) => {
      setTimeout(() => {
        el.classList.add('ai-optimized');
        el.style.animation = 'aiOptimizeGlow 0.6s ease-out';
      }, index * 100);
    });
  }

  // 成功音再生
  playSuccessSound() {
    const audio = new Audio('data:audio/wav;base64,UklGRigBAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQQBAACAhYmLjo+Rk5WXmZucnZ6foKGio6SlpqanqKmqq6yrq6yrq6yrq6yrq6yrq6yrq6yrq6yrq6yrrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysrKysq6yrq6yrq6yrq6yrq6yrq6yrq6yrq6yrrKuqqqmop6alpKOioJ+enZuZmJWTkY+Ni4mGg4B+e3l2c3FubGpoZWNhX11bWFZUUlBOTEpIRkRCQD48Ojg2NDIwLy0sKyopKCcmJSQjIiEgHx4dHBsaGRgXFhUUExIREA8ODQwLCgkIBwYFBAMCAQA=');
    audio.volume = 0.3;
    audio.play().catch(() => {});
  }

  // ユーザーアクション記録
  recordUserAction(action) {
    if (!this.userPreferences.actions) {
      this.userPreferences.actions = [];
    }
    
    this.userPreferences.actions.push({
      type: action,
      timestamp: Date.now()
    });
    
    // 最新の50アクションのみ保持
    if (this.userPreferences.actions.length > 50) {
      this.userPreferences.actions.shift();
    }
  }

  // 行動に基づくUI適応
  adaptUIBasedOnBehavior() {
    const actions = this.userPreferences.actions || [];
    const recentActions = actions.slice(-10);
    
    // よく使う機能を強調表示
    const actionCounts = {};
    recentActions.forEach(action => {
      actionCounts[action.type] = (actionCounts[action.type] || 0) + 1;
    });
    
    const mostUsed = Object.entries(actionCounts)
      .sort((a, b) => b[1] - a[1])[0];
    
    if (mostUsed && mostUsed[1] > 3) {
      this.highlightFeature(mostUsed[0]);
    }
  }

  // 機能ハイライト
  highlightFeature(feature) {
    const element = document.querySelector(`[data-feature="${feature}"]`);
    if (element) {
      element.classList.add('ai-highlighted');
      element.style.animation = 'aiPulse 2s ease-in-out infinite';
    }
  }

  // テーマ検出と適用
  detectAndApplyTheme() {
    const isDarkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;
    
    if (isDarkMode) {
      document.body.classList.add('ai-dark-theme');
    }
    
    // テーマ変更監視
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (e.matches) {
        document.body.classList.add('ai-dark-theme');
      } else {
        document.body.classList.remove('ai-dark-theme');
      }
    });
  }

  // アクセシビリティ強化
  enhanceAccessibility() {
    // キーボードナビゲーション
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        document.body.classList.add('keyboard-navigation');
      }
    });
    
    document.addEventListener('mousedown', () => {
      document.body.classList.remove('keyboard-navigation');
    });
    
    // ARIAラベル自動追加
    document.querySelectorAll('.ai-button').forEach(btn => {
      if (!btn.getAttribute('aria-label')) {
        btn.setAttribute('aria-label', btn.textContent || 'AI機能ボタン');
      }
    });
  }

  // AI提案処理
  async processAISuggestion(suggestionId, type) {
    // 実際のAI処理をシミュレート
    return new Promise(resolve => {
      setTimeout(() => {
        resolve({
          success: true,
          message: 'AI提案が正常に適用されました',
          improvements: {
            efficiency: '+23%',
            accuracy: '+15%',
            userSatisfaction: '+18%'
          }
        });
      }, 2000);
    });
  }

  // 結果でUIを更新
  updateUIWithResult(result) {
    if (result.success) {
      this.showResultNotification(result);
      this.updateMetrics(result.improvements);
    }
  }

  // 結果通知表示
  showResultNotification(result) {
    const notification = document.createElement('div');
    notification.className = 'ai-result-notification';
    notification.innerHTML = `
      <div class="ai-result-header">
        <span class="ai-result-icon">✨</span>
        <span class="ai-result-title">AI最適化完了</span>
      </div>
      <div class="ai-result-body">
        <p>${result.message}</p>
        <div class="ai-result-metrics">
          <div class="metric">
            <span class="metric-label">効率性</span>
            <span class="metric-value">${result.improvements.efficiency}</span>
          </div>
          <div class="metric">
            <span class="metric-label">精度</span>
            <span class="metric-value">${result.improvements.accuracy}</span>
          </div>
          <div class="metric">
            <span class="metric-label">満足度</span>
            <span class="metric-value">${result.improvements.userSatisfaction}</span>
          </div>
        </div>
      </div>
    `;
    
    // スタイル適用と表示
    this.displayNotification(notification);
  }

  // 通知表示
  displayNotification(notification) {
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: white;
      border-radius: 16px;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
      padding: 20px;
      z-index: 10000;
      transform: translateX(400px);
      transition: transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
    `;
    
    document.body.appendChild(notification);
    
    // スライドイン
    requestAnimationFrame(() => {
      notification.style.transform = 'translateX(0)';
    });
    
    // 自動削除
    setTimeout(() => {
      notification.style.transform = 'translateX(400px)';
      setTimeout(() => notification.remove(), 400);
    }, 5000);
  }
}

// グローバル初期化
window.AIUIOptimizer = AIUIOptimizer;

// ページロード時に初期化
document.addEventListener('DOMContentLoaded', () => {
  window.aiUIOptimizer = new AIUIOptimizer();
  console.log('🤖✨ AI UI Optimizer ready! Supporting worker2\'s AI implementation');
});

// CSS アニメーション定義
const style = document.createElement('style');
style.textContent = `
  @keyframes aiOptimizeGlow {
    0% { box-shadow: 0 0 0 rgba(99, 102, 241, 0); }
    50% { box-shadow: 0 0 20px rgba(99, 102, 241, 0.6); }
    100% { box-shadow: 0 0 0 rgba(99, 102, 241, 0); }
  }
  
  @keyframes aiPulse {
    0%, 100% { transform: scale(1); }
    50% { transform: scale(1.05); }
  }
  
  .ai-optimized {
    transition: all 0.3s ease;
  }
  
  .ai-highlighted {
    border: 2px solid #6366f1 !important;
  }
  
  .keyboard-navigation *:focus {
    outline: 3px solid #6366f1;
    outline-offset: 2px;
  }
  
  .ai-dark-theme {
    --ai-primary: #8b5cf6;
    --ai-secondary: #ec4899;
  }
  
  .ai-spinner {
    width: 20px;
    height: 20px;
    border: 2px solid rgba(99, 102, 241, 0.3);
    border-top-color: #6366f1;
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
  }
  
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
`;
document.head.appendChild(style);