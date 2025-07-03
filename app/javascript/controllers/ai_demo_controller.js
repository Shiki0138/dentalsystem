// AI予約最適化システム - デモモード対応版
// worker2 - デモ環境用のモックAIレスポンス実装

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    demoMode: Boolean,
    apiUrl: String
  }

  connect() {
    console.log('AI Demo Controller: デモモード =', this.demoModeValue)
    this.initializeAIDemo()
  }

  initializeAIDemo() {
    this.aiDemoEngine = {
      // デモ用のモック最適時間提案
      async suggestOptimalTime(patientId, treatmentType) {
        if (this.demoModeValue) {
          return this.generateMockOptimalTime(patientId, treatmentType)
        } else {
          return this.callRealAIAPI('/api/ai/suggest_appointment_time', { patient_id: patientId, treatment_type: treatmentType })
        }
      },

      // デモ用の競合予測
      async predictConflicts(appointmentData) {
        if (this.demoModeValue) {
          return this.generateMockConflictPrediction(appointmentData)
        } else {
          return this.callRealAIAPI('/api/ai/predict_conflicts', appointmentData)
        }
      },

      // デモ用の繰り返し予約最適化
      async optimizeRecurringAppointments(patientId, pattern) {
        if (this.demoModeValue) {
          return this.generateMockRecurringOptimization(patientId, pattern)
        } else {
          return this.callRealAIAPI('/api/ai/optimize_recurring', { patient_id: patientId, pattern: pattern })
        }
      }
    }
  }

  // デモ用モック関数群
  generateMockOptimalTime(patientId, treatmentType) {
    // デモ用の疑似AIレスポンス
    const demoTimes = [
      { 
        time: '2025-07-04T10:00:00',
        confidence: 0.95,
        reason: 'AI分析: 患者の過去の来院パターンから最適な時間帯です'
      },
      { 
        time: '2025-07-04T14:30:00',
        confidence: 0.88,
        reason: 'AI分析: クリニックの混雑度が低い時間帯で推奨です'
      },
      { 
        time: '2025-07-04T16:00:00',
        confidence: 0.82,
        reason: 'AI分析: 治療内容に適した時間配分が可能です'
      }
    ]

    return {
      success: true,
      suggested_times: demoTimes,
      ai_insight: `${treatmentType}の治療に最適化された時間を提案しました`,
      efficiency_score: 98.5,
      demo_mode: true
    }
  }

  generateMockConflictPrediction(appointmentData) {
    // デモ用の競合予測
    const conflictRisk = Math.random() * 0.3 // 0-30%の競合リスク

    return {
      success: true,
      conflict_probability: conflictRisk,
      risk_level: conflictRisk < 0.1 ? 'low' : conflictRisk < 0.2 ? 'medium' : 'high',
      suggested_alternatives: [
        {
          time: '2025-07-04T11:00:00',
          risk: 0.05,
          reason: 'AI分析: 最も安全な時間帯です'
        }
      ],
      ai_insight: '競合リスクを分析し、最適な代替案を提案しました',
      demo_mode: true
    }
  }

  generateMockRecurringOptimization(patientId, pattern) {
    // デモ用の繰り返し予約最適化
    const optimizedSchedule = []
    const startDate = new Date()
    
    for (let i = 0; i < 6; i++) {
      const date = new Date(startDate)
      date.setDate(date.getDate() + (i * 14)) // 2週間間隔
      
      optimizedSchedule.push({
        date: date.toISOString(),
        time: '10:00',
        confidence: 0.92 - (i * 0.02),
        reason: `AI最適化: パターン${pattern}に基づく最適配置`
      })
    }

    return {
      success: true,
      optimized_schedule: optimizedSchedule,
      pattern_efficiency: 94.2,
      ai_insight: '繰り返し予約を最適化し、94.2%の効率性を達成しました',
      demo_mode: true
    }
  }

  // 本番API呼び出し
  async callRealAIAPI(endpoint, data) {
    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify(data)
      })
      return await response.json()
    } catch (error) {
      console.error('AI API エラー:', error)
      return { success: false, error: error.message }
    }
  }

  // デモモード表示用のUI要素
  showDemoModeIndicator() {
    if (this.demoModeValue) {
      const indicator = document.createElement('div')
      indicator.className = 'fixed top-4 left-4 bg-orange-500 text-white px-4 py-2 rounded-lg shadow-lg z-50'
      indicator.innerHTML = `
        <div class="flex items-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
          <span class="font-medium">デモモード - AI機能体験版</span>
        </div>
      `
      document.body.appendChild(indicator)
    }
  }

  // デモ用の成功メトリクス表示
  displayDemoMetrics() {
    const metrics = {
      efficiency: '98.5%',
      response_time: '50ms',
      accuracy: '94.2%',
      user_satisfaction: '98%'
    }

    const metricsDisplay = document.createElement('div')
    metricsDisplay.className = 'fixed bottom-4 left-4 bg-white border-2 border-green-200 rounded-lg p-4 shadow-lg z-50'
    metricsDisplay.innerHTML = `
      <h3 class="font-bold text-green-800 mb-2">🤖 AI性能メトリクス (デモ)</h3>
      <div class="space-y-1 text-sm">
        <div>効率性: <span class="font-semibold text-green-600">${metrics.efficiency}</span></div>
        <div>応答時間: <span class="font-semibold text-green-600">${metrics.response_time}</span></div>
        <div>精度: <span class="font-semibold text-green-600">${metrics.accuracy}</span></div>
        <div>満足度: <span class="font-semibold text-green-600">${metrics.user_satisfaction}</span></div>
      </div>
    `
    
    document.body.appendChild(metricsDisplay)
    
    // 10秒後に自動で消去
    setTimeout(() => {
      metricsDisplay.remove()
    }, 10000)
  }
}