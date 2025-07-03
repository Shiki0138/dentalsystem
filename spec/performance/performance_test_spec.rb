require 'rails_helper'
require 'benchmark'

RSpec.describe "パフォーマンステスト", type: :performance do
  describe "レスポンスタイム測定" do
    before(:all) do
      # テストデータ準備
      100.times do |i|
        Patient.create!(
          name: "患者#{i}",
          phone: "090-0000-#{sprintf('%04d', i)}",
          email: "patient#{i}@example.com"
        )
      end
    end
    
    context "データベースクエリパフォーマンス" do
      it "患者検索が高速に実行される" do
        execution_time = Benchmark.realtime do
          patients = Patient.where("name LIKE ?", "%患者%").limit(50)
          patients.load
        end
        
        expect(execution_time).to be < 0.1 # 100ms以内
        puts "患者検索実行時間: #{(execution_time * 1000).round(2)}ms"
      end
      
      it "予約一覧取得が高速に実行される" do
        # テスト予約データ作成
        patient = Patient.first
        30.times do |i|
          Appointment.create!(
            patient: patient,
            appointment_date: Date.today + i.days,
            appointment_time: "#{9 + (i % 8)}:00",
            treatment_type: "治療"
          )
        end
        
        execution_time = Benchmark.realtime do
          appointments = Appointment.includes(:patient)
                                  .where(appointment_date: Date.today..30.days.from_now)
                                  .order(:appointment_date, :appointment_time)
          appointments.load
        end
        
        expect(execution_time).to be < 0.2 # 200ms以内
        puts "予約一覧取得時間: #{(execution_time * 1000).round(2)}ms"
      end
      
      it "N+1クエリが発生しない" do
        # ActiveRecordのクエリカウント
        query_count = 0
        
        ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
          query_count += 1
        end
        
        # includesを使用した効率的なクエリ
        Appointment.includes(:patient, :deliveries).limit(10).each do |appointment|
          appointment.patient.name
          appointment.deliveries.count
        end
        
        ActiveSupport::Notifications.unsubscribe('sql.active_record')
        
        expect(query_count).to be <= 3 # 3クエリ以内（メイン + 2つのincludes）
        puts "実行クエリ数: #{query_count}"
      end
    end
    
    context "メモリ使用量" do
      it "大量データ処理時のメモリ効率" do
        initial_memory = GetProcessMem.new.mb
        
        # バッチ処理のシミュレーション
        Patient.find_each(batch_size: 100) do |patient|
          # 処理のシミュレーション
          patient.name.upcase
        end
        
        final_memory = GetProcessMem.new.mb
        memory_increase = final_memory - initial_memory
        
        expect(memory_increase).to be < 50 # 50MB以内の増加
        puts "メモリ使用増加量: #{memory_increase.round(2)}MB"
      end
    end
    
    context "同時アクセス処理" do
      it "並行処理が正常に動作する" do
        errors = []
        threads = []
        
        execution_time = Benchmark.realtime do
          10.times do |i|
            threads << Thread.new do
              begin
                Patient.create!(
                  name: "並行テスト#{i}",
                  phone: "090-9999-#{sprintf('%04d', i)}"
                )
              rescue => e
                errors << e
              end
            end
          end
          
          threads.each(&:join)
        end
        
        expect(errors).to be_empty
        expect(execution_time).to be < 1.0 # 1秒以内
        puts "並行処理実行時間: #{(execution_time * 1000).round(2)}ms"
      end
    end
    
    context "キャッシュ効率" do
      it "キャッシュが適切に機能する" do
        Rails.cache.clear
        
        # 初回アクセス（キャッシュなし）
        first_time = Benchmark.realtime do
          result = Rails.cache.fetch("expensive_query") do
            Patient.joins(:appointments).group(:id).count
          end
        end
        
        # 2回目アクセス（キャッシュあり）
        second_time = Benchmark.realtime do
          result = Rails.cache.fetch("expensive_query") do
            Patient.joins(:appointments).group(:id).count
          end
        end
        
        expect(second_time).to be < (first_time * 0.1) # 10%以下の時間
        puts "キャッシュなし: #{(first_time * 1000).round(2)}ms"
        puts "キャッシュあり: #{(second_time * 1000).round(2)}ms"
      end
    end
  end
  
  describe "スケーラビリティテスト" do
    it "大量データでも性能が劣化しない" do
      # 1000件のデータでテスト
      data_sizes = [100, 500, 1000]
      execution_times = []
      
      data_sizes.each do |size|
        # データ準備
        size.times do |i|
          Patient.create!(
            name: "スケールテスト#{i}",
            phone: "090-8888-#{sprintf('%04d', i)}"
          )
        end
        
        # 実行時間測定
        time = Benchmark.realtime do
          Patient.where("name LIKE ?", "%スケール%").count
        end
        
        execution_times << time
        puts "#{size}件のデータ: #{(time * 1000).round(2)}ms"
      end
      
      # 線形以下の増加率であることを確認
      growth_rate = execution_times.last / execution_times.first
      expect(growth_rate).to be < 15 # データ量10倍で実行時間15倍以内
    end
  end
end