#!/bin/bash

echo "🚨 緊急Ruby環境修正スクリプト"
echo "worker2からのエラー報告に対する緊急対応"
echo ""

# 色付き出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

error() { echo -e "${RED}❌ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# 現在の状況確認
echo -e "${BLUE}1️⃣ 現在の環境確認${NC}"
echo "システムRubyバージョン: $(ruby --version)"
echo "要求されるRubyバージョン: $(cat .ruby-version)"
echo "Gemfile指定バージョン: $(grep 'ruby' Gemfile | head -1)"
echo ""

# 問題の特定
if [[ "$(ruby --version)" == *"2.6.10"* ]]; then
    error "Ruby 2.6.10を使用中（要求: 3.2.0）"
    echo "この環境不整合がデプロイエラーの原因です"
else
    success "Ruby環境は適切です"
    exit 0
fi

echo ""
echo -e "${BLUE}2️⃣ 解決方法の選択${NC}"
echo "以下の解決方法から選択してください："
echo ""
echo "A) rbenv/rvm を使用したRuby 3.2.0インストール（推奨）"
echo "B) Dockerを使用した環境分離（即座に利用可能）"
echo "C) システムRubyの更新（非推奨）"
echo ""

read -p "選択肢を入力してください (A/B/C): " choice

case $choice in
    A|a)
        echo ""
        echo -e "${BLUE}Option A: rbenv を使用したRuby 3.2.0 セットアップ${NC}"
        
        # rbenvの確認
        if command -v rbenv &> /dev/null; then
            info "rbenvが検出されました"
        else
            error "rbenvがインストールされていません"
            echo "インストール方法："
            echo "brew install rbenv ruby-build"
            echo "echo 'eval \"\$(rbenv init -)\"' >> ~/.zshrc"
            echo "source ~/.zshrc"
            exit 1
        fi
        
        # Ruby 3.2.0のインストール
        info "Ruby 3.2.0をインストール中..."
        rbenv install 3.2.0
        rbenv local 3.2.0
        
        # 環境確認
        if [[ "$(rbenv version)" == *"3.2.0"* ]]; then
            success "Ruby 3.2.0のセットアップ完了"
            
            # Bundlerの再インストール
            gem install bundler
            bundle install
            
            success "環境修正完了"
        else
            error "Ruby 3.2.0のセットアップに失敗しました"
            exit 1
        fi
        ;;
        
    B|b)
        echo ""
        echo -e "${BLUE}Option B: Docker環境でのデプロイ実行${NC}"
        
        # Dockerの確認
        if command -v docker &> /dev/null; then
            info "Dockerが検出されました"
        else
            error "Dockerがインストールされていません"
            echo "Docker Desktopをインストールしてください"
            exit 1
        fi
        
        # Docker用のデプロイスクリプト作成
        cat > docker-deploy.sh << 'EOF'
#!/bin/bash
echo "🐳 Dockerを使用したセーフデプロイ"

# Dockerビルド
docker build -t dentalsystem .

# 環境変数チェック（Docker内）
docker run --rm dentalsystem bundle exec rails deployment:check_env

# Railwayデプロイ（Docker使用）
railway up

echo "✅ Dockerデプロイ完了"
EOF
        
        chmod +x docker-deploy.sh
        success "Dockerデプロイスクリプト作成完了"
        info "./docker-deploy.sh を実行してデプロイしてください"
        ;;
        
    C|c)
        echo ""
        warning "Option C: システムRuby更新は推奨されません"
        echo "macOSシステムの安定性に影響する可能性があります"
        echo "Option AまたはBを選択することを強く推奨します"
        ;;
        
    *)
        error "無効な選択です"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}3️⃣ 修正後の確認${NC}"
echo "以下のコマンドで環境を確認してください："
echo ""
echo "ruby --version    # Ruby 3.2.0 であることを確認"
echo "bundle install    # 依存関係の再インストール"
echo "rails deployment:check_env    # 環境変数チェック"
echo ""

# ログ記録
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [FIX] [dentalsystem] Ruby環境修正スクリプト実行 - 選択: $choice" >> development/development_log.txt

echo -e "${GREEN}🛠️ Ruby環境修正作業完了${NC}"
echo "修正後、セーフデプロイスクリプトを再実行してください"