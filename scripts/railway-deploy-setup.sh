#!/bin/bash

# 🚀 Railway ワンコマンドデプロイ準備スクリプト

echo "=================================================="
echo "🚀 Railway デプロイ準備チェック"
echo "=================================================="

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""

# 1. 必須ファイル確認
echo -e "${BLUE}📁 必須ファイル確認${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_file() {
    if [ -f "$1" ]; then
        echo -e "✅ $1"
    else
        echo -e "❌ $1 ${RED}(作成が必要)${NC}"
        return 1
    fi
}

FILES_OK=true
check_file "railway.toml" || FILES_OK=false
check_file "Procfile" || FILES_OK=false
check_file ".env.production" || FILES_OK=false
check_file "app/models/application_record.rb" || FILES_OK=false
check_file "config/environments/production.rb" || FILES_OK=false
check_file "config/initializers/devise.rb" || FILES_OK=false

echo ""

# 2. Git状態確認
echo -e "${BLUE}📤 Git リポジトリ状態${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if git status --porcelain | grep -q .; then
    echo -e "${YELLOW}⚠️  未コミットの変更があります${NC}"
    echo "   以下のコマンドでコミットしてください:"
    echo -e "   ${CYAN}git add . && git commit -m 'feat: デプロイ準備'${NC}"
    echo -e "   ${CYAN}git push origin master${NC}"
    GIT_OK=false
else
    echo -e "✅ Git リポジトリはクリーンです"
    GIT_OK=true
fi

# リモートリポジトリ確認
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if [ -n "$REMOTE_URL" ]; then
    echo -e "✅ GitHub リポジトリ: ${CYAN}$REMOTE_URL${NC}"
else
    echo -e "❌ GitHubリモートリポジトリが設定されていません"
    GIT_OK=false
fi

echo ""

# 3. Railway CLI確認
echo -e "${BLUE}🚄 Railway CLI${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v railway &> /dev/null; then
    echo -e "✅ Railway CLI インストール済み"
    RAILWAY_VERSION=$(railway --version 2>/dev/null || echo "不明")
    echo -e "   バージョン: ${CYAN}$RAILWAY_VERSION${NC}"
    CLI_OK=true
else
    echo -e "❌ Railway CLI がインストールされていません"
    echo -e "   インストール: ${CYAN}npm install -g @railway/cli${NC}"
    CLI_OK=false
fi

echo ""

# 4. シークレットキー生成
echo -e "${BLUE}🔐 シークレットキー生成${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "SECRET_KEY_BASE (Railwayで設定してください):"
echo -e "${GREEN}$(openssl rand -hex 32)${NC}"

echo ""

# 5. デプロイ準備状況サマリー
echo -e "${BLUE}📊 デプロイ準備状況サマリー${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$FILES_OK" = true ] && [ "$GIT_OK" = true ]; then
    echo -e "${GREEN}🎉 デプロイ準備完了！${NC}"
    echo ""
    echo -e "${YELLOW}次のステップ:${NC}"
    echo "1. Railway.app でアカウント作成"
    echo "2. 'New Project' → 'Deploy from GitHub repo' 選択"
    echo "3. リポジトリ選択してデプロイ開始"
    echo "4. PostgreSQL追加"
    echo "5. 環境変数設定"
    echo ""
    echo -e "${CYAN}詳細手順: RAILWAY_DEPLOY_GUIDE.md を参照${NC}"
else
    echo -e "${RED}❌ デプロイ準備が不完全です${NC}"
    echo ""
    echo -e "${YELLOW}対処が必要な項目:${NC}"
    [ "$FILES_OK" = false ] && echo "- 必須ファイルの作成"
    [ "$GIT_OK" = false ] && echo "- Git コミット・プッシュ"
    echo ""
fi

echo ""
echo "=================================================="
echo -e "${GREEN}🔗 参考リンク${NC}"
echo "Railway公式: https://railway.app"
echo "ドキュメント: https://docs.railway.app"
echo "GitHub: https://github.com/Shiki0138/dentalsystem"
echo "=================================================="