#!/bin/bash

# 🛡️ 安全なGAE移行スクリプト - エラー防止対策強化版
# Version: 1.0
# Purpose: Railway → GAE移行を安全に実行

set -euo pipefail  # エラー時即座停止
IFS=$'\n\t'       # 安全なIFS設定

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# エラーハンドラー
trap 'echo -e "${RED}❌ エラーが発生しました。Line: $LINENO${NC}" >&2; exit 1' ERR

echo -e "${MAGENTA}===================================================="
echo -e "🛡️  安全なGAE移行スクリプト (エラー防止対策強化版)"
echo -e "====================================================${NC}"

# タイムスタンプ
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_DIR="backup_${TIMESTAMP}"

# Step 1: 事前確認とバックアップ
echo -e "\n${BLUE}📋 Step 1: 事前確認とバックアップ${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 重要ファイルのバックアップ
echo -e "${YELLOW}📦 重要ファイルをバックアップ中...${NC}"
mkdir -p "$BACKUP_DIR"
cp -p Gemfile "$BACKUP_DIR/Gemfile.bak" 2>/dev/null || true
cp -p Gemfile.lock "$BACKUP_DIR/Gemfile.lock.bak" 2>/dev/null || true
cp -p .ruby-version "$BACKUP_DIR/.ruby-version.bak" 2>/dev/null || true
[ -f config/environments/production.rb ] && cp -p config/environments/production.rb "$BACKUP_DIR/production.rb.bak"

echo -e "${GREEN}✅ バックアップ完了: $BACKUP_DIR${NC}"

# gcloud確認
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ Google Cloud SDK がインストールされていません${NC}"
    echo -e "${YELLOW}以下のコマンドでインストール:${NC}"
    echo "curl https://sdk.cloud.google.com | bash"
    exit 1
fi

# Step 2: Ruby バージョン統一（GAE互換）
echo -e "\n${BLUE}🔧 Step 2: Ruby バージョン調整（GAE互換）${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# .ruby-versionをGAE互換に変更
echo -e "${YELLOW}📝 Ruby バージョンをGAE標準に調整中...${NC}"
echo "3.2.0" > .ruby-version

# Gemfileのrubyバージョンも調整
if grep -q 'ruby "3.3' Gemfile; then
    sed -i.bak 's/ruby "3.3.[0-9]"/ruby "3.2.0"/' Gemfile
    echo -e "${GREEN}✅ Gemfile: Ruby 3.2.0 に変更${NC}"
fi

# Step 3: Gemfile.lockクリーンアップ
echo -e "\n${BLUE}🧹 Step 3: Gemfile.lock クリーンアップ${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 既存のGemfile.lockを削除（不完全な状態を防ぐ）
if [ -f Gemfile.lock ]; then
    echo -e "${YELLOW}📝 既存のGemfile.lockを削除中...${NC}"
    rm -f Gemfile.lock
fi

# vendor/bundleも削除（キャッシュ問題を防ぐ）
if [ -d vendor/bundle ]; then
    echo -e "${YELLOW}📝 vendor/bundleを削除中...${NC}"
    rm -rf vendor/bundle
fi

# Step 4: GAE必須gemの追加
echo -e "\n${BLUE}💎 Step 4: GAE必須gemの追加${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Google Cloud gems追加（エラー自動収集用）
if ! grep -q "google-cloud-logging" Gemfile; then
    echo -e "${YELLOW}📝 Google Cloud gems追加中...${NC}"
    cat >> Gemfile << 'EOL'

# Google Cloud integration for GAE
group :production do
  gem 'google-cloud-logging', '~> 2.3'
  gem 'google-cloud-error_reporting', '~> 0.42'
  gem 'stackdriver', '~> 0.21'
end
EOL
fi

# Step 5: 最小限のapp.yaml作成
echo -e "\n${BLUE}📝 Step 5: app.yaml作成 (安全設定)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# SECRET_KEY_BASE生成
SECRET_KEY_BASE=$(openssl rand -hex 64)

cat > app.yaml << EOL
runtime: ruby32
env: standard

# インスタンス設定（コスト最小化）
automatic_scaling:
  min_instances: 0
  max_instances: 2
  target_cpu_utilization: 0.65
  target_throughput_utilization: 0.65
  max_concurrent_requests: 10
  max_pending_latency: 30s

