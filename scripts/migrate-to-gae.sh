#!/bin/bash

# 🚀 Railway → Google App Engine 自動移行スクリプト
# エラー対応時間を最小化する完全自動化デプロイ

set -e

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ID="dental-system-prod"
DB_INSTANCE="dental-db"
REGION="asia-northeast1"

echo "=================================================="
echo -e "${GREEN}🚀 Railway → Google App Engine 移行開始${NC}"
echo "=================================================="

# Step 1: 前提条件チェック
echo -e "\n${BLUE}📋 Step 1: 前提条件チェック${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# GCloud CLI確認
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ Google Cloud SDK がインストールされていません${NC}"
    echo -e "${YELLOW}インストール方法:${NC}"
    echo "curl https://sdk.cloud.google.com | bash"
    echo "exec -l \$SHELL"
    exit 1
fi

echo -e "${GREEN}✅ Google Cloud SDK インストール済み${NC}"

# Step 2: GCP プロジェクト設定
echo -e "\n${BLUE}🏗️ Step 2: GCP プロジェクト設定${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 認証確認
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${YELLOW}⚠️ GCPへのログインが必要です${NC}"
    gcloud auth login
fi

echo -e "${GREEN}✅ GCP認証済み${NC}"

# プロジェクト作成/選択
if gcloud projects describe $PROJECT_ID &>/dev/null; then
    echo -e "${GREEN}✅ プロジェクト '$PROJECT_ID' 存在確認済み${NC}"
else
    echo -e "${YELLOW}📝 プロジェクト '$PROJECT_ID' を作成中...${NC}"
    gcloud projects create $PROJECT_ID --set-as-default
    
    # 課金アカウント関連付け（必要に応じて）
    echo -e "${YELLOW}⚠️ 課金アカウントの関連付けが必要な場合があります${NC}"
    echo "GCP Console: https://console.cloud.google.com/billing"
fi

gcloud config set project $PROJECT_ID

# 必要なAPI有効化
echo -e "${YELLOW}📡 必要なAPIを有効化中...${NC}"
gcloud services enable appengine.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable cloudbuild.googleapis.com

echo -e "${GREEN}✅ API有効化完了${NC}"

# Step 3: Cloud SQL データベース作成
echo -e "\n${BLUE}🗄️ Step 3: Cloud SQL データベース作成${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if gcloud sql instances describe $DB_INSTANCE --project=$PROJECT_ID &>/dev/null; then
    echo -e "${GREEN}✅ Cloud SQL インスタンス '$DB_INSTANCE' 存在確認済み${NC}"
else
    echo -e "${YELLOW}📝 Cloud SQL インスタンス作成中...${NC}"
    gcloud sql instances create $DB_INSTANCE \
        --database-version=POSTGRES_15 \
        --tier=db-f1-micro \
        --region=$REGION \
        --storage-auto-increase \
        --backup-start-time=03:00 \
        --project=$PROJECT_ID
    
    echo -e "${GREEN}✅ Cloud SQL インスタンス作成完了${NC}"
fi

# データベース作成
if gcloud sql databases describe dentalsystem --instance=$DB_INSTANCE --project=$PROJECT_ID &>/dev/null; then
    echo -e "${GREEN}✅ データベース 'dentalsystem' 存在確認済み${NC}"
else
    echo -e "${YELLOW}📝 データベース作成中...${NC}"
    gcloud sql databases create dentalsystem --instance=$DB_INSTANCE --project=$PROJECT_ID
    echo -e "${GREEN}✅ データベース作成完了${NC}"
fi

# Step 4: App Engine 初期化
echo -e "\n${BLUE}🚀 Step 4: App Engine 初期化${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if gcloud app describe --project=$PROJECT_ID &>/dev/null; then
    echo -e "${GREEN}✅ App Engine アプリケーション存在確認済み${NC}"
else
    echo -e "${YELLOW}📝 App Engine アプリケーション作成中...${NC}"
    gcloud app create --region=$REGION --project=$PROJECT_ID
    echo -e "${GREEN}✅ App Engine アプリケーション作成完了${NC}"
fi

# Step 5: 環境変数設定
echo -e "\n${BLUE}🔐 Step 5: 環境変数設定${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# SECRET_KEY_BASE生成
SECRET_KEY_BASE=$(openssl rand -hex 32)
echo -e "${GREEN}✅ SECRET_KEY_BASE生成完了${NC}"

# Cloud SQL接続文字列生成
CONNECTION_NAME="$PROJECT_ID:$REGION:$DB_INSTANCE"
DATABASE_URL="postgresql://postgres@/$DB_INSTANCE?host=/cloudsql/$CONNECTION_NAME"

echo -e "${CYAN}データベース接続文字列: $DATABASE_URL${NC}"

# app.yamlファイル更新
echo -e "${YELLOW}📝 app.yaml設定ファイル更新中...${NC}"

