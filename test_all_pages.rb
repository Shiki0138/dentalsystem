#!/usr/bin/env ruby
# システム全ページのエラーチェック

require 'net/http'
require 'uri'

BASE_URL = 'http://localhost:3003'

# テストするページのリスト
pages = [
  { path: '/', name: 'ダッシュボード' },
  { path: '/patients', name: '患者管理' },
  { path: '/patients/new', name: '新規患者登録' },
  { path: '/patients/1', name: '患者詳細' },
  { path: '/calendar', name: '予約カレンダー（日表示）' },
  { path: '/calendar?view=week', name: '予約カレンダー（週表示）' },
  { path: '/calendar?view=month', name: '予約カレンダー（月表示）' },
  { path: '/reminders', name: 'リマインド管理' },
  { path: '/settings', name: 'システム設定' },
  { path: '/api/appointments.json', name: '予約API' },
  { path: '/api/time_slots.json?date=2025-07-05', name: 'タイムスロットAPI' }
]

puts "🔍 歯科医院管理システムのエラーチェック開始...\n\n"

errors = []
success = []

pages.each do |page|
  begin
    uri = URI("#{BASE_URL}#{page[:path]}")
    response = Net::HTTP.get_response(uri)
    
    case response.code
    when '200'
      success << "✅ #{page[:name]} (#{page[:path]}) - OK"
    when '302'
      success << "↗️  #{page[:name]} (#{page[:path]}) - リダイレクト (正常)"
    when '404'
      errors << "❌ #{page[:name]} (#{page[:path]}) - 404 Not Found"
    when '500'
      errors << "❌ #{page[:name]} (#{page[:path]}) - 500 Internal Server Error"
      # エラー内容を取得
      if response.body.include?('undefined')
        error_match = response.body.match(/undefined\s+[^<]+/)
        errors << "   詳細: #{error_match[0]}" if error_match
      end
    else
      errors << "⚠️  #{page[:name]} (#{page[:path]}) - #{response.code} #{response.message}"
    end
  rescue => e
    errors << "❌ #{page[:name]} (#{page[:path]}) - 接続エラー: #{e.message}"
  end
end

# 結果表示
puts "=== 成功したページ ===\n"
success.each { |s| puts s }

if errors.any?
  puts "\n=== エラーが発生したページ ===\n"
  errors.each { |e| puts e }
else
  puts "\n🎉 すべてのページが正常に動作しています！"
end

puts "\n総ページ数: #{pages.size}"
puts "成功: #{success.size}"
puts "エラー: #{errors.size}"

# CSVエクスポートテスト
puts "\n📄 CSVエクスポートテスト..."
begin
  uri = URI("#{BASE_URL}/patients/export")
  response = Net::HTTP.get_response(uri)
  if response.code == '200' && response['Content-Type'].include?('csv')
    puts "✅ CSV出力機能 - OK"
  else
    puts "❌ CSV出力機能 - エラー (#{response.code})"
  end
rescue => e
  puts "❌ CSV出力機能 - 接続エラー: #{e.message}"
end