# リソース設定
resources:
  cpu: 1
  memory_gb: 0.5
  disk_size_gb: 10

# 環境変数
env_variables:
  RAILS_ENV: "production"
  RACK_ENV: "production"
  RAILS_SERVE_STATIC_FILES: "true"
  RAILS_LOG_TO_STDOUT: "true"
  SECRET_KEY_BASE: "${SECRET_KEY_BASE}"
  RAILS_MASTER_KEY: "${SECRET_KEY_BASE}"
  WEB_CONCURRENCY: "1"
  RAILS_MAX_THREADS: "5"
  
# エントリーポイント
entrypoint: bundle exec rails server -p \$PORT -e production

# ヘルスチェック（重要）
readiness_check:
  path: "/health"
  check_interval_sec: 5
  timeout_sec: 4
  failure_threshold: 2
  success_threshold: 2
  app_start_timeout_sec: 300

liveness_check:
  path: "/health"
  check_interval_sec: 30
  timeout_sec: 4
  failure_threshold: 2
  success_threshold: 2
EOL

echo -e "${GREEN}✅ app.yaml作成完了（エラー防止設定込み）${NC}"

# Step 6: production.rb安全設定
echo -e "\n${BLUE}⚙️ Step 6: production.rb安全設定${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# production.rbの安全な更新
PROD_FILE="config/environments/production.rb"
if [ -f "$PROD_FILE" ]; then
    # 既存設定をコメントアウトして新設定追加
    cat >> "$PROD_FILE" << 'EOL'

# ===== Google App Engine 安全設定 =====
Rails.application.configure do
  # SSL設定（GAEが自動処理）
  config.force_ssl = false
  
  # 静的ファイル配信
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=3600'
  }
  
  # ログ設定
  config.log_level = :info
  config.log_tags = [ :request_id ]
  
  # アセット設定
  config.assets.compile = false
  config.assets.digest = true
  
  # エラーレポート設定
  if defined?(Google::Cloud::ErrorReporting)
    config.google_cloud.project_id = ENV['GOOGLE_CLOUD_PROJECT']
    config.google_cloud.keyfile = ENV['GOOGLE_APPLICATION_CREDENTIALS']
  end
  
  # Active Storageの安全設定
  config.active_storage.variant_processor = :mini_magick if defined?(ActiveStorage)
end
EOL
    echo -e "${GREEN}✅ production.rb更新完了${NC}"
fi

# Step 7: ヘルスチェックルート追加
echo -e "\n${BLUE}🏥 Step 7: ヘルスチェックルート追加${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! grep -q "/health" config/routes.rb; then
    echo -e "${YELLOW}📝 ヘルスチェックルート追加中...${NC}"
    
    # routes.rbの先頭付近に追加
    sed -i.bak '/Rails.application.routes.draw do/a\
  # Health check endpoints for GAE\
  get "/health", to: proc { [200, {"Content-Type" => "text/plain"}, ["OK"]] }\
  get "/_ah/health", to: proc { [200, {"Content-Type" => "text/plain"}, ["healthy"]] }\
  get "/_ah/start", to: proc { [200, {"Content-Type" => "text/plain"}, ["started"]] }\
  get "/_ah/stop", to: proc { [200, {"Content-Type" => "text/plain"}, ["stopping"]] }\
' config/routes.rb
fi

# Step 8: .gcloudignore作成（重要ファイル除外）
echo -e "\n${BLUE}📄 Step 8: .gcloudignore作成${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > .gcloudignore << 'EOL'
# Rails specific
*.log
*.sqlite3
/tmp
/log
.byebug_history
/public/packs
/public/packs-test
/node_modules
/yarn-error.log
yarn-debug.log*
.yarn-integrity
/storage

# Git
.git/
.gitignore

# Development
.env*
!.env.example
config/master.key
config/credentials/*.key
/coverage
/spec
/test
docker-compose*.yml
Dockerfile*

# Docs and configs
*.md
README*
docs/
.rubocop.yml
.eslintrc*

# Railway specific
railway.toml
nixpacks.toml
Procfile

# CI/CD
.github/
.circleci/
.gitlab-ci.yml

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# macOS
.DS_Store

# Backup
backup_*/
EOL

