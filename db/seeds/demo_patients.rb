# 本番デモ用サンプルデータ - 患者管理機能テスト
class DemoPatients
  def self.create_sample_data
    puts "🦷 本番デモ用患者データ作成開始..."
    
    # 既存データクリア（デモ環境のみ）
    if Rails.env.development?
      Patient.delete_all
      Appointment.delete_all
      puts "📝 既存データをクリアしました"
    end
    
    # リアルな患者データ作成
    sample_patients = [
      {
        name: "田中 太郎", name_kana: "タナカ タロウ", 
        email: "tanaka@example.com", phone: "090-1234-5678",
        birth_date: 35.years.ago, address: "東京都渋谷区神南1-2-3",
        insurance_info: "社会保険", 
        profile: "定期的な検診を重視する会社員"
      },
      {
        name: "佐藤 花子", name_kana: "サトウ ハナコ", 
        email: "sato@example.com", phone: "080-2345-6789",
        birth_date: 28.years.ago, address: "東京都新宿区西新宿2-1-1",
        insurance_info: "国民健康保険",
        profile: "審美治療に関心の高いOL"
      },
      {
        name: "鈴木 一郎", name_kana: "スズキ イチロウ", 
        email: "suzuki@example.com", phone: "070-3456-7890",
        birth_date: 45.years.ago, address: "東京都港区赤坂1-1-1",
        insurance_info: "社会保険",
        profile: "多忙なビジネスマン、短時間治療希望"
      },
      {
        name: "高橋 美由紀", name_kana: "タカハシ ミユキ", 
        email: "takahashi@example.com", phone: "090-4567-8901",
        birth_date: 32.years.ago, address: "東京都品川区大崎2-1-1",
        insurance_info: "社会保険",
        profile: "子育て中の主婦、午前中の予約希望"
      },
      {
        name: "伊藤 健", name_kana: "イトウ ケン", 
        email: "ito@example.com", phone: "080-5678-9012",
        birth_date: 52.years.ago, address: "東京都中央区銀座4-5-6",
        insurance_info: "社会保険",
        profile: "歯周病治療中、定期メンテナンス重視"
      },
      {
        name: "山田 愛子", name_kana: "ヤマダ アイコ", 
        email: "yamada@example.com", phone: "070-6789-0123",
        birth_date: 26.years.ago, address: "東京都世田谷区三軒茶屋1-1-1",
        insurance_info: "国民健康保険",
        profile: "矯正治療中、月1回通院"
      },
      {
        name: "渡辺 博", name_kana: "ワタナベ ヒロシ", 
        email: "watanabe@example.com", phone: "090-7890-1234",
        birth_date: 61.years.ago, address: "東京都文京区本郷3-1-1",
        insurance_info: "後期高齢者医療",
        profile: "インプラント治療歴あり、定期チェック"
      },
      {
        name: "中村 真理", name_kana: "ナカムラ マリ", 
        email: "nakamura@example.com", phone: "080-8901-2345",
        birth_date: 39.years.ago, address: "東京都豊島区池袋2-2-2",
        insurance_info: "社会保険",
        profile: "歯科恐怖症、リラックス治療希望"
      },
      {
        name: "小林 大輔", name_kana: "コバヤシ ダイスケ", 
        email: "kobayashi@example.com", phone: "070-9012-3456",
        birth_date: 41.years.ago, address: "東京都墨田区錦糸町1-1-1",
        insurance_info: "社会保険",
        profile: "スポーツ選手、マウスガード作成"
      },
      {
        name: "加藤 さくら", name_kana: "カトウ サクラ", 
        email: "kato@example.com", phone: "090-0123-4567",
        birth_date: 23.years.ago, address: "東京都江東区有明1-1-1",
        insurance_info: "学生保険",
        profile: "大学生、ホワイトニング希望"
      }
    ]
    
    created_patients = []
    
    sample_patients.each_with_index do |patient_data, index|
      patient = Patient.create!(
        name: patient_data[:name],
        name_kana: patient_data[:name_kana],
        email: patient_data[:email],
        phone: patient_data[:phone],
        birth_date: patient_data[:birth_date],
        address: patient_data[:address],
        insurance_info: patient_data[:insurance_info],
        patient_number: sprintf("P%06d", 1000 + index),
        line_user_id: rand(2) == 0 ? "line_user_#{rand(100000)}" : nil
      )
      
      created_patients << patient
      puts "✅ 患者作成: #{patient.name} (#{patient.patient_number})"
      
      # 予約履歴作成（リアルなパターン）
      create_appointment_history(patient, patient_data[:profile])
    end
    
    puts "🎉 #{created_patients.count}名の患者データ作成完了！"
    
    # 統計情報表示
    display_demo_stats
    
    created_patients
  end
  
  private
  
  def self.create_appointment_history(patient, profile)
    # プロファイルに基づいたリアルな予約パターン
    appointments_count = case profile
    when /定期的/ then rand(8..15)
    when /多忙/ then rand(3..6)
    when /月1回/ then 6
    when /学生/ then rand(2..5)
    else rand(4..10)
    end
    
    base_date = 1.year.ago
    
    appointments_count.times do |i|
      # 間隔パターン（プロファイルに基づく）
      interval = case profile
      when /定期的/ then rand(60..90).days
      when /多忙/ then rand(120..180).days
      when /月1回/ then 30.days
      when /学生/ then rand(90..150).days
      else rand(45..120).days
      end
      
      appointment_date = base_date + (interval * i)
      
      # 時間帯の傾向
      hour = case profile
      when /主婦/ then [9, 10, 11].sample
      when /多忙/ then [18, 19, 20].sample
      when /会社員/ then [9, 10, 18, 19].sample
      else rand(9..18)
      end
      
      final_date = appointment_date.change(hour: hour, min: [0, 30].sample)
      
      # 過去の予約のみ作成（未来は除く）
      next if final_date > Time.current
      
      # ステータス決定（リアルなパターン）
      status = if i < appointments_count - 2
        ['completed', 'completed', 'completed', 'cancelled'].sample
      else
        ['completed', 'scheduled'].sample
      end
      
      # キャンセル傾向（プロファイルに基づく）
      if profile.include?('多忙') && rand(10) < 3
        status = 'cancelled'
      end
      
      treatment_types = [
        '一般診療', '定期検診', '歯石除去', 'フッ素塗布',
        'むし歯治療', '歯周病治療', 'ホワイトニング', 
        '矯正チェック', 'インプラント検診'
      ]
      
      treatment_type = case profile
      when /審美/ then ['ホワイトニング', '審美治療', '一般診療'].sample
      when /矯正/ then ['矯正チェック', '矯正調整', '定期検診'].sample
      when /歯周病/ then ['歯周病治療', '歯石除去', '定期検診'].sample
      when /インプラント/ then ['インプラント検診', 'インプラントメンテナンス'].sample
      else treatment_types.sample
      end
      
      appointment = Appointment.create!(
        patient: patient,
        appointment_date: final_date,
        treatment_type: treatment_type,
        status: status,
        notes: generate_realistic_notes(treatment_type, status),
        duration_minutes: [30, 45, 60, 90].sample
      )
      
      # リマインダー配信履歴（完了した予約のみ）
      if status == 'completed' && rand(10) < 8
        create_delivery_record(patient, appointment)
      end
    end
  end
  
  def self.generate_realistic_notes(treatment_type, status)
    notes_templates = {
      '一般診療' => ['右上6番むし歯治療', '左下7番CR充填', '全体的な口腔内チェック'],
      '定期検診' => ['異常なし、良好な状態', '軽度歯石付着、次回クリーニング推奨', 'プラーク除去、ブラッシング指導'],
      '歯石除去' => ['上下顎歯石除去実施', 'SRP実施、経過良好', '歯肉炎改善傾向'],
      'ホワイトニング' => ['オフィスホワイトニング実施', 'ホームホワイトニング開始', '色調確認、満足度高'],
      '矯正チェック' => ['ワイヤー調整実施', 'アライナー交換', '歯の移動順調'],
      'インプラント検診' => ['インプラント周囲健全', 'プロービング値安定', 'メンテナンス継続']
    }
    
    base_notes = notes_templates[treatment_type]&.sample || '治療実施'
    
    case status
    when 'cancelled'
      "#{base_notes}（患者都合によりキャンセル）"
    when 'completed'
      "#{base_notes}。次回予約: #{rand(4..12)}週後"
    else
      base_notes
    end
  end
  
  def self.create_delivery_record(patient, appointment)
    delivery_types = ['email', 'line', 'sms']
    preferred_type = patient.line_user_id ? 'line' : 
                    patient.email.present? ? 'email' : 'sms'
    
    # 前日リマインダー
    reminder_date = appointment.appointment_date - 1.day
    
    delivery = Delivery.create!(
      patient: patient,
      appointment: appointment,
      delivery_type: preferred_type,
      subject: "【#{appointment.appointment_date.strftime('%m/%d')}】明日の予約リマインダー",
      content: generate_reminder_content(patient, appointment),
      status: 'sent',
      sent_at: reminder_date
    )
  end
  
  def self.generate_reminder_content(patient, appointment)
    <<~CONTENT
      #{patient.name}様

      明日 #{appointment.appointment_date.strftime('%m月%d日(%a) %H:%M')} からの予約をお忘れなくお願いいたします。

      【予約内容】
      ・治療内容: #{appointment.treatment_type}
      ・所要時間: 約#{appointment.duration_minutes}分

      何かご不明な点がございましたら、お気軽にお電話ください。

      ※体調不良等でキャンセルされる場合は、前日までにご連絡をお願いいたします。

      歯科クリニック
    CONTENT
  end
  
  def self.display_demo_stats
    puts "\n📊 デモデータ統計情報:"
    puts "=" * 50
    puts "総患者数: #{Patient.count}名"
    puts "総予約数: #{Appointment.count}件"
    puts "完了した予約: #{Appointment.where(status: 'completed').count}件"
    puts "キャンセル予約: #{Appointment.where(status: 'cancelled').count}件"
    puts "配信されたリマインダー: #{Delivery.count}件"
    
    # 年代別統計
    puts "\n👥 年代別患者分布:"
    age_groups = Patient.all.group_by do |p|
      age = Date.current.year - p.birth_date.year
      case age
      when 0..29 then "20代"
      when 30..39 then "30代" 
      when 40..49 then "40代"
      when 50..59 then "50代"
      else "60代以上"
      end
    end
    
    age_groups.each do |group, patients|
      puts "  #{group}: #{patients.count}名"
    end
    
    # 治療種別統計
    puts "\n🦷 治療種別統計:"
    treatment_stats = Appointment.group(:treatment_type).count
    treatment_stats.each do |type, count|
      puts "  #{type}: #{count}件"
    end
    
    puts "=" * 50
    puts "✅ デモ環境準備完了！"
  end
end

# シードデータ実行
if Rails.env.development?
  DemoPatients.create_sample_data
end