#!/bin/bash

echo "=== 🚀 本番環境 + デモ環境 セットアップ ==="
echo ""

# 色付き出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. アプリケーションコントローラーの更新
echo -e "${YELLOW}1. アクセス制御の環境変数対応${NC}"
cat > app/controllers/application_controller.rb << 'EOF'
class ApplicationController < ActionController::Base
  before_action :check_access_control
  
  private
  
  def check_access_control
    # ヘルスチェックは常に許可
    return if controller_name == 'health'
    
    # デモモードの場合
    if ENV['DEMO_MODE'] == 'true'
      setup_demo_session
      return
    end
    
    # ベータモードの場合（移行期間用）
    if ENV['BETA_MODE'] == 'true'
      return if controller_name == 'beta_login'
      unless session[:beta_authorized]
        redirect_to beta_login_path
        return
      end
    end
    
    # 本番モード：通常の認証のみ
  end
  
  def setup_demo_session
    # デモモードでは自動的にデモクリニックを設定
    unless session[:demo_initialized]
      demo_clinic = Clinic.find_or_create_by!(name: "デモクリニック") do |c|
        c.email = "demo@example.com"
        c.phone = "03-0000-0000"
        c.address = "東京都渋谷区デモ1-2-3"
      end
      session[:clinic_id] = demo_clinic.id
      session[:demo_initialized] = true
      session[:demo_mode] = true
    end
  end
  
  def current_clinic
    @current_clinic ||= Clinic.find_by(id: session[:clinic_id]) || Clinic.first
  end
  helper_method :current_clinic
  
  def demo_mode?
    ENV['DEMO_MODE'] == 'true' || session[:demo_mode]
  end
  helper_method :demo_mode?
end
EOF

# 2. デモモード通知バナーの作成
echo -e "${YELLOW}2. デモモード通知コンポーネント作成${NC}"
mkdir -p app/views/shared
cat > app/views/shared/_demo_banner.html.erb << 'EOF'
<% if demo_mode? %>
  <div class="bg-yellow-500 text-white px-4 py-2 text-center">
    <p class="text-sm font-medium">
      🎯 デモモードで動作中 - すべてのデータはテスト用です
      <span class="ml-2">
        <a href="#" class="underline" onclick="alert('実際の導入をご検討の方は、お問い合わせください。'); return false;">
          本番環境への移行
        </a>
      </span>
    </p>
  </div>
<% end %>
EOF

# 3. レイアウトファイルの更新
echo -e "${YELLOW}3. レイアウトにデモバナーを追加${NC}"
# layouts/application.html.erbにデモバナーを追加
sed -i.bak '/<body>/a\    <%= render "shared/demo_banner" %>' app/views/layouts/application.html.erb 2>/dev/null || true

