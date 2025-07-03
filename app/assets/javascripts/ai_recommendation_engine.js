// AI予測・レコメンデーションエンジン - 患者管理革新
class AIRecommendationEngine {
  constructor() {
    this.patientData = [];
    this.appointmentHistory = [];
    this.predictions = {};
    this.recommendations = {};
    
    this.init();
  }
  
  init() {
    console.log('🤖 AI Recommendation Engine initialized');
    this.loadPatientData();
    this.startRealtimeAnalysis();
    this.setupUIIntegration();
  }
  
  // 患者データ読み込み
  async loadPatientData() {
    try {
      const response = await fetch('/api/patients/analytics');
      this.patientData = await response.json();
      this.analyzePatterns();
    } catch (error) {
      console.error('Failed to load patient data:', error);
    }
  }
  
  // パターン分析
  analyzePatterns() {
    this.patientData.forEach(patient => {
      // キャンセル傾向分析
      const cancelPattern = this.analyzeCancelPattern(patient);
      
      // 来院頻度分析
      const visitFrequency = this.analyzeVisitFrequency(patient);
      
      // 最適予約時間分析
      const optimalTime = this.analyzeOptimalTime(patient);
      
      // 治療完了率予測
      const completionRate = this.predictTreatmentCompletion(patient);
      
      this.predictions[patient.id] = {
        cancelRisk: cancelPattern.risk,
        nextVisitProbability: visitFrequency.probability,
        optimalAppointmentTime: optimalTime,
        treatmentCompletionRate: completionRate
      };
    });
  }
  
  // キャンセルパターン分析
  analyzeCancelPattern(patient) {
    const cancelHistory = patient.appointments.filter(a => a.status === 'cancelled');
    const totalAppointments = patient.appointments.length;
    
    if (totalAppointments === 0) return { risk: 0, factors: [] };
    
    const cancelRate = cancelHistory.length / totalAppointments;
    const factors = [];
    
    // 曜日別キャンセル率
    const dayOfWeekCancels = this.groupByDayOfWeek(cancelHistory);
    const riskDays = Object.entries(dayOfWeekCancels)
      .filter(([day, count]) => count > 2)
      .map(([day]) => day);
    
    if (riskDays.length > 0) {
      factors.push(`${riskDays.join('・')}のキャンセル傾向`);
    }
    
    // 時間帯別キャンセル率
    const timeSlotCancels = this.groupByTimeSlot(cancelHistory);
    const riskTimes = Object.entries(timeSlotCancels)
      .filter(([time, count]) => count > 2)
      .map(([time]) => time);
    
    if (riskTimes.length > 0) {
      factors.push(`${riskTimes.join('・')}の時間帯にキャンセル傾向`);
    }
    
    // リスクレベル計算
    let riskLevel = cancelRate * 100;
    if (cancelHistory.length > 0) {
      const recentCancels = cancelHistory.filter(a => 
        new Date(a.date) > new Date(Date.now() - 90 * 24 * 60 * 60 * 1000)
      );
      if (recentCancels.length > 2) {
        riskLevel *= 1.5; // 最近のキャンセルが多い場合はリスク上昇
      }
    }
    
    return {
      risk: Math.min(Math.round(riskLevel), 100),
      factors: factors,
      suggestion: this.generateCancelPreventionSuggestion(riskLevel, factors)
    };
  }
  
  // 来院頻度分析
  analyzeVisitFrequency(patient) {
    const visits = patient.appointments.filter(a => a.status === 'completed');
    if (visits.length < 2) return { probability: 50, nextVisitEstimate: null };
    
    // 来院間隔計算
    const intervals = [];
    for (let i = 1; i < visits.length; i++) {
      const days = Math.floor(
        (new Date(visits[i].date) - new Date(visits[i-1].date)) / (1000 * 60 * 60 * 24)
      );
      intervals.push(days);
    }
    
    const avgInterval = intervals.reduce((a, b) => a + b, 0) / intervals.length;
    const lastVisit = new Date(visits[visits.length - 1].date);
    const daysSinceLastVisit = Math.floor((Date.now() - lastVisit) / (1000 * 60 * 60 * 24));
    
    // 来院確率計算
    let probability = 100;
    if (daysSinceLastVisit > avgInterval * 0.8) {
      probability = Math.max(100 - (daysSinceLastVisit - avgInterval) * 2, 0);
    }
    
    // 次回来院予測日
    const nextVisitEstimate = new Date(lastVisit.getTime() + avgInterval * 24 * 60 * 60 * 1000);
    
    return {
      probability: Math.round(probability),
      nextVisitEstimate: nextVisitEstimate,
      avgIntervalDays: Math.round(avgInterval),
      daysSinceLastVisit: daysSinceLastVisit
    };
  }
  