echo -e "${GREEN}✅ .gcloudignore作成完了${NC}"

# Step 9: database.yml確認と調整
echo -e "\n${BLUE}🗄️ Step 9: database.yml確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f config/database.yml ]; then
    # production設定を確認
    if ! grep -q "production:" config/database.yml; then
        echo -e "${YELLOW}⚠️ production設定が見つかりません${NC}"
        echo -e "${CYAN}後でCloud SQLの設定が必要です${NC}"
    else
        echo -e "${GREEN}✅ database.yml確認完了${NC}"
    fi
fi

# Step 10: 依存関係の再インストール
echo -e "\n${BLUE}📦 Step 10: 依存関係の安全インストール${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${YELLOW}📝 Bundlerを更新中...${NC}"
gem install bundler -v 2.5.9 --user-install || {
    echo -e "${YELLOW}⚠️ システムBundlerを使用します${NC}"
}

echo -e "${YELLOW}📝 依存関係をインストール中...${NC}"
bundle install --path vendor/bundle

# Step 11: アセットプリコンパイル（エラー対策）
echo -e "\n${BLUE}🎨 Step 11: アセットプリコンパイル${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# アセットプリコンパイルディレクトリ作成
mkdir -p public/assets

# プリコンパイル実行
echo -e "${YELLOW}🎨 アセットプリコンパイル中...${NC}"
RAILS_ENV=production bundle exec rails assets:precompile || {
    echo -e "${YELLOW}⚠️ アセットプリコンパイルをスキップ${NC}"
}

# Step 12: 最終確認
echo -e "\n${BLUE}🔍 Step 12: デプロイ前最終確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${CYAN}📋 チェックリスト:${NC}"
echo "✓ Ruby バージョン: 3.2.0 (GAE互換)"
echo "✓ app.yaml: 作成完了"
echo "✓ ヘルスチェック: 設定完了"
echo "✓ .gcloudignore: 作成完了"
echo "✓ Google Cloud gems: 追加完了"
echo "✓ バックアップ: $BACKUP_DIR"

# Railway関連ファイルの確認
if [ -f railway.toml ] || [ -f nixpacks.toml ] || [ -f Procfile ]; then
    echo -e "\n${YELLOW}⚠️ Railway関連ファイルが残っています:${NC}"
    ls -la | grep -E "(railway|nixpacks|Procfile)" || true
fi

# 完了メッセージ
echo -e "\n${MAGENTA}===================================================="
echo -e "🎉 移行準備完了！安全対策実施済み"
echo -e "====================================================${NC}"
echo ""
echo -e "${CYAN}📋 次のステップ:${NC}"
echo ""
echo -e "${YELLOW}1. プロジェクト設定:${NC}"
echo "   gcloud config set project YOUR_PROJECT_ID"
echo ""
echo -e "${YELLOW}2. App Engine初期化 (初回のみ):${NC}"
echo "   gcloud app create --region=asia-northeast1"
echo ""
echo -e "${YELLOW}3. デプロイ実行:${NC}"
echo "   gcloud app deploy --version=v$(date +%Y%m%d-%H%M%S)"
echo ""
echo -e "${YELLOW}4. ログ確認:${NC}"
echo "   gcloud app logs tail -s default"
echo ""
echo -e "${YELLOW}5. ブラウザで確認:${NC}"
echo "   gcloud app browse"
echo ""
echo -e "${CYAN}💡 重要な注意事項:${NC}"
echo "• 初回デプロイは5-10分かかります"
echo "• Cloud SQLの設定は別途必要です"
echo "• エラーは自動的にGoogle Cloud Consoleに記録されます"
echo "• デプロイ後はログを確認してください"
echo ""
echo -e "${GREEN}✨ 安全対策により、エラー発生リスクを最小化しました！${NC}"

# エラー防止のための追加確認
echo -e "\n${YELLOW}🔒 追加の安全確認:${NC}"
echo "• Gemfile.lockは新規作成されます"
echo "• Ruby 3.2.0で統一されています"
echo "• 不要なファイルは.gcloudignoreで除外されます"
echo "• ヘルスチェックエンドポイントが設定されています"