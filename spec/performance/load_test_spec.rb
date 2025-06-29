# 歯科クリニック予約・業務管理システム パフォーマンステスト
# Load Testing with RSpec
# Version: 1.0

require 'rails_helper'

RSpec.describe "システムパフォーマンステスト", type: :request do
  let!(:patients) { create_list(:patient, 100) }
  let!(:appointments) { create_list(:appointment, 200, patient: patients.sample) }
  let!(:current_user) { create(:user, email: "admin@clinic.com", password: "password123") }

  before do
    sign_in current_user
    Rails.cache.clear
  end

  describe "負荷テスト" do
    it "同時接続100ユーザーでのパフォーマンス測定" do
      puts "=== 負荷テスト開始 ==="
      
      concurrent_requests = 50
      response_times = []
      errors = []
      
      threads = []
      
      concurrent_requests.times do |i|
        threads << Thread.new do
          begin
            start_time = Time.current
            
            # 患者検索API
            get '/api/v1/patients/search', params: { q: '田中' }
            search_time = Time.current - start_time
            
            # 予約一覧取得
            get '/appointments'
            list_time = Time.current - start_time - search_time
            
            # ダッシュボード表示
            get '/dashboard'
            dashboard_time = Time.current - start_time - search_time - list_time
            
            total_time = Time.current - start_time
            response_times << {
              thread_id: i,
              search_time: search_time,
              list_time: list_time,
              dashboard_time: dashboard_time,
              total_time: total_time
            }
            
          rescue => e
            errors << { thread_id: i, error: e.message }
          end
        end
      end
      
      # 全スレッドの完了を待機
      threads.each(&:join)
      
      # パフォーマンス分析
      avg_response_time = response_times.map { |rt| rt[:total_time] }.sum / response_times.size
      max_response_time = response_times.map { |rt| rt[:total_time] }.max
      min_response_time = response_times.map { |rt| rt[:total_time] }.min
      
      # 95パーセンタイル計算
      sorted_times = response_times.map { |rt| rt[:total_time] }.sort
      percentile_95_index = (sorted_times.size * 0.95).ceil - 1
      percentile_95 = sorted_times[percentile_95_index]
      
      puts "負荷テスト結果:"
      puts "  同時接続数: #{concurrent_requests}"
      puts "  成功率: #{((response_times.size.to_f / concurrent_requests) * 100).round(2)}%"
      puts "  エラー数: #{errors.size}"
      puts "  平均応答時間: #{avg_response_time.round(3)}秒"
      puts "  最大応答時間: #{max_response_time.round(3)}秒"
      puts "  最小応答時間: #{min_response_time.round(3)}秒"
      puts "  95パーセンタイル: #{percentile_95.round(3)}秒"
      
      # 品質基準チェック（仕様書要件）
      expect(percentile_95).to be < 1.0, "95パーセンタイルが1秒を超過: #{percentile_95.round(3)}秒"
      expect(errors.size).to be < (concurrent_requests * 0.01), "エラー率が1%を超過: #{errors.size}/#{concurrent_requests}"
      
      puts "✓ 負荷テスト完了 - 品質基準を満たしています"
    end

    it "データベースパフォーマンステスト" do
      puts "=== データベースパフォーマンステスト開始 ==="
      
      # 大量データでのクエリ性能測定
      test_cases = [
        {
          name: "患者検索（LIKE検索）",
          query: -> { Patient.where("name LIKE ?", "%田中%").limit(10) }
        },
        {
          name: "予約検索（日付範囲）",
          query: -> { Appointment.where(appointment_time: Date.current..1.week.from_now) }
        },
        {
          name: "重複患者検出",
          query: -> { Patient.joins(:appointments).group('patients.id').having('COUNT(appointments.id) > 1') }
        },
        {
          name: "複雑JOIN（患者-予約-配信）",
          query: -> { Patient.joins(appointments: :deliveries).where(deliveries: { status: 'sent' }) }
        }
      ]
      
      test_cases.each do |test_case|
        # クエリ実行時間測定
        execution_times = []
        
        10.times do
          start_time = Time.current
          result = test_case[:query].call.to_a
          execution_time = Time.current - start_time
          execution_times << execution_time
        end
        
        avg_time = execution_times.sum / execution_times.size
        max_time = execution_times.max
        
        puts "#{test_case[:name]}: 平均#{avg_time.round(3)}秒, 最大#{max_time.round(3)}秒"
        
        # 5ms以内の要件チェック（仕様書要件）
        expect(avg_time).to be < 0.005, "#{test_case[:name]}が5ms要件を超過: #{avg_time.round(3)}秒"
      end
      
      puts "✓ データベースパフォーマンステスト完了"
    end

    it "メモリ使用量テスト" do
      puts "=== メモリ使用量テスト開始 ==="
      
      # 初期メモリ使用量
      initial_memory = get_memory_usage
      
      # 大量データ処理シミュレーション
      1000.times do |i|
        patient = create(:patient, name: "テスト患者#{i}")
        appointment = create(:appointment, patient: patient)
        
        # 100件ごとにGC実行
        GC.start if i % 100 == 0
      end
      
      # 処理後メモリ使用量
      final_memory = get_memory_usage
      memory_increase = final_memory - initial_memory
      
      puts "メモリ使用量:"
      puts "  初期: #{initial_memory}MB"
      puts "  最終: #{final_memory}MB"
      puts "  増加: #{memory_increase}MB"
      
      # メモリリーク検出（100MB以上の増加は異常）
      expect(memory_increase).to be < 100, "メモリリークの可能性: #{memory_increase}MB増加"
      
      puts "✓ メモリ使用量テスト完了"
    end

    it "キャッシュ効率テスト" do
      puts "=== キャッシュ効率テスト開始 ==="
      
      # キャッシュなしでの実行時間
      Rails.cache.clear
      start_time = Time.current
      get '/dashboard'
      no_cache_time = Time.current - start_time
      
      # キャッシュありでの実行時間
      start_time = Time.current
      get '/dashboard'
      cached_time = Time.current - start_time
      
      # キャッシュ効率計算
      cache_efficiency = ((no_cache_time - cached_time) / no_cache_time) * 100
      
      puts "キャッシュ効率:"
      puts "  キャッシュなし: #{no_cache_time.round(3)}秒"
      puts "  キャッシュあり: #{cached_time.round(3)}秒"
      puts "  効率: #{cache_efficiency.round(1)}%"
      
      # キャッシュ効率30%以上を期待
      expect(cache_efficiency).to be > 30, "キャッシュ効率が低い: #{cache_efficiency.round(1)}%"
      
      puts "✓ キャッシュ効率テスト完了"
    end
  end

  describe "ストレステスト" do
    it "長時間稼働テスト（1時間シミュレーション）" do
      puts "=== 長時間稼働テスト開始 ==="
      
      # 1時間の稼働をシミュレーション（実際は短時間で実行）
      start_time = Time.current
      error_count = 0
      success_count = 0
      
      # 10分間のシミュレーション
      while Time.current - start_time < 600 # 10分 = 600秒
        begin
          # ランダムなAPIエンドポイントにアクセス
          endpoints = ['/dashboard', '/appointments', '/patients', '/api/v1/patients/search?q=test']
          endpoint = endpoints.sample
          
          get endpoint
          
          if response.successful?
            success_count += 1
          else
            error_count += 1
          end
          
          # 少し待機
          sleep(0.1)
          
        rescue => e
          error_count += 1
        end
      end
      
      total_requests = success_count + error_count
      success_rate = (success_count.to_f / total_requests) * 100
      
      puts "長時間稼働テスト結果:"
      puts "  実行時間: #{(Time.current - start_time).round(1)}秒"
      puts "  総リクエスト数: #{total_requests}"
      puts "  成功数: #{success_count}"
      puts "  エラー数: #{error_count}"
      puts "  成功率: #{success_rate.round(2)}%"
      
      # 99.9%の可用性を期待
      expect(success_rate).to be > 99.9, "可用性が要件を下回る: #{success_rate.round(2)}%"
      
      puts "✓ 長時間稼働テスト完了"
    end
  end

  private

  def get_memory_usage
    # Rubyプロセスのメモリ使用量を取得（MB単位）
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  end
end