  // 最適予約時間分析
  analyzeOptimalTime(patient) {
    const completedAppointments = patient.appointments.filter(a => a.status === 'completed');
    if (completedAppointments.length === 0) return { timeSlots: ['10:00', '14:00'] };
    
    // 時間帯別来院率
    const timeSlotSuccess = {};
    completedAppointments.forEach(appointment => {
      const hour = new Date(appointment.date).getHours();
      const timeSlot = `${hour}:00`;
      timeSlotSuccess[timeSlot] = (timeSlotSuccess[timeSlot] || 0) + 1;
    });
    
    // 上位時間帯を取得
    const optimalSlots = Object.entries(timeSlotSuccess)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 3)
      .map(([time]) => time);
    
    return {
      timeSlots: optimalSlots.length > 0 ? optimalSlots : ['10:00', '14:00', '16:00'],
      confidence: Math.min(completedAppointments.length * 10, 90)
    };
  }
  
  // 治療完了率予測
  predictTreatmentCompletion(patient) {
    const treatments = patient.treatments || [];
    if (treatments.length === 0) return 80; // デフォルト値
    
    const completedTreatments = treatments.filter(t => t.status === 'completed');
    const completionRate = (completedTreatments.length / treatments.length) * 100;
    
    // 年齢による補正
    const ageBonus = patient.age && patient.age > 50 ? 10 : 0;
    
    // 来院頻度による補正
    const regularVisitBonus = patient.isRegular ? 15 : 0;
    
    return Math.min(Math.round(completionRate + ageBonus + regularVisitBonus), 100);
  }
  
  // キャンセル防止提案生成
  generateCancelPreventionSuggestion(riskLevel, factors) {
    const suggestions = [];
    
    if (riskLevel > 30) {
      suggestions.push('前日リマインダーの送信を推奨');
    }
    
    if (riskLevel > 50) {
      suggestions.push('3日前と前日の2回リマインダー送信を推奨');
      suggestions.push('電話での確認を検討');
    }
    
    if (factors.includes('朝の時間帯')) {
      suggestions.push('午後の予約を提案することを推奨');
    }
    
    if (factors.includes('月曜日')) {
      suggestions.push('週中〜週末の予約を提案することを推奨');
    }
    
    return suggestions;
  }
  
  // リアルタイムレコメンデーション生成
  generateRecommendations(patientId) {
    const predictions = this.predictions[patientId];
    if (!predictions) return [];
    
    const recommendations = [];
    
    // キャンセルリスクが高い場合
    if (predictions.cancelRisk > 40) {
      recommendations.push({
        type: 'warning',
        icon: '⚠️',
        title: 'キャンセルリスク警告',
        message: `キャンセル確率: ${predictions.cancelRisk}%`,
        actions: predictions.cancelRisk > 60 ? 
          ['電話確認を推奨', '複数回リマインダー設定'] : 
          ['前日リマインダー設定']
      });
    }
    
    // 再来院が必要な場合
    if (predictions.nextVisitProbability < 50) {
      recommendations.push({
        type: 'action',
        icon: '📞',
        title: '再来院フォローアップ',
        message: '前回来院から期間が空いています',
        actions: ['リコール連絡', '健診案内送付']
      });
    }
    
    // 最適時間の提案
    if (predictions.optimalAppointmentTime.confidence > 70) {
      recommendations.push({
        type: 'info',
        icon: '⏰',
        title: '最適予約時間',
        message: `推奨時間帯: ${predictions.optimalAppointmentTime.timeSlots.join(', ')}`,
        actions: ['この時間帯で予約提案']
      });
    }
    
    return recommendations;
  }
  
  // UIへの統合
  setupUIIntegration() {
    // 患者詳細ページでのAI予測表示
    document.addEventListener('DOMContentLoaded', () => {
      const patientIdElement = document.querySelector('[data-patient-id]');
      if (patientIdElement) {
        const patientId = patientIdElement.dataset.patientId;
        this.displayPatientInsights(patientId);
      }
    });
    
    // 予約作成時の最適時間提案
    const appointmentForm = document.querySelector('#new_appointment');
    if (appointmentForm) {
      this.enhanceAppointmentForm(appointmentForm);
    }
  }
  
  // 患者インサイト表示
  displayPatientInsights(patientId) {
    const predictions = this.predictions[patientId];
    const recommendations = this.generateRecommendations(patientId);
    
    if (!predictions || recommendations.length === 0) return;
    
    const insightContainer = document.createElement('div');
    insightContainer.className = 'ai-insights-container';
    insightContainer.innerHTML = `
      <div class="ai-insights-header">
        <h3 class="text-lg font-semibold text-gray-900 flex items-center">
          <span class="text-2xl mr-2">🤖</span>
          AI分析レポート
        </h3>
      </div>
      <div class="ai-insights-content">
        ${recommendations.map(rec => `
          <div class="ai-recommendation ${rec.type}">
            <div class="rec-icon">${rec.icon}</div>
            <div class="rec-content">
              <h4 class="rec-title">${rec.title}</h4>
              <p class="rec-message">${rec.message}</p>
              <div class="rec-actions">
                ${rec.actions.map(action => `
                  <button class="rec-action-btn">${action}</button>
                `).join('')}
              </div>
            </div>
          </div>
        `).join('')}
      </div>
    `;
    
    // 既存の患者情報エリアに追加
    const patientInfoSection = document.querySelector('.patient-info-section');
    if (patientInfoSection) {
      patientInfoSection.appendChild(insightContainer);
    }
  }
  
  // 予約フォーム強化
  enhanceAppointmentForm(form) {
    const patientSelect = form.querySelector('#appointment_patient_id');
    const timeSelect = form.querySelector('#appointment_time');
    
    if (patientSelect && timeSelect) {
      patientSelect.addEventListener('change', (e) => {
        const patientId = e.target.value;
        if (patientId) {
          this.updateTimeRecommendations(patientId, timeSelect);
        }
      });
    }
  }
  
  // 時間推奨更新
  updateTimeRecommendations(patientId, timeSelect) {
    const predictions = this.predictions[patientId];
    if (!predictions || !predictions.optimalAppointmentTime) return;
    
    const optimalTimes = predictions.optimalAppointmentTime.timeSlots;
    
    // 推奨時間をハイライト
    Array.from(timeSelect.options).forEach(option => {
      const timeValue = option.value;
      if (optimalTimes.some(time => timeValue.includes(time))) {
        option.text = `${option.text} ⭐ おすすめ`;
        option.className = 'recommended-time';
      }
    });
  }
  
  // ヘルパー関数
  groupByDayOfWeek(appointments) {
    const days = ['日', '月', '火', '水', '木', '金', '土'];
    const grouped = {};
    
    appointments.forEach(appointment => {
      const day = days[new Date(appointment.date).getDay()];
      grouped[day] = (grouped[day] || 0) + 1;
    });
    
    return grouped;
  }
  
  groupByTimeSlot(appointments) {
    const grouped = {};
    
    appointments.forEach(appointment => {
      const hour = new Date(appointment.date).getHours();
      const slot = hour < 12 ? '午前' : hour < 17 ? '午後' : '夕方';
      grouped[slot] = (grouped[slot] || 0) + 1;
    });
    
    return grouped;
  }
  
  // リアルタイム分析開始
  startRealtimeAnalysis() {
    // 5分ごとに分析更新
    setInterval(() => {
      this.loadPatientData();
      console.log('🔄 AI predictions updated');
    }, 5 * 60 * 1000);
    
    // WebSocketでリアルタイム更新（実装時）
    // this.setupWebSocket();
  }
}