# 4. デモデータ生成タスクの作成
echo -e "${YELLOW}4. デモデータ生成タスク作成${NC}"
cat > lib/tasks/demo.rake << 'EOF'
namespace :demo do
  desc "デモ環境用のサンプルデータを生成"
  task setup: :environment do
    return unless ENV['DEMO_MODE'] == 'true'
    
    puts "🎯 デモデータを生成中..."
    
    # デモクリニック
    clinic = Clinic.find_or_create_by!(name: "デモクリニック") do |c|
      c.email = "demo@example.com"
      c.phone = "03-0000-0000"
      c.address = "東京都渋谷区デモ1-2-3"
    end
    
    # サンプル患者データ
    patients = []
    10.times do |i|
      patient = Patient.find_or_create_by!(
        clinic: clinic,
        email: "demo_patient#{i+1}@example.com"
      ) do |p|
        p.name = "デモ患者#{i+1}"
        p.name_kana = "デモカンジャ#{i+1}"
        p.phone = "090-0000-#{sprintf('%04d', i+1)}"
        p.birth_date = (20 + i*3).years.ago
        p.gender = i.even? ? "male" : "female"
        p.address = "東京都渋谷区デモ町#{i+1}-2-3"
      end
      patients << patient
    end
    
    # サンプル予約データ
    patients.each_with_index do |patient, i|
      # 過去の予約
      2.times do |j|
        Appointment.find_or_create_by!(
          patient: patient,
          clinic: clinic,
          start_time: (i+1).weeks.ago + j.days + 10.hours
        ) do |a|
          a.end_time = a.start_time + 30.minutes
          a.treatment_type = ["初診", "定期検診", "虫歯治療", "歯石除去"].sample
          a.status = "completed"
          a.notes = "デモ予約 - 完了済み"
        end
      end
      
      # 今後の予約
      Appointment.find_or_create_by!(
        patient: patient,
        clinic: clinic,
        start_time: (i+1).days.from_now + 14.hours
      ) do |a|
        a.end_time = a.start_time + 30.minutes
        a.treatment_type = ["定期検診", "クリーニング", "相談"].sample
        a.status = "confirmed"
        a.notes = "デモ予約 - 予定"
      end
    end
    
    puts "✅ デモデータ生成完了！"
    puts "   - 患者: #{patients.count}名"
    puts "   - 予約: #{Appointment.count}件"
  end
  
  desc "デモデータをリセット"
  task reset: :environment do
    return unless ENV['DEMO_MODE'] == 'true'
    
    puts "🔄 デモデータをリセット中..."
    
    clinic = Clinic.find_by(name: "デモクリニック")
    if clinic
      clinic.appointments.destroy_all
      clinic.patients.destroy_all
    end
    
    Rake::Task['demo:setup'].invoke
    
    puts "✅ リセット完了！"
  end
end
EOF

# 5. 環境別設定ファイルの作成
echo -e "${YELLOW}5. 環境別設定ファイル作成${NC}"

# 本番環境用
cat > .env.production.local << 'EOF'
# 本番環境設定
RAILS_ENV=production
BETA_MODE=false
DEMO_MODE=false
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
EOF

# デモ環境用
cat > .env.demo << 'EOF'
# デモ環境設定
RAILS_ENV=production
BETA_MODE=false
DEMO_MODE=true
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
DEMO_RESET_INTERVAL=24h
EOF

# 6. Railwayデプロイ設定の更新
echo -e "${YELLOW}6. Railway設定ファイル更新${NC}"

# 本番用
cat > railway.production.json << 'EOF'
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE"
  },
  "deploy": {
    "numReplicas": 1,
    "startCommand": "bundle exec puma -C config/puma.rb",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  },
  "environments": {
    "production": {
      "env": {
        "RAILS_ENV": "production",
        "BETA_MODE": "false",
        "DEMO_MODE": "false",
        "RAILS_SERVE_STATIC_FILES": "true",
        "RAILS_LOG_TO_STDOUT": "true",
        "WEB_CONCURRENCY": "2",
        "RAILS_MAX_THREADS": "5"
      }
    }
  }
}
EOF

# デモ用
cat > railway.demo.json << 'EOF'
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE"
  },
  "deploy": {
    "numReplicas": 1,
    "startCommand": "bundle exec puma -C config/puma.rb",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  },
  "environments": {
    "production": {
      "env": {
        "RAILS_ENV": "production",
        "BETA_MODE": "false",
        "DEMO_MODE": "true",
        "RAILS_SERVE_STATIC_FILES": "true",
        "RAILS_LOG_TO_STDOUT": "true",
        "WEB_CONCURRENCY": "2",
        "RAILS_MAX_THREADS": "5",
        "DEMO_RESET_INTERVAL": "24h"
      }
    }
  }
}
EOF

echo ""
echo -e "${GREEN}✅ セットアップ完了！${NC}"
echo ""
echo -e "${BLUE}📋 次のステップ：${NC}"
echo ""
echo "1. 本番環境のデプロイ:"
echo "   railway link  # 'dentalsystem' を選択"
echo "   railway up"
echo ""
echo "2. デモ環境のデプロイ:"
echo "   railway init  # 新規プロジェクト 'dentalsystem-demo' を作成"
echo "   railway add   # PostgreSQLを追加"
echo "   cp railway.demo.json railway.json"
echo "   railway up"
echo "   railway run rails db:create db:migrate demo:setup"
echo ""
echo "3. 環境変数の確認:"
echo "   railway variables"
echo ""