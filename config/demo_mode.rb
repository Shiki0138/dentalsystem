# 本番環境デモモード設定
# 歯科業界革命実現のための安全なデモ体験環境

module DemoMode
  class Configuration
    attr_accessor :enabled, :safety_mode, :demo_data_prefix, :feature_restrictions

    def initialize
      @enabled = ENV['DEMO_MODE'] == 'true'
      @safety_mode = true
      @demo_data_prefix = 'DEMO_'
      @feature_restrictions = {
        real_email_sending: false,
        real_sms_sending: false,
        real_line_messaging: false,
        payment_processing: false,
        external_api_calls: false,
        data_persistence: :limited,
        user_registration: :limited,
        max_appointments_per_day: 50,
        max_patients: 100,
        max_demo_duration_hours: 24
      }
    end

    def demo_mode?
      @enabled
    end

    def production_demo?
      Rails.env.production? && demo_mode?
    end

    def safe_for_demo?(action)
      return true unless demo_mode?
      
      case action
      when :send_real_email
        !@feature_restrictions[:real_email_sending]
      when :send_real_sms
        !@feature_restrictions[:real_sms_sending]
      when :line_messaging
        !@feature_restrictions[:real_line_messaging]
      when :payment_processing
        !@feature_restrictions[:payment_processing]
      when :external_api_calls
        !@feature_restrictions[:external_api_calls]
      else
        true
      end
    end

    def demo_data_limits
      {
        patients: @feature_restrictions[:max_patients],
        appointments_per_day: @feature_restrictions[:max_appointments_per_day],
        demo_duration_hours: @feature_restrictions[:max_demo_duration_hours]
      }
    end
  end

  # グローバル設定インスタンス
  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield(config)
  end

  # デモモード確認メソッド
  def self.enabled?
    config.demo_mode?
  end

  def self.production_demo?
    config.production_demo?
  end

  def self.safe_for_demo?(action)
    config.safe_for_demo?(action)
  end

  def self.demo_data_limits
    config.demo_data_limits
  end

  # デモ用データ識別メソッド
  def self.demo_prefix
    config.demo_data_prefix
  end

  def self.demo_patient_name(base_name)
    "#{demo_prefix}#{base_name}"
  end

  def self.demo_email(base_email)
    if base_email.include?('@')
      username, domain = base_email.split('@')
      "#{demo_prefix.downcase}#{username}@#{domain}"
    else
      "#{demo_prefix.downcase}#{base_email}@demo.example.com"
    end
  end

  def self.demo_phone(base_phone)
    # デモ用の無効な電話番号を生成
    "#{demo_prefix}#{base_phone.gsub(/[^\d]/, '')}"
  end

  # 安全性チェック
  def self.validate_demo_safety!
    return unless enabled?
    
    if Rails.env.production?
      raise "本番環境でのデモモードは DEMO_MODE=true かつ適切な制限設定が必要" unless production_demo?
    end
    
    # 重要な外部サービスの無効化確認
    {
      real_email_sending: 'メール送信',
      real_sms_sending: 'SMS送信', 
      real_line_messaging: 'LINE送信',
      payment_processing: '決済処理',
      external_api_calls: '外部API呼び出し'
    }.each do |restriction, description|
      if config.feature_restrictions[restriction]
        Rails.logger.warn "デモモード: #{description}が有効になっています - 安全性を確認してください"
      end
    end
  end

  # デモ用モック応答
  module MockResponses
    def self.email_delivery_success
      {
        success: true,
        message_id: "demo_email_#{SecureRandom.hex(8)}",
        status: 'delivered',
        demo_mode: true,
        timestamp: Time.current
      }
    end

    def self.sms_delivery_success
      {
        success: true,
        message_id: "demo_sms_#{SecureRandom.hex(8)}",
        status: 'delivered',
        demo_mode: true,
        timestamp: Time.current
      }
    end

    def self.line_message_success
      {
        success: true,
        message_id: "demo_line_#{SecureRandom.hex(8)}",
        status: 'delivered',
        demo_mode: true,
        timestamp: Time.current
      }
    end

    def self.payment_success(amount)
      {
        success: true,
        transaction_id: "demo_pay_#{SecureRandom.hex(8)}",
        amount: amount,
        status: 'completed',
        demo_mode: true,
        timestamp: Time.current
      }
    end

    def self.ai_optimization_result
      {
        success: true,
        suggested_times: [
          { time: '09:00', efficiency_score: 95.2 },
          { time: '14:30', efficiency_score: 92.8 },
          { time: '16:00', efficiency_score: 89.5 }
        ],
        optimization_score: 98.5,
        demo_mode: true,
        timestamp: Time.current
      }
    end
  end
end

# 初期化時の安全性チェック
DemoMode.validate_demo_safety! if Rails.env.production?