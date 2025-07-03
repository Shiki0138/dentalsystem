# 🎬 デモ専用コントローラー
class DemoController < ApplicationController
  include DemoEnvironment::Helpers
  
  before_action :ensure_production_environment
  before_action :set_demo_mode
  
  # デモダッシュボード
  def dashboard
    @demo_data = {
      patients: demo_data(:patients, :medium),
      appointments: demo_data(:appointments, :medium),
      recent_activities: demo_data(:activities, :small),
      kpis: demo_data(:kpis)
    }
    
    @performance_config = {
      update_interval: demo_update_interval,
      optimization_level: 'maximum',
      features: ['ai_integration', 'realtime_sync', 'predictive_analytics']
    }
    
    render 'dashboard/realtime_enhanced_demo'
  end
  
  # デモAPI - リアルタイムデータ
  def realtime_data
    render json: {
      timestamp: Time.current.iso8601,
      demo_mode: true,
      data: {
        kpis: demo_data(:kpis),
        activities: demo_data(:activities, :small).first(3),
        system_status: {
          status: 'optimal',
          performance: 99.2,
          ai_efficiency: 98.5,
          last_update: Time.current.strftime('%H:%M:%S')
        }
      }
    }
  end
  
  # デモAPI - AI予測データ
  def ai_predictions
    render json: {
      demo_mode: true,
      predictions: {
        booking_efficiency: (98.5 + rand(-0.5..0.5)).round(1),
        patient_flow: {
          next_hour: rand(3..8),
          peak_time: "#{rand(14..16)}:#{['00', '30'].sample}",
          optimal_slots: generate_optimal_slots
        },
        resource_optimization: {
          staff_allocation: 'optimal',
          room_utilization: (92 + rand(-2..3)).round(1),
          equipment_usage: (88 + rand(-3..5)).round(1)
        },
        risk_analysis: {
          cancellation_risk: generate_cancellation_risks,
          no_show_probability: (5.2 + rand(-1..1)).round(1),
          vip_patient_satisfaction: (4.8 + rand(-0.1..0.2)).round(1)
        }
      },
      accuracy: (94.2 + rand(-0.3..0.5)).round(1),
      confidence: (96.5 + rand(-1..1)).round(1)
    }
  end
  
  # デモAPI - システムパフォーマンス
  def system_performance
    render json: {
      demo_mode: true,
      performance: {
        response_time: rand(40..55),
        cpu_usage: rand(15..25),
        memory_usage: rand(45..60),
        database: {
          connections: "#{rand(6..12)}/50",
          query_time: rand(2..8),
          cache_hit_ratio: (97.5 + rand(-1..1)).round(1)
        },
        network: {
          latency: rand(10..25),
          bandwidth_usage: rand(20..40),
          packet_loss: (0.1 + rand(-0.05..0.05)).round(2)
        },
        ai_processing: {
          inference_time: rand(25..45),
          model_accuracy: (94.2 + rand(-0.3..0.5)).round(1),
          processing_queue: rand(0..3)
        }
      },
      status: 'excellent',
      uptime: '99.98%',
      last_restart: 7.days.ago.iso8601
    }
  end
  
  # デモ設定変更
  def update_settings
    permitted_params = params.permit(:update_interval, :performance_mode, :data_size)
    
    session[:demo_settings] = {
      update_interval: permitted_params[:update_interval]&.to_i || 2000,
      performance_mode: permitted_params[:performance_mode] || 'optimized',
      data_size: permitted_params[:data_size] || 'medium'
    }
    
    render json: {
      success: true,
      message: 'デモ設定を更新しました',
      settings: session[:demo_settings]
    }
  end
  
  # デモモード切り替え
  def toggle_mode
    if params[:mode] == 'production'
      redirect_to dashboard_path
    else
      redirect_to demo_dashboard_path(demo: 'true')
    end
  end
  
  # デモ統計情報
  def statistics
    render json: {
      demo_mode: true,
      statistics: {
        session_duration: calculate_session_duration,
        interactions: session[:demo_interactions] || 0,
        features_accessed: session[:demo_features] || [],
        performance_metrics: {
          average_response_time: "#{rand(40..55)}ms",
          data_updates: session[:demo_updates] || 0,
          ai_optimizations: rand(15..25)
        },
        user_engagement: {
          scroll_depth: "#{rand(70..95)}%",
          time_on_dashboard: "#{rand(2..8)}分",
          feature_usage: generate_feature_usage
        }
      }
    }
  end
  
  private
  
  def ensure_production_environment
    unless Rails.env.production?
      render json: { error: 'Demo mode is only available in production environment' }, status: :forbidden
    end
  end
  
  def set_demo_mode
    Rails.application.config.demo_environment.enable_demo_mode! if params[:demo] == 'true'
    
    # セッション追跡
    session[:demo_interactions] = (session[:demo_interactions] || 0) + 1
    session[:demo_start_time] ||= Time.current
    session[:demo_features] ||= []
    session[:demo_updates] = (session[:demo_updates] || 0) + 1
    
    # アクセスした機能を記録
    session[:demo_features] << action_name unless session[:demo_features].include?(action_name)
  end
  
  def generate_optimal_slots
    slots = []
    (9..17).each do |hour|
      ['00', '30'].each do |minute|
        efficiency = rand(75..98)
        slots << {
          time: "#{hour}:#{minute}",
          efficiency: efficiency,
          availability: efficiency > 90 ? 'optimal' : efficiency > 80 ? 'good' : 'fair'
        }
      end
    end
    slots.sample(5)
  end
  
  def generate_cancellation_risks
    patients = ['デモ太郎', 'デモ花子', 'デモ一郎', 'デモ美咲']
    patients.map do |patient|
      {
        patient_name: patient,
        risk_level: ['low', 'medium', 'high'].sample,
        probability: rand(5..25),
        factors: ['past_behavior', 'appointment_time', 'weather'].sample(2)
      }
    end
  end
  
  def generate_feature_usage
    features = %w[dashboard realtime_updates ai_predictions system_monitor patient_management]
    usage = {}
    features.each do |feature|
      usage[feature] = "#{rand(20..95)}%"
    end
    usage
  end
  
  def calculate_session_duration
    return 0 unless session[:demo_start_time]
    ((Time.current - session[:demo_start_time]) / 60).round(1) # 分単位
  end
end