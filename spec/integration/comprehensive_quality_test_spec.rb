require 'rails_helper'

RSpec.describe "包括的品質保証テスト", type: :integration do
  describe "全機能動作確認テスト" do
    context "予約管理機能" do
      it "予約の作成・更新・削除が正常に動作する" do
        patient = Patient.create!(
          name: "テスト患者",
          phone: "090-1234-5678",
          email: "test@example.com"
        )
        
        # 予約作成
        appointment = Appointment.create!(
          patient: patient,
          appointment_date: Date.tomorrow,
          appointment_time: "10:00",
          treatment_type: "定期検診",
          status: "scheduled"
        )
        expect(appointment).to be_valid
        expect(appointment.status).to eq("scheduled")
        
        # 予約更新
        appointment.update!(status: "completed")
        expect(appointment.reload.status).to eq("completed")
        
        # 予約削除
        expect { appointment.destroy }.to change(Appointment, :count).by(-1)
      end
      
      it "重複予約を防止する" do
        patient = Patient.create!(
          name: "テスト患者2",
          phone: "090-8765-4321"
        )
        
        appointment1 = Appointment.create!(
          patient: patient,
          appointment_date: Date.tomorrow,
          appointment_time: "14:00",
          treatment_type: "治療"
        )
        
        appointment2 = Appointment.new(
          patient: patient,
          appointment_date: Date.tomorrow,
          appointment_time: "14:00",
          treatment_type: "検診"
        )
        
        expect(appointment2).not_to be_valid
        expect(appointment2.errors[:appointment_time]).to include("はすでに予約されています")
      end
    end
    
    context "患者管理機能" do
      it "患者情報の登録・検索・更新が正常に動作する" do
        # 患者登録
        patient = Patient.create!(
          name: "山田太郎",
          phone: "080-1111-2222",
          email: "yamada@example.com",
          birth_date: "1990-01-01"
        )
        expect(patient).to be_valid
        
        # 患者検索
        found_patients = Patient.where("name LIKE ?", "%山田%")
        expect(found_patients).to include(patient)
        
        # 患者情報更新
        patient.update!(phone: "080-3333-4444")
        expect(patient.reload.phone).to eq("080-3333-4444")
      end
    end
    
    context "認証機能" do
      it "ユーザー登録・ログイン・ログアウトが正常に動作する" do
        # ユーザー登録
        user = User.create!(
          email: "staff@dental.com",
          password: "password123",
          name: "スタッフ太郎"
        )
        expect(user).to be_valid
        
        # ログイン確認
        authenticated = user.valid_password?("password123")
        expect(authenticated).to be true
        
        # 不正パスワード
        wrong_auth = user.valid_password?("wrongpassword")
        expect(wrong_auth).to be false
      end
    end
    
    context "リマインダー機能" do
      it "予約リマインダーが正常に送信される" do
        patient = Patient.create!(
          name: "リマインダーテスト",
          phone: "090-5555-6666",
          email: "reminder@example.com"
        )
        
        appointment = Appointment.create!(
          patient: patient,
          appointment_date: 3.days.from_now,
          appointment_time: "15:00",
          treatment_type: "クリーニング"
        )
        
        # リマインダー作成
        delivery = Delivery.create!(
          appointment: appointment,
          delivery_type: "reminder",
          status: "pending",
          scheduled_at: 2.days.from_now
        )
        
        expect(delivery).to be_valid
        expect(delivery.status).to eq("pending")
      end
    end
  end
  
  describe "データ整合性テスト" do
    it "関連データの整合性が保たれる" do
      patient = Patient.create!(name: "整合性テスト", phone: "090-7777-8888")
      appointment_count = 3
      
      appointment_count.times do |i|
        Appointment.create!(
          patient: patient,
          appointment_date: Date.today + i.days,
          appointment_time: "10:00",
          treatment_type: "治療#{i+1}"
        )
      end
      
      expect(patient.appointments.count).to eq(appointment_count)
      
      # 患者削除時の予約も削除される（カスケード）
      patient.destroy
      expect(Appointment.where(patient_id: patient.id).count).to eq(0)
    end
  end
  
  describe "トランザクション処理テスト" do
    it "エラー時にロールバックが正常に動作する" do
      ActiveRecord::Base.transaction do
        patient = Patient.create!(name: "トランザクションテスト", phone: "090-9999-0000")
        
        # 意図的にエラーを発生させる
        expect {
          appointment = Appointment.create!(
            patient: patient,
            appointment_date: nil, # 必須項目をnilに
            appointment_time: "10:00"
          )
          raise ActiveRecord::Rollback if appointment.errors.any?
        }.not_to change(Patient, :count)
      end
    end
  end
end