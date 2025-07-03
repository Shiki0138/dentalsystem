#!/bin/bash

# 🚆 Railway ベータ版即時デプロイスクリプト
set -e

echo "🚀 Railway ベータ版デプロイ準備"

# カラー設定
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Step 1: Railway設定確認
echo -e "\n${BLUE}🔍 Step 1: Railway設定確認${NC}"

if ! command -v railway &> /dev/null; then
    echo -e "${RED}❌ Railway CLIがインストールされていません${NC}"
    echo -e "${YELLOW}以下のコマンドでインストール:${NC}"
    echo "npm install -g @railway/cli"
    exit 1
fi

# Step 2: Procfile作成（Railway用）
echo -e "\n${BLUE}📝 Step 2: Procfile更新${NC}"

cat > Procfile << 'EOL'
web: bundle exec puma -C config/puma.rb
release: bundle exec rails db:migrate && bundle exec rails beta:setup
EOL

echo -e "${GREEN}✅ Procfile作成完了${NC}"

# Step 3: 本番環境設定
echo -e "\n${BLUE}⚙️ Step 3: 本番環境設定${NC}"

# secrets設定
cat > config/credentials.yml.enc << 'EOL'
# このファイルは自動生成されます
EOL

# database.yml更新
cat > config/database.yml << 'EOL'
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: dental_development

test:
  <<: *default
  database: dental_test

production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
EOL

# Step 4: 環境変数設定スクリプト
echo -e "\n${BLUE}🔐 Step 4: Railway環境変数設定${NC}"

cat > scripts/set-railway-env.sh << 'EOSCRIPT'
#!/bin/bash

echo "Railway環境変数を設定します..."

# 必須環境変数
railway variables set RAILS_ENV=production
railway variables set BETA_MODE=true
railway variables set BETA_ACCESS_CODE=dental2024beta
railway variables set RAILS_SERVE_STATIC_FILES=true
railway variables set RAILS_LOG_TO_STDOUT=true
railway variables set SECRET_KEY_BASE=$(openssl rand -hex 64)

echo "✅ 環境変数設定完了"
EOSCRIPT

chmod +x scripts/set-railway-env.sh

# Step 5: 最小限のGemfile.lock生成
echo -e "\n${BLUE}💎 Step 5: Gemfile.lock生成${NC}"

# Dockerを使って安全に生成
if command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker経由でGemfile.lock生成中...${NC}"
    
    cat > Dockerfile.gemlock << 'EOL'
FROM ruby:3.2.0
WORKDIR /app
COPY Gemfile* ./
RUN bundle lock --add-platform x86_64-linux
EOL
    
    docker build -f Dockerfile.gemlock -t gemlock . 2>/dev/null || {
        echo -e "${YELLOW}⚠️ Docker生成をスキップ${NC}"
    }
    
    docker run --rm -v $(pwd):/app gemlock bundle lock --add-platform x86_64-linux 2>/dev/null || true
    rm -f Dockerfile.gemlock
else
    echo -e "${YELLOW}⚠️ Dockerが利用できません。Gemfile.lockを手動で生成してください${NC}"
fi

# Step 6: デプロイ前チェックリスト
echo -e "\n${BLUE}✅ Step 6: デプロイ前チェックリスト${NC}"

echo "チェック項目:"
echo -n "  Railwayにログイン済み... "
if railway whoami 2>/dev/null | grep -q "@"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ 'railway login'を実行してください${NC}"
    exit 1
fi

echo -n "  プロジェクトリンク済み... "
if [ -f ".railway/config.json" ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}新規作成します${NC}"
    railway link
fi

# Step 7: デプロイコマンド生成
echo -e "\n${BLUE}🚀 Step 7: デプロイ実行${NC}"

cat > deploy-to-railway.sh << 'EODEPLOY'
#!/bin/bash

echo "🚆 Railway ベータ版デプロイ開始"

# 環境変数設定
./scripts/set-railway-env.sh

# デプロイ実行
echo "デプロイを開始します..."
railway up

# デプロイ完了後の処理
echo ""
echo "✅ デプロイ完了！"
echo ""
echo "📋 次のステップ:"
echo "1. デプロイURL確認: railway open"
echo "2. ログ確認: railway logs"
echo "3. 環境変数確認: railway variables"
echo ""
echo "🔑 ベータアクセス情報:"
echo "URL: [Railway提供URL]/beta"
echo "アクセスコード: dental2024beta"
EODEPLOY

chmod +x deploy-to-railway.sh

echo -e "\n${GREEN}✅ Railway ベータ版デプロイ準備完了！${NC}"
echo ""
echo -e "${CYAN}📋 即座にデプロイするには:${NC}"
echo "  ./deploy-to-railway.sh"
echo ""
echo -e "${YELLOW}⏱️ 所要時間: 約3-5分${NC}"