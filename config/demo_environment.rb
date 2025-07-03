# 🎬 デモ環境専用設定ファイル
# 本番環境でのデモンストレーション用設定

module DemoEnvironment
  class Configuration
    attr_accessor :demo_mode_enabled, :sample_data_size, :update_interval, :performance_mode
    
    def initialize
      @demo_mode_enabled = false
      @sample_data_size = :medium  # :small, :medium, :large
      @update_interval = 2000      # ミリ秒
      @performance_mode = :optimized # :standard, :optimized, :maximum
    end
    
    def demo_mode?
      @demo_mode_enabled
    end
    
    def enable_demo_mode!
      @demo_mode_enabled = true
      configure_demo_settings
    end
    
    def disable_demo_mode!
      @demo_mode_enabled = false
    end
    
    private
    
    def configure_demo_settings
      case @performance_mode
      when :optimized
        @update_interval = 1500
        @sample_data_size = :medium
      when :maximum
        @update_interval = 1000
        @sample_data_size = :large
      else
        @update_interval = 2000
        @sample_data_size = :small
      end
    end
  end
  
  # サンプルデータ生成クラス
  class SampleDataGenerator
    class << self
      def generate_patients(size = :medium)
        count = data_size_to_count(size)
        
        (1..count).map do |i|
          {
            id: i,
            name: "デモ患者#{i}",
            name_kana: "デモカンジャ#{i}",
            phone: "090-0000-#{sprintf('%04d', i)}",
            email: "demo#{i}@example.com",
            birth_date: (20..80).to_a.sample.years.ago.to_date,
            gender: ['male', 'female'].sample,
            address: "東京都渋谷区デモ町#{i}-1-1",
            insurance_number: "00000#{sprintf('%07d', i)}",
            created_at: (1..30).to_a.sample.days.ago,
            last_visit: (1..7).to_a.sample.days.ago,
            visit_count: (1..20).to_a.sample,
            vip_status: i <= 3 ? true : false
          }
        end
      end
      
      def generate_appointments(size = :medium)
        count = data_size_to_count(size) * 2
        base_date = Date.current
        
        (1..count).map do |i|
          appointment_date = base_date + ((-7)..14).to_a.sample.days
          appointment_time = Time.zone.parse("#{appointment_date} #{(9..17).to_a.sample}:#{['00', '30'].sample}")
          
          {
            id: i,
            patient_id: (1..data_size_to_count(size)).to_a.sample,
            patient_name: "デモ患者#{(1..data_size_to_count(size)).to_a.sample}",
            appointment_datetime: appointment_time,
            treatment_type: ['検診', '治療', 'クリーニング', '相談', '緊急'].sample,
            duration_minutes: [30, 45, 60, 90].sample,
            status: ['scheduled', 'confirmed', 'completed', 'cancelled'].sample,
            notes: "デモ用の予約データです",
            created_at: (1..14).to_a.sample.days.ago,
            reminder_sent: [true, false].sample,
            ai_optimized: i % 3 == 0 ? true : false
          }
        end
      end
      
      def generate_activities(size = :medium)
        count = data_size_to_count(size) * 3
        
        activities = [
          { icon: '🤖', message: 'AI予約最適化完了', type: 'success' },
          { icon: '📊', message: '予測分析更新', type: 'info' },
          { icon: '⚡', message: 'リアルタイム同期完了', type: 'success' },
          { icon: '👤', message: 'VIP患者自動識別', type: 'warning' },
          { icon: '📅', message: 'AI最適予約提案', type: 'info' },
          { icon: '✨', message: 'システム自動最適化', type: 'success' },
          { icon: '🎯', message: 'KPI目標達成', type: 'success' },
          { icon: '🔄', message: 'worker2連携完了', type: 'info' },
          { icon: '📱', message: 'モバイル最適化完了', type: 'success' },
          { icon: '💫', message: 'パフォーマンス向上', type: 'info' }
        ]
        
        (1..count).map do |i|
          activity = activities.sample
          {
            id: i,
            icon: activity[:icon],
            message: activity[:message],
            detail: "詳細情報#{i}",
            type: activity[:type],
            timestamp: (0..120).to_a.sample.minutes.ago,
            priority: ['high', 'medium', 'low'].sample,
            source: 'demo_system'
          }
        end
      end
      
      def generate_kpis(demo_mode = true)
        if demo_mode
          current_time = Time.current
          minute = current_time.min
          
          {
            bookings_today: (28 + Math.sin(minute / 8.0) * 4).floor,
            checkins_today: (25 + Math.sin(minute / 6.0) * 3).floor,
            revenue_today: (1150 + Math.sin(minute / 12.0) * 150).round,
            system_performance: (99.2 + Math.sin(current_time.sec / 8.0) * 0.4).round(1),
            response_time: (43 + Math.sin(current_time.sec / 7.0) * 8).floor,
            ai_efficiency: (98.5 + Math.sin(minute / 10.0) * 0.4).round(1),
            active_users: (10 + Math.sin(minute / 5.0) * 3).floor,
            cpu_usage: (18 + Math.sin(minute / 6.0) * 8).floor,
            memory_usage: (52 + Math.sin(minute / 9.0) * 10).floor,
            db_connections: (6 + Math.sin(minute / 8.0) * 4).floor,
            booking_optimization: (98.5 + Math.sin(minute / 9.0) * 0.3).round(1),
            prediction_accuracy: (94.2 + Math.sin(minute / 11.0) * 0.5).round(1)
          }
        else
          {
            bookings_today: 23,
            checkins_today: 15,
            revenue_today: 847,
            system_performance: 98.7,
            response_time: 142,
            ai_efficiency: 94.0,
            active_users: 8,
            cpu_usage: 23,
            memory_usage: 67,
            db_connections: 12,
            booking_optimization: 87.2,
            prediction_accuracy: 89.1
          }
        end
      end
      
      private
      
      def data_size_to_count(size)
        case size
        when :small then 10
        when :medium then 25
        when :large then 50
        else 25
        end
      end
    end
  end
  
  # デモモードヘルパー
  module Helpers
    def demo_mode?
      Rails.env.production? && params[:demo] == 'true'
    end
    
    def demo_class
      demo_mode? ? 'demo-mode' : 'production-mode'
    end
    
    def demo_data(type, size = :medium)
      return nil unless demo_mode?
      
      case type
      when :patients
        DemoEnvironment::SampleDataGenerator.generate_patients(size)
      when :appointments
        DemoEnvironment::SampleDataGenerator.generate_appointments(size)
      when :activities
        DemoEnvironment::SampleDataGenerator.generate_activities(size)
      when :kpis
        DemoEnvironment::SampleDataGenerator.generate_kpis(true)
      end
    end
    
    def real_or_demo_data(real_data, demo_type, size = :medium)
      demo_mode? ? demo_data(demo_type, size) : real_data
    end
    
    def demo_update_interval
      demo_mode? ? 2000 : 5000
    end
    
    def demo_performance_class
      demo_mode? ? 'demo-optimized' : 'production-standard'
    end
  end
end

# Rails アプリケーションに組み込み
if defined?(Rails)
  Rails.application.config.demo_environment = DemoEnvironment::Configuration.new
  
  # ヘルパーをActionViewに追加
  ActionView::Base.include DemoEnvironment::Helpers if defined?(ActionView)
  
  # コントローラーにも追加
  ActionController::Base.include DemoEnvironment::Helpers if defined?(ActionController)
end