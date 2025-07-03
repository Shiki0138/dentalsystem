#!/bin/bash

# 🐳 Docker経由でのGAEデプロイスクリプト
# Ruby環境の問題を回避

set -euo pipefail

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${MAGENTA}===================================================="
echo -e "🐳 Docker経由でのGAEデプロイ準備"
echo -e "====================================================${NC}"

# Step 1: Dockerfile作成
echo -e "\n${BLUE}📝 Step 1: Dockerfile作成${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > Dockerfile << 'EOL'
# Ruby 3.2.0 (GAE互換)
FROM ruby:3.2.0-slim

# 必要なパッケージのインストール
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    libpq-dev \
    nodejs \
    npm \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリ設定
WORKDIR /app

# Gemfileコピー
COPY Gemfile Gemfile.lock* ./

# Bundle install
RUN bundle install --deployment --without development test

# アプリケーションコピー
COPY . .

# アセットプリコンパイル
RUN RAILS_ENV=production bundle exec rails assets:precompile || true

# ポート設定
EXPOSE 8080

# 起動コマンド
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "8080", "-e", "production"]
EOL

echo -e "${GREEN}✅ Dockerfile作成完了${NC}"

# Step 2: Gemfile.lock生成（Docker内で）
echo -e "\n${BLUE}🔧 Step 2: Gemfile.lock生成${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 一時的なDockerfileを作成
cat > Dockerfile.bundle << 'EOL'
FROM ruby:3.2.0-slim
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev git
WORKDIR /app
COPY Gemfile ./
RUN bundle install
EOL

echo -e "${YELLOW}📦 Docker内でGemfile.lock生成中...${NC}"
docker build -f Dockerfile.bundle -t temp-bundle . || {
    echo -e "${RED}❌ Docker buildに失敗しました${NC}"
    echo -e "${YELLOW}Dockerがインストールされているか確認してください${NC}"
    exit 1
}

# Gemfile.lockを取得
docker run --rm -v $(pwd):/app temp-bundle bundle lock --lockfile=/app/Gemfile.lock

echo -e "${GREEN}✅ Gemfile.lock生成完了${NC}"

# Step 3: cloudbuild.yaml作成
echo -e "\n${BLUE}☁️ Step 3: cloudbuild.yaml作成${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > cloudbuild.yaml << 'EOL'
steps:
  # Dockerイメージのビルド
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/dental-system:$BUILD_ID', '.']

  # イメージのプッシュ
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/dental-system:$BUILD_ID']

  # App Engineへのデプロイ
  - name: 'gcr.io/google-appengine/exec-wrapper'
    args: ['app', 'deploy', '--image-url=gcr.io/$PROJECT_ID/dental-system:$BUILD_ID']

timeout: 1200s
EOL

echo -e "${GREEN}✅ cloudbuild.yaml作成完了${NC}"

# Step 4: 最小限のapp.yaml更新
echo -e "\n${BLUE}📝 Step 4: app.yaml更新（Docker対応）${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > app.yaml << 'EOL'
runtime: custom
env: flex

# 最小リソース設定
resources:
  cpu: 1
  memory_gb: 0.5
  disk_size_gb: 10

# 自動スケーリング
automatic_scaling:
  min_num_instances: 1
  max_num_instances: 2
  cool_down_period_sec: 180
  cpu_utilization:
    target_utilization: 0.6

# 環境変数
env_variables:
  RAILS_ENV: production
  RAILS_SERVE_STATIC_FILES: true
  RAILS_LOG_TO_STDOUT: true

# ヘルスチェック
readiness_check:
  path: "/health"
  check_interval_sec: 5
  timeout_sec: 4
  failure_threshold: 2
  success_threshold: 2

liveness_check:
  path: "/health"
  check_interval_sec: 30
  timeout_sec: 4
  failure_threshold: 2
  success_threshold: 2
EOL

echo -e "${GREEN}✅ app.yaml更新完了${NC}"

# Step 5: .dockerignore作成
echo -e "\n${BLUE}📄 Step 5: .dockerignore作成${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > .dockerignore << 'EOL'
# Git
.git
.gitignore

# Rails
*.log
/tmp
/log
/storage
/public/packs
/public/packs-test
/node_modules
/yarn-error.log
yarn-debug.log*
.byebug_history

# Test
/coverage
/spec
/test

# Development
.env*
config/master.key
config/credentials/*.key

# Docker
Dockerfile*
docker-compose*

# Docs
*.md
docs/

# macOS
.DS_Store

# Editor
.idea/
.vscode/
*.swp
*.swo

# Railway
railway.toml
nixpacks.toml
Procfile

# Backup
backup_*/
EOL

echo -e "${GREEN}✅ .dockerignore作成完了${NC}"

# クリーンアップ
rm -f Dockerfile.bundle
docker rmi temp-bundle 2>/dev/null || true

# 完了メッセージ
echo -e "\n${MAGENTA}===================================================="
echo -e "🎉 Docker経由でのGAEデプロイ準備完了！"
echo -e "====================================================${NC}"
echo ""
echo -e "${CYAN}📋 次のステップ:${NC}"
echo ""
echo -e "${YELLOW}1. プロジェクト設定:${NC}"
echo "   gcloud config set project YOUR_PROJECT_ID"
echo ""
echo -e "${YELLOW}2. APIを有効化:${NC}"
echo "   gcloud services enable appengine.googleapis.com"
echo "   gcloud services enable cloudbuild.googleapis.com"
echo ""
echo -e "${YELLOW}3. App Engine初期化 (初回のみ):${NC}"
echo "   gcloud app create --region=asia-northeast1"
echo ""
echo -e "${YELLOW}4. デプロイ実行:${NC}"
echo "   gcloud app deploy --version=v$(date +%Y%m%d-%H%M%S)"
echo ""
echo -e "${YELLOW}5. または Cloud Buildでデプロイ:${NC}"
echo "   gcloud builds submit --config cloudbuild.yaml"
echo ""
echo -e "${CYAN}💡 利点:${NC}"
echo "• ローカルのRuby環境に依存しない"
echo "• Dockerコンテナで完全に隔離された環境"
echo "• エラーが起きにくい安定したデプロイ"
echo ""
echo -e "${GREEN}✨ Ruby環境の問題を完全に回避できます！${NC}"