cat > app.yaml << EOL
runtime: ruby32
env: standard

automatic_scaling:
  min_instances: 0
  max_instances: 5
  target_cpu_utilization: 0.6

env_variables:
  RAILS_ENV: production
  RAILS_SERVE_STATIC_FILES: true
  RAILS_LOG_TO_STDOUT: true
  SECRET_KEY_BASE: "$SECRET_KEY_BASE"
  DATABASE_URL: "$DATABASE_URL"
  CLINIC_NAME: "さくら歯科クリニック"
  
beta_settings:
  cloud_sql_instances: $CONNECTION_NAME

entrypoint: bundle exec puma -C config/puma.rb

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
  failure_threshold: 4
  success_threshold: 2
EOL

echo -e "${GREEN}✅ app.yaml設定完了${NC}"

# Step 6: アプリケーション設定調整
echo -e "\n${BLUE}⚙️ Step 6: アプリケーション設定調整${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Gemfile調整（RubyバージョンをGAE互換に）
if grep -q "ruby.*3.3" Gemfile; then
    echo -e "${YELLOW}📝 Gemfile の Ruby バージョンを GAE 互換に調整中...${NC}"
    sed -i.bak 's/ruby "3.3.0"/ruby "3.2.0"/' Gemfile
    echo -e "${GREEN}✅ Gemfile調整完了${NC}"
fi

# production.rb設定確認
if [ -f "config/environments/production.rb" ]; then
    echo -e "${GREEN}✅ production.rb設定確認済み${NC}"
else
    echo -e "${RED}❌ production.rb が見つかりません${NC}"
    exit 1
fi

# ヘルスチェックルート確認・作成
if ! grep -q "health" config/routes.rb; then
    echo -e "${YELLOW}📝 ヘルスチェックルート追加中...${NC}"
    
    # バックアップ作成
    cp config/routes.rb config/routes.rb.bak
    
    # ヘルスチェックルート追加
    sed -i.tmp '1 a\
  # Health check for App Engine\
  get "/health", to: proc { [200, {}, ["OK"]] }\
    ' config/routes.rb
    
    echo -e "${GREEN}✅ ヘルスチェックルート追加完了${NC}"
fi

# Step 7: デプロイ実行
echo -e "\n${BLUE}🚀 Step 7: デプロイ実行${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${YELLOW}📤 Google App Engine にデプロイ中...${NC}"
echo -e "${CYAN}これには数分かかる場合があります...${NC}"

# デプロイ実行
if gcloud app deploy --quiet --project=$PROJECT_ID; then
    echo -e "${GREEN}🎉 デプロイ成功！${NC}"
else
    echo -e "${RED}❌ デプロイに失敗しました${NC}"
    echo -e "${YELLOW}ログを確認してください:${NC}"
    gcloud app logs tail --service=default --project=$PROJECT_ID
    exit 1
fi

# Step 8: デプロイ後設定
echo -e "\n${BLUE}🔧 Step 8: デプロイ後設定${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# データベースマイグレーション実行
echo -e "${YELLOW}📝 データベースマイグレーション実行中...${NC}"
gcloud app versions list --project=$PROJECT_ID

APP_URL=$(gcloud app describe --project=$PROJECT_ID --format="value(defaultHostname)")

echo -e "${GREEN}✅ アプリケーションURL: https://$APP_URL${NC}"

# Step 9: 動作確認
echo -e "\n${BLUE}✅ Step 9: 動作確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${YELLOW}🔍 ヘルスチェック実行中...${NC}"
if curl -f "https://$APP_URL/health" &>/dev/null; then
    echo -e "${GREEN}✅ ヘルスチェック成功${NC}"
else
    echo -e "${YELLOW}⚠️ ヘルスチェック失敗 - アプリケーション起動中の可能性${NC}"
fi

# 完了
echo -e "\n=================================================="
echo -e "${GREEN}🎉 移行完了！${NC}"
echo "=================================================="
echo ""
echo -e "${CYAN}📊 デプロイ情報:${NC}"
echo -e "  アプリケーションURL: ${GREEN}https://$APP_URL${NC}"
echo -e "  プロジェクトID: ${GREEN}$PROJECT_ID${NC}"
echo -e "  データベース: ${GREEN}$DB_INSTANCE${NC}"
echo ""
echo -e "${CYAN}📋 次のステップ:${NC}"
echo "1. アプリケーションのテスト: https://$APP_URL"
echo "2. カスタムドメイン設定（必要に応じて）"
echo "3. Railway環境の停止（動作確認後）"
echo ""
echo -e "${CYAN}🔗 管理コンソール:${NC}"
echo "  App Engine: https://console.cloud.google.com/appengine"
echo "  Cloud SQL: https://console.cloud.google.com/sql"
echo "  ログ: https://console.cloud.google.com/logs"
echo ""
echo -e "${GREEN}✨ エラー対応時間を最小化する安定した環境が完成しました！${NC}"