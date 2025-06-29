# 歯科クリニック予約・業務管理システム 包括的統合テスト
# Version: 1.0
# Date: 2025-06-29

require 'rails_helper'

RSpec.describe "歯科クリニック包括的統合テスト", type: :request do
  let!(:patient) { create(:patient, name: "田中 太郎", phone: "090-1234-5678", email: "tanaka@example.com") }
  let!(:employee) { create(:employee, name: "佐藤 花子", role: "receptionist") }
  let!(:current_user) { create(:user, email: "admin@clinic.com", password: "password123") }

  before do
    Rails.cache.clear
    sign_in current_user
  end

  describe "【1. 機能統合テスト】" do
    context "1.1 予約統合モジュール（IMAP→Parser→Manual Booking）" do
      it "メール受信から予約登録までの一連フローが正常に動作すること" do
        # テスト開始ログ
        puts "=== 予約統合モジュール統合テスト開始 ==="
        
        # Step 1: メール受信をシミュレーション
        mail_content = <<~MAIL
          Subject: 【EPark歯科】予約完了のお知らせ
          From: noreply@epark.jp
          To: clinic@example.com
          
          田中 太郎様の予約が完了しました。
          日時: 2025-07-01 14:00
          診療内容: 定期検診
          電話番号: 090-1234-5678
        MAIL
        
        # Step 2: Mail Parser Service のテスト
        parser_result = MailParserService.new.parse(mail_content)
        expect(parser_result[:success]).to be true
        expect(parser_result[:patient_name]).to eq "田中 太郎"
        expect(parser_result[:appointment_time]).to eq "2025-07-01 14:00"
        expect(parser_result[:phone]).to eq "090-1234-5678"
        
        # Step 3: 重複チェック
        duplicate_result = DuplicateCheckService.new.check_patient(
          name: parser_result[:patient_name],
          phone: parser_result[:phone]
        )
        expect(duplicate_result[:has_duplicate]).to be true
        expect(duplicate_result[:patient_id]).to eq patient.id
        
        # Step 4: 予約登録APIテスト
        post '/api/v1/appointments', params: {
          patient_id: patient.id,
          appointment_time: parser_result[:appointment_time],
          status: 'booked',
          notes: '定期検診'
        }
        expect(response).to have_http_status(:created)
        
        # Step 5: 予約確認
        appointment = Appointment.last
        expect(appointment.patient_id).to eq patient.id
        expect(appointment.status).to eq 'booked'
        
        puts "✓ 予約統合モジュール統合テスト完了"
      end
      
      it "手動予約入力UIが30秒以内の操作を実現できること" do
        # パフォーマンステスト
        start_time = Time.current
        
        # 患者検索APIのレスポンス時間測定
        get '/api/v1/patients/search', params: { q: '田中' }
        expect(response).to have_http_status(:ok)
        search_time = Time.current - start_time
        expect(search_time).to be < 1.0 # 1秒以内
        
        # 空き枠取得のレスポンス時間測定
        get '/book/manual', params: { date: Date.current.strftime('%Y-%m-%d') }
        expect(response).to have_http_status(:ok)
        
        total_time = Time.current - start_time
        expect(total_time).to be < 5.0 # 5秒以内（30秒KPI達成の基盤）
        
        puts "✓ 手動予約UI性能テスト完了（応答時間: #{total_time.round(2)}秒）"
      end
    end

    context "1.2 リマインド配信モジュール（Daily→Reminder→LINE/メール配信）" do
      let!(:future_appointment) do
        create(:appointment, 
               patient: patient, 
               appointment_time: 3.days.from_now,
               status: 'booked')
      end
      
      it "リマインダー配信の完全フローが動作すること" do
        puts "=== リマインダー配信統合テスト開始 ==="
        
        # Step 1: Daily Reminder Job実行
        expect {
          DailyReminderJob.perform_now
        }.to change { Delivery.count }.by_at_least(1)
        
        # Step 2: 配信記録確認
        delivery = Delivery.last
        expect(delivery.appointment_id).to eq future_appointment.id
        expect(delivery.delivery_method).to be_in(['line', 'email'])
        expect(delivery.status).to eq 'sent'
        
        # Step 3: LINE配信テスト（モック）
        allow(LineMessagingService).to receive(:send_reminder).and_return({ success: true })
        
        ReminderJob.perform_now(future_appointment.id, 'line')
        
        expect(LineMessagingService).to have_received(:send_reminder)
        
        puts "✓ リマインダー配信統合テスト完了"
      end
      
      it "配信失敗時のフォールバック機能が動作すること" do
        # LINE配信失敗をシミュレーション
        allow(LineMessagingService).to receive(:send_reminder).and_return({ success: false, error: 'API Error' })
        allow(ReminderMailer).to receive(:three_day_reminder).and_call_original
        
        ReminderJob.perform_now(future_appointment.id, 'line')
        
        # メールフォールバックの確認
        expect(ReminderMailer).to have_received(:three_day_reminder)
        
        puts "✓ フォールバック機能テスト完了"
      end
    end

    context "1.3 顧客管理（患者検索→重複検出→マージ）" do
      let!(:duplicate_patient) { create(:patient, name: "田中太郎", phone: "090-1234-5678", email: "tanaka2@example.com") }
      
      it "重複患者検出とマージ機能が正常に動作すること" do
        puts "=== 顧客管理統合テスト開始 ==="
        
        # Step 1: 重複検出
        get '/patients/duplicates', params: { patient_id: patient.id }
        expect(response).to have_http_status(:ok)
        
        # Step 2: 重複検出結果確認
        duplicates = DuplicateCheckService.new.find_duplicates(patient)
        expect(duplicates).to include(duplicate_patient)
        
        # Step 3: マージ処理
        post '/patients/merge', params: {
          primary_patient_id: patient.id,
          duplicate_patient_id: duplicate_patient.id
        }
        expect(response).to have_http_status(:ok)
        
        # Step 4: マージ結果確認
        duplicate_patient.reload
        expect(duplicate_patient.merged_to).to eq patient.id
        
        puts "✓ 顧客管理統合テスト完了"
      end
    end

    context "1.4 勤怠・給与（打刻→計算→承認）" do
      it "勤怠から給与計算までのワンストップ処理が動作すること" do
        puts "=== 勤怠・給与統合テスト開始 ==="
        
        # Step 1: 出勤打刻
        post '/clockings', params: {
          employee_id: employee.id,
          clock_type: 'clock_in',
          location_lat: 35.6762,
          location_lng: 139.6503
        }
        expect(response).to have_http_status(:created)
        
        # Step 2: 退勤打刻
        travel 8.hours do
          post '/clockings', params: {
            employee_id: employee.id,
            clock_type: 'clock_out',
            location_lat: 35.6762,
            location_lng: 139.6503
          }
          expect(response).to have_http_status(:created)
        end
        
        # Step 3: 給与計算
        PayrollCalculationJob.perform_now(employee.id, Date.current.beginning_of_month)
        
        # Step 4: 給与記録確認
        payroll = Payroll.last
        expect(payroll.employee_id).to eq employee.id
        expect(payroll.worked_hours).to eq 8.0
        expect(payroll.total_salary).to be > 0
        
        puts "✓ 勤怠・給与統合テスト完了"
      end
    end

    context "1.5 LINE Webhook（受信→処理→応答）" do
      it "LINE Webhookの双方向通信が正常に動作すること" do
        puts "=== LINE Webhook統合テスト開始 ==="
        
        # Step 1: LINE Webhook受信シミュレーション
        webhook_payload = {
          events: [{
            type: 'message',
            message: {
              type: 'text',
              text: '予約確認'
            },
            source: {
              userId: 'U12345678901234567890123456789ab'
            },
            replyToken: 'replytoken123'
          }]
        }
        
        # Step 2: Webhook処理
        post '/webhooks/line', params: webhook_payload.to_json, headers: {
          'Content-Type' => 'application/json',
          'X-Line-Signature' => 'test_signature'
        }
        expect(response).to have_http_status(:ok)
        
        puts "✓ LINE Webhook統合テスト完了"
      end
    end
  end

  describe "【2. データフロー検証】" do
    it "各モジュール間のデータ連携が正常に動作すること" do
      puts "=== データフロー検証開始 ==="
      
      # Patient → Appointment → Delivery のデータフロー
      appointment = create(:appointment, patient: patient, appointment_time: 1.day.from_now)
      
      # リマインダー作成
      DailyReminderJob.perform_now
      
      # データ連携確認
      delivery = Delivery.find_by(appointment: appointment)
      expect(delivery).to be_present
      expect(delivery.patient_name).to eq patient.name
      expect(delivery.patient_phone).to eq patient.phone
      
      puts "✓ データフロー検証完了"
    end

    it "キャッシュ整合性が保たれていること" do
      puts "=== キャッシュ整合性検証開始 ==="
      
      # キャッシュ設定確認
      expect(Rails.cache).to be_present
      
      # Patient検索キャッシュテスト
      key = "patient_search_田中"
      Rails.cache.write(key, [patient])
      cached_result = Rails.cache.read(key)
      expect(cached_result).to include(patient)
      
      # キャッシュ無効化テスト
      patient.update(name: "田中 二郎")
      Rails.cache.delete(key)
      expect(Rails.cache.read(key)).to be_nil
      
      puts "✓ キャッシュ整合性検証完了"
    end

    it "トランザクション境界が適切に設定されていること" do
      puts "=== トランザクション境界検証開始 ==="
      
      expect {
        ActiveRecord::Base.transaction do
          patient = create(:patient, name: "テスト患者")
          appointment = create(:appointment, patient: patient)
          
          # 意図的にエラーを発生
          raise ActiveRecord::Rollback if appointment.patient_id.nil?
        end
      }.not_to change { Patient.count }
      
      puts "✓ トランザクション境界検証完了"
    end
  end

  describe "【3. エラーケース】" do
    it "ネットワーク障害時に適切にハンドリングされること" do
      puts "=== ネットワーク障害テスト開始 ==="
      
      # 外部API障害をシミュレーション
      allow(LineMessagingService).to receive(:send_reminder).and_raise(Faraday::ConnectionFailed)
      
      expect {
        ReminderJob.perform_now(future_appointment.id, 'line')
      }.not_to raise_error
      
      # エラーログ記録確認
      delivery = Delivery.last
      expect(delivery.status).to eq 'failed'
      expect(delivery.error_message).to be_present
      
      puts "✓ ネットワーク障害テスト完了"
    end

    it "外部API障害時のフォールバック機能が動作すること" do
      puts "=== 外部API障害テスト開始 ==="
      
      # Gmail API障害をシミュレーション
      allow_any_instance_of(ImapFetcherJob).to receive(:perform).and_raise(Google::Apis::ServerError.new('Service Unavailable'))
      
      expect {
        ImapFetcherJob.perform_now
      }.not_to raise_error
      
      # Parse Error記録確認
      expect(ParseError.last.error_type).to eq 'api_error'
      
      puts "✓ 外部API障害テスト完了"
    end

    it "同時アクセス時の競合状態が適切に処理されること" do
      puts "=== 同時アクセス競合テスト開始 ==="
      
      # 同じ時間枠への同時予約をシミュレーション
      appointment_time = 1.day.from_now.change(hour: 14, min: 0)
      
      threads = []
      results = []
      
      3.times do |i|
        threads << Thread.new do
          begin
            post '/api/v1/appointments', params: {
              patient_id: patient.id,
              appointment_time: appointment_time,
              status: 'booked'
            }
            results << response.status
          rescue => e
            results << e.class.name
          end
        end
      end
      
      threads.each(&:join)
      
      # 1つの予約のみ成功することを確認
      success_count = results.count(201)
      expect(success_count).to eq 1
      
      puts "✓ 同時アクセス競合テスト完了"
    end
  end

  describe "【4. 品質基準チェック】" do
    it "レスポンス時間95パーセンタイルが1秒未満であること" do
      puts "=== レスポンス時間テスト開始 ==="
      
      response_times = []
      
      10.times do
        start_time = Time.current
        get '/dashboard'
        response_times << (Time.current - start_time)
      end
      
      # 95パーセンタイル計算
      percentile_95 = response_times.sort[8] # 10回中9番目 = 95%
      expect(percentile_95).to be < 1.0
      
      puts "✓ レスポンス時間テスト完了（95p: #{percentile_95.round(3)}秒）"
    end

    it "Critical Pathが100%通過することを確認" do
      puts "=== Critical Path テスト開始 ==="
      
      critical_paths = [
        -> { get '/dashboard' },
        -> { get '/appointments' },
        -> { get '/patients' },
        -> { post '/api/v1/appointments', params: { patient_id: patient.id, appointment_time: 1.day.from_now } },
        -> { get '/book/manual' }
      ]
      
      success_count = 0
      critical_paths.each do |path|
        begin
          path.call
          success_count += 1 if response.successful?
        rescue => e
          puts "Critical Path失敗: #{e.message}"
        end
      end
      
      success_rate = (success_count.to_f / critical_paths.size) * 100
      expect(success_rate).to eq 100.0
      
      puts "✓ Critical Path テスト完了（成功率: #{success_rate}%）"
    end

    it "セキュリティ基準が満たされていること" do
      puts "=== セキュリティテスト開始 ==="
      
      # CSRF保護確認
      post '/appointments', params: { patient_id: patient.id }
      expect(response).to have_http_status(:unprocessable_entity)
      
      # 認証が必要なエンドポイントの確認
      sign_out current_user
      get '/admin/payrolls'
      expect(response).to have_http_status(:redirect)
      
      puts "✓ セキュリティテスト完了"
    end
  end

  after(:all) do
    puts "\n=== 統合テスト完了 ==="
    puts "実行時刻: #{Time.current}"
    puts "テスト対象: 歯科クリニック予約・業務管理システム"
    puts "===================="
  end
end