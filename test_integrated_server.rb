#!/usr/bin/env ruby
# 統合サーバーテストスクリプト

require 'net/http'
require 'json'

def test_route(path, expected_status = 200)
  uri = URI("http://localhost:3000#{path}")
  
  begin
    response = Net::HTTP.get_response(uri)
    if response.code.to_i == expected_status
      puts "✅ #{path} - OK (#{response.code})"
      return true
    else
      puts "❌ #{path} - ERROR (#{response.code})"
      return false
    end
  rescue => e
    puts "❌ #{path} - CONNECTION ERROR: #{e.message}"
    return false
  end
end

puts "🦷 歯科医院統合管理システム - ルートテスト"
puts "=" * 50

# テストするルート
routes = [
  '/',                    # ダッシュボード
  '/patients',            # 患者管理
  '/patients/new',        # 新規患者登録
  '/patients/1',          # 患者詳細
  '/appointments',        # 予約管理
  '/appointments/new',    # 新規予約作成
  '/calendar',            # カレンダー
  '/reminders',           # リマインド管理
  '/settings',            # 設定
  '/api/appointments.json' # API
]

puts "テスト開始..."
sleep 2  # サーバー起動待機

success_count = 0
routes.each do |route|
  success_count += 1 if test_route(route)
end

puts "=" * 50
puts "テスト結果: #{success_count}/#{routes.length} ルートが正常"

if success_count == routes.length
  puts "🎉 全ルートが正常に動作しています！"
else
  puts "⚠️  いくつかのルートに問題があります。"
end