// スタイル定義
const aiStyles = `
<style>
  .ai-insights-container {
    @apply bg-gradient-to-r from-blue-50 to-purple-50 rounded-2xl p-6 mt-6 border border-blue-200;
  }
  
  .ai-insights-header {
    @apply mb-4 pb-4 border-b border-blue-200;
  }
  
  .ai-recommendation {
    @apply bg-white rounded-xl p-4 mb-3 shadow-sm border;
  }
  
  .ai-recommendation.warning {
    @apply border-yellow-200 bg-yellow-50;
  }
  
  .ai-recommendation.action {
    @apply border-blue-200 bg-blue-50;
  }
  
  .ai-recommendation.info {
    @apply border-gray-200;
  }
  
  .rec-icon {
    @apply text-2xl mb-2;
  }
  
  .rec-title {
    @apply font-semibold text-gray-900 mb-1;
  }
  
  .rec-message {
    @apply text-sm text-gray-600 mb-3;
  }
  
  .rec-actions {
    @apply flex gap-2;
  }
  
  .rec-action-btn {
    @apply px-3 py-1 text-xs font-medium rounded-lg bg-blue-600 text-white hover:bg-blue-700 transition-colors;
  }
  
  .recommended-time {
    @apply bg-yellow-100 font-semibold;
  }
</style>
`;

// スタイル注入
if (!document.getElementById('ai-recommendation-styles')) {
  const styleElement = document.createElement('div');
  styleElement.id = 'ai-recommendation-styles';
  styleElement.innerHTML = aiStyles;
  document.head.appendChild(styleElement);
}

// 自動初期化
document.addEventListener('DOMContentLoaded', () => {
  window.aiRecommendationEngine = new AIRecommendationEngine();
  console.log('🚀 AI Recommendation Engine ready');
});