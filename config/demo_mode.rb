# デモモード設定
class DemoMode
  class << self
    def enabled?
      Rails.env.development? || ENV['DEMO_MODE'] == 'true'
    end
    
    def demo_prefix
      'デモ'
    end
    
    def safe_for_operation?(model, operation)
      return true unless enabled?
      
      case model
      when Patient
        model.demo_data?
      when Appointment
        model.patient&.demo_data?
      when Reminder
        model.appointment&.patient&.demo_data?
      else
        true
      end
    end
  end
end