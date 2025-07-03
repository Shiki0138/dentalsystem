#!/bin/bash

echo "=== 🚀 Railway Beta デプロイメント実行 ==="
echo ""
echo "このスクリプトはRailwayへのデプロイに必要なコマンドを順次実行します。"
echo "各ステップで対話的な入力が必要な場合があります。"
echo ""

# 色付き出力関数
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

# 環境変数設定
echo "📋 環境変数を設定中..."
export RAILS_ENV=production
export BETA_MODE=true
export BETA_ACCESS_CODE=dental2024beta
export RAILS_SERVE_STATIC_FILES=true
export RAILS_LOG_TO_STDOUT=true
export SECRET_KEY_BASE=$(openssl rand -hex 64)

success "環境変数設定完了"
echo ""

# Railway CLIの確認
echo "🔍 Railway CLIの確認..."
if ! command -v railway &> /dev/null; then
    error "Railway CLIがインストールされていません"
    echo "以下のコマンドでインストールしてください："
    echo "curl -fsSL https://railway.app/install.sh | sh"
    exit 1
fi
success "Railway CLI確認済み"
echo ""

# デプロイ前チェック
echo "📂 デプロイ前チェック..."
files_to_check=(
    "Dockerfile"
    "railway.json"
    "Gemfile.lock"
    ".env.production"
)

all_ok=true
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        success "$file ✓"
    else
        error "$file が見つかりません"
        all_ok=false
    fi
done

if [ "$all_ok" = false ]; then
    error "必要なファイルが不足しています"
    exit 1
fi
echo ""

# デプロイ実行
echo "🚀 Railwayデプロイを開始します..."
echo ""

# Step 1: Railway ログイン
warning "Step 1: Railwayにログイン"
echo "実行コマンド: railway login"
echo "ブラウザが開きます。Railwayアカウントでログインしてください。"
echo ""
read -p "準備ができたらEnterキーを押してください..."
railway login

# Step 2: プロジェクト作成または選択
echo ""
warning "Step 2: プロジェクトの作成/選択"
echo "新規プロジェクトの場合: railway init"
echo "既存プロジェクトの場合: railway link"
echo ""
read -p "新規プロジェクトを作成しますか？ (y/n): " new_project

if [ "$new_project" = "y" ]; then
    railway init
else
    railway link
fi

# Step 3: PostgreSQL追加
echo ""
warning "Step 3: PostgreSQLサービスの追加"
echo "実行コマンド: railway add"
echo "PostgreSQLを選択してください"
echo ""
read -p "準備ができたらEnterキーを押してください..."
railway add

# Step 4: 環境変数設定
echo ""
warning "Step 4: 環境変数の設定"
echo "以下の環境変数をRailwayに設定します..."
echo ""

railway variables set RAILS_ENV=production
railway variables set BETA_MODE=true
railway variables set BETA_ACCESS_CODE=dental2024beta
railway variables set RAILS_SERVE_STATIC_FILES=true
railway variables set RAILS_LOG_TO_STDOUT=true
railway variables set SECRET_KEY_BASE=$SECRET_KEY_BASE
railway variables set WEB_CONCURRENCY=2
railway variables set RAILS_MAX_THREADS=5

success "環境変数設定完了"

# Step 5: デプロイ
echo ""
warning "Step 5: アプリケーションのデプロイ"
echo "実行コマンド: railway up"
echo ""
read -p "デプロイを開始します。準備ができたらEnterキーを押してください..."
railway up

# Step 6: デプロイ状態確認
echo ""
warning "デプロイ状態を確認中..."
echo "デプロイが完了するまで数分かかります..."
echo ""

# Step 7: マイグレーション
echo ""
warning "Step 6: データベースマイグレーション"
echo "デプロイが完了したら、以下のコマンドを実行してください："
echo ""
echo "railway run rails db:create"
echo "railway run rails db:migrate"
echo "railway run rails beta:setup"
echo ""

# Step 8: URL確認
echo ""
warning "Step 7: アプリケーションURLの確認"
echo "以下のコマンドでURLを確認できます："
echo "railway domain"
echo ""

# 完了メッセージ
echo ""
success "🎉 デプロイ設定が完了しました！"
echo ""
echo "📝 次のステップ："
echo "1. デプロイの完了を待つ（railway logs でログ確認）"
echo "2. データベースのセットアップを実行"
echo "3. railway domain でURLを確認"
echo "4. ベータアクセスコード: dental2024beta"
echo ""
echo "🔍 便利なコマンド："
echo "- ログ確認: railway logs"
echo "- 環境変数一覧: railway variables"
echo "- サービス状態: railway status"
echo ""