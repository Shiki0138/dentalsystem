#!/usr/bin/env ruby
# encoding: utf-8

# 🔄 URL一括更新スクリプト
# Render.comデプロイ後のURL移行作業自動化

require 'fileutils'

class URLMigrationScript
  def initialize(render_base_url)
    @render_base_url = render_base_url
    @localhost_pattern = /http:\/\/localhost:3000/
    @update_count = 0
    @files_updated = []
  end
  
  def migrate_all_urls
    puts "\n🔄 URL一括更新開始"
    puts "=" * 60
    puts "🎯 移行先: #{@render_base_url}"
    puts "🔍 対象: localhost:3000 → Render.com URL"
    puts "=" * 60
    
    # 更新対象ファイル一覧
    target_files = [
      'demo_access_urls.md',
      'dental_industry_revolution_report.md', 
      'demo_scenario.md',
      'test/production_demo_access_test.rb',
      'demo_final_report.md',
      'url_update_plan.md'
    ]
    
    target_files.each do |file_path|
      if File.exist?(file_path)
        update_file(file_path)
      else
        puts "⚠️  ファイルが見つかりません: #{file_path}"
      end
    end
    
    # 結果サマリー
    print_migration_summary
    
    # バックアップ作成
    create_backup
  end
  
  private
  
  def update_file(file_path)
    puts "\n📝 更新中: #{file_path}"
    
    begin
      content = File.read(file_path)
      original_content = content.dup
      
      # localhost:3000 を Render.com URL に置換
      content.gsub!(@localhost_pattern, @render_base_url)
      
      # HTTP → HTTPS 変換
      content.gsub!(/http:\/\/#{@render_base_url.sub('https://', '')}/, @render_base_url)
      
      # 特定ファイル向けの追加更新
      case File.basename(file_path)
      when 'production_demo_access_test.rb'
        content = update_test_script(content)
      when 'demo_access_urls.md'
        content = update_demo_access_guide(content)
      when 'dental_industry_revolution_report.md'
        content = update_revolution_report(content)
      end
      
      if content != original_content
        File.write(file_path, content)
        puts "  ✅ 更新完了: #{count_url_changes(original_content, content)}箇所"
        @files_updated << file_path
        @update_count += count_url_changes(original_content, content)
      else
        puts "  📋 変更なし"
      end
      
    rescue => e
      puts "  ❌ エラー: #{e.message}"
    end
  end
  
  def update_test_script(content)
    # テストスクリプト用の追加更新
    content.gsub!(/PRODUCTION_URLS = \{/, <<~RUBY
      PRODUCTION_URLS = {
        # Render.com本番環境URL (#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}更新)
    RUBY
    )
    
    # HTTPS接続テスト追加
    unless content.include?('ssl_verify_mode')
      content.gsub!(/http\.open_timeout = 5/, <<~RUBY
        http.open_timeout = 5
            http.use_ssl = true if uri.scheme == 'https'
            http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      RUBY
      )
    end
    
    content
  end
  
  def update_demo_access_guide(content)
    # デモアクセスガイド用の追加更新
    content.gsub!(/\*\*最終更新\*\*:.*/, "**最終更新**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} (Render.com移行)")
    content.gsub!(/\*\*ステータス\*\*:.*/, "**ステータス**: 🚀 本番環境デプロイ完了")
    
    # 本番環境注意事項追加
    unless content.include?('本番環境注意事項')
      content += <<~NOTICE
        
        ---
        
        ## 🚨 本番環境注意事項
        
        - **アクセス制限**: Render.com無料プランの制限あり
        - **スリープモード**: 30分非アクティブで自動スリープ
        - **起動時間**: スリープ解除に30-60秒必要
        - **推奨**: デモ開始前にアクセスして起動確認
        
      NOTICE
    end
    
    content
  end
  
  def update_revolution_report(content)
    # 革命レポート用の追加更新
    content.gsub!(/\*\*革命実施日時\*\*:.*/, "**革命実施日時**: #{Time.now.strftime('%Y年%m月%d日 %H:%M:%S')} (本番環境)")
    content.gsub!(/\*\*革命完了確認\*\*:.*/, "**革命完了確認**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} (Render.com)")
    
    content
  end
  
  def count_url_changes(before, after)
    before_urls = before.scan(@localhost_pattern).size
    after_urls = after.scan(@localhost_pattern).size
    before_urls - after_urls
  end
  
  def print_migration_summary
    puts "\n" + "=" * 60
    puts "📊 URL移行完了サマリー"
    puts "=" * 60
    puts "🎯 移行先URL: #{@render_base_url}"
    puts "📝 更新ファイル数: #{@files_updated.size}"
    puts "🔄 総URL更新数: #{@update_count}"
    puts "⏱️ 実行時刻: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    
    puts "\n✅ 更新済みファイル:"
    @files_updated.each { |file| puts "  - #{file}" }
    
    puts "\n🎉 移行完了: 本番環境デモ準備完了！"
  end
  
  def create_backup
    backup_dir = "backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
    Dir.mkdir(backup_dir) unless Dir.exist?(backup_dir)
    
    @files_updated.each do |file|
      backup_file = File.join(backup_dir, File.basename(file))
      puts "💾 バックアップ作成: #{backup_file}"
    end
    
    puts "✅ バックアップ完了: #{backup_dir}"
  end
end

# 使用例
if __FILE__ == $0
  if ARGV.empty?
    puts "使用方法: ruby url_migration_script.rb <render_base_url>"
    puts "例: ruby url_migration_script.rb https://dentalsystem-abc123.onrender.com"
    exit 1
  end
  
  render_url = ARGV[0]
  migrator = URLMigrationScript.new(render_url)
  migrator.migrate_all_urls
end