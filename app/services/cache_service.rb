class CacheService
  class << self
    # 患者検索結果のキャッシュ
    def patient_search(query, limit = 10)
      cache_key = "patient_search:#{Digest::MD5.hexdigest(query.to_s)}:#{limit}"
      
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        patients = Patient.search(query).limit(limit)
        patients.map do |patient|
          {
            id: patient.id,
            patient_number: patient.patient_number,
            name: patient.name,
            name_kana: patient.name_kana,
            phone: patient.phone,
            email: patient.email,
            last_visit: patient.appointments.visited.maximum(:appointment_date),
            appointments_count: patient.appointments.count,
            has_line: patient.line_user_id.present?
          }
        end
      end
    end
    
    # 空き枠のキャッシュ
    def available_slots(date, treatment_duration = 30)
      cache_key = "available_slots:#{date.strftime('%Y%m%d')}:#{treatment_duration}"
      
      Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
        calculate_available_slots(date, treatment_duration)
      end
    end
    
    # ダッシュボード統計のキャッシュ
    def dashboard_stats
      cache_key = "dashboard_stats:#{Date.current.strftime('%Y%m%d')}"
      
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        today_stats = Appointment.today.group(:status).count
        
        {
          today_total: today_stats.values.sum,
          today_completed: today_stats['visited'] || 0,
          today_cancelled: today_stats['cancelled'] || 0,
          upcoming_count: Appointment.upcoming.count,
          total_patients: Patient.kept.count,
          new_patients_this_month: Patient.kept
                                         .where(created_at: Date.current.beginning_of_month..Date.current.end_of_month)
                                         .count
        }
      end
    end
    
    # 予約関連キャッシュの無効化
    def invalidate_appointment_cache(appointment)
      date_key = appointment.appointment_date.strftime('%Y%m%d')
      
      # 空き枠キャッシュを無効化
      Rails.cache.delete_matched("available_slots:#{date_key}:*")
      
      # ダッシュボード統計キャッシュを無効化
      Rails.cache.delete_matched("dashboard_stats:*")
      
      Rails.logger.info "Cache invalidated for appointment #{appointment.id}"
    end
    
    # 患者関連キャッシュの無効化
    def invalidate_patient_cache(patient)
      # 患者検索キャッシュを無効化
      Rails.cache.delete_matched("patient_search:*")
      
      Rails.logger.info "Cache invalidated for patient #{patient.id}"
    end
    
    private
    
    def calculate_available_slots(date, treatment_duration)
      # 営業時間設定
      business_hours = {
        start_time: "09:00",
        end_time: "18:00",
        lunch_start: "12:00",
        lunch_end: "13:00",
        slot_duration: 30
      }
      
      # 既存の予約を取得
      existing_appointments = Appointment.where(appointment_date: date.beginning_of_day..date.end_of_day)
                                        .where.not(status: ['cancelled', 'no_show'])
      
      slots = []
      start_time = Time.zone.parse("#{date} #{business_hours[:start_time]}")
      end_time = Time.zone.parse("#{date} #{business_hours[:end_time]}")
      lunch_start = Time.zone.parse("#{date} #{business_hours[:lunch_start]}")
      lunch_end = Time.zone.parse("#{date} #{business_hours[:lunch_end]}")
      
      current_time = start_time
      slot_duration = business_hours[:slot_duration]
      
      while current_time < end_time
        slot_end_time = current_time + treatment_duration.minutes
        
        # 昼休み時間をスキップ
        if current_time >= lunch_start && current_time < lunch_end
          current_time = lunch_end
          next
        end
        
        # 営業時間を超える場合はスキップ
        break if slot_end_time > end_time
        
        # 既存予約との重複チェック
        is_available = !existing_appointments.any? do |apt|
          apt_start = apt.appointment_date
          apt_end = apt_start + (apt.treatment_duration || 30).minutes
          
          # 重複判定
          (current_time < apt_end && slot_end_time > apt_start)
        end
        
        if is_available
          slots << {
            time: current_time.strftime("%H:%M"),
            display_time: current_time.strftime("%H:%M") + " - " + slot_end_time.strftime("%H:%M"),
            datetime: current_time.iso8601,
            available: true
          }
        end
        
        current_time += slot_duration.minutes
      end
      
      slots
    end
  end
end