#!/bin/bash

# ==================================================
# 歯科クリニックシステム 簡易ローカル起動
# ==================================================

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}===================================================${NC}"
echo -e "${PURPLE}    歯科クリニックシステム 簡易起動${NC}"
echo -e "${PURPLE}===================================================${NC}"

# Phase 1: PostgreSQL確認・起動
check_postgres() {
    echo -e "\n${BLUE}=== PostgreSQL確認 ===${NC}"
    
    if command -v pg_ctl &> /dev/null; then
        echo -e "${GREEN}✅ PostgreSQL: インストール済み${NC}"
        
        # PostgreSQL起動確認
        if ! pg_isready > /dev/null 2>&1; then
            echo -e "${YELLOW}PostgreSQL起動中...${NC}"
            brew services start postgresql 2>/dev/null || {
                echo -e "${YELLOW}手動でPostgreSQLを起動してください:${NC}"
                echo -e "${CYAN}pg_ctl -D /usr/local/var/postgres start${NC}"
            }
        else
            echo -e "${GREEN}✅ PostgreSQL: 稼働中${NC}"
        fi
    else
        echo -e "${RED}❌ PostgreSQLがインストールされていません${NC}"
        echo -e "${YELLOW}Homebrewでインストール: brew install postgresql${NC}"
        exit 1
    fi
}

# Phase 2: Redis確認・起動
check_redis() {
    echo -e "\n${BLUE}=== Redis確認 ===${NC}"
    
    if command -v redis-server &> /dev/null; then
        echo -e "${GREEN}✅ Redis: インストール済み${NC}"
        
        # Redis起動確認
        if ! redis-cli ping > /dev/null 2>&1; then
            echo -e "${YELLOW}Redis起動中...${NC}"
            brew services start redis 2>/dev/null || {
                echo -e "${YELLOW}手動でRedisを起動してください:${NC}"
                echo -e "${CYAN}redis-server${NC}"
            }
        else
            echo -e "${GREEN}✅ Redis: 稼働中${NC}"
        fi
    else
        echo -e "${RED}❌ Redisがインストールされていません${NC}"
        echo -e "${YELLOW}Homebrewでインストール: brew install redis${NC}"
        exit 1
    fi
}

# Phase 3: 環境設定
setup_environment() {
    echo -e "\n${BLUE}=== 環境設定 ===${NC}"
    
    # .envファイル確認・作成
    if [ ! -f ".env" ]; then
        echo -e "${CYAN}.envファイル作成中...${NC}"
        cp .env.example .env
        
        # ローカル用設定追加
        cat >> .env << 'EOF'

# ローカル環境設定
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USERNAME=$USER
DATABASE_PASSWORD=
REDIS_URL=redis://localhost:6379/0
EOF
        echo -e "${GREEN}✅ .envファイル作成完了${NC}"
    fi
    
    # Ruby環境確認
    echo -e "${CYAN}Ruby環境: $(ruby -v)${NC}"
}

# Phase 4: Rails依存関係
setup_rails_dependencies() {
    echo -e "\n${BLUE}=== Rails依存関係セットアップ ===${NC}"
    
    # vendorディレクトリのbundleを使用
    if [ -d "vendor/bundle/ruby/3.3.0/bin" ]; then
        export PATH="$(pwd)/vendor/bundle/ruby/3.3.0/bin:$PATH"
        echo -e "${GREEN}✅ Vendor bundle使用${NC}"
    fi
    
    # rails実行可能ファイル確認
    if [ -f "bin/rails" ]; then
        echo -e "${GREEN}✅ bin/rails 存在${NC}"
    else
        echo -e "${RED}❌ bin/rails が見つかりません${NC}"
        exit 1
    fi
}

# Phase 5: データベース準備
prepare_database() {
    echo -e "\n${BLUE}=== データベース準備 ===${NC}"
    
    echo -e "${CYAN}データベース作成中...${NC}"
    createdb dental_system_development 2>/dev/null || echo "データベース既存"
    
    echo -e "${CYAN}マイグレーション実行中...${NC}"
    ruby bin/rails db:migrate RAILS_ENV=development 2>/dev/null || {
        echo -e "${YELLOW}マイグレーションスキップ${NC}"
    }
    
    # 簡易テストデータ作成
    echo -e "${CYAN}テストユーザー作成中...${NC}"
    ruby bin/rails runner "
      # 管理者ユーザー作成
      User.find_or_create_by(email: 'admin@dental.jp') do |u|
        u.password = 'password123'
        u.name = '管理者'
        u.role = 'admin'
        u.confirmed_at = Time.current
      end
      
      # 歯科医師ユーザー作成
      User.find_or_create_by(email: 'dentist@dental.jp') do |u|
        u.password = 'password123'
        u.name = '山田太郎'
        u.role = 'dentist'
        u.confirmed_at = Time.current
      end
      
      # 受付スタッフユーザー作成
      User.find_or_create_by(email: 'staff@dental.jp') do |u|
        u.password = 'password123'
        u.name = '鈴木花子'
        u.role = 'staff'
        u.confirmed_at = Time.current
      end
      
      puts '✅ テストユーザー作成完了'
    " 2>/dev/null || echo "テストユーザー作成スキップ"
}

# Phase 6: サーバー起動
start_server() {
    echo -e "\n${GREEN}===================================================${NC}"
    echo -e "${GREEN}    歯科クリニックシステム 起動準備完了！${NC}"
    echo -e "${GREEN}===================================================${NC}"
    
    echo -e "\n${YELLOW}📋 ログイン情報:${NC}"
    echo -e "  ${CYAN}管理者: admin@dental.jp / password123${NC}"
    echo -e "  ${CYAN}歯科医師: dentist@dental.jp / password123${NC}"
    echo -e "  ${CYAN}受付スタッフ: staff@dental.jp / password123${NC}"
    
    echo -e "\n${YELLOW}🌐 アクセスURL:${NC}"
    echo -e "  ${CYAN}http://localhost:3000${NC}"
    
    echo -e "\n${YELLOW}📍 主要画面:${NC}"
    echo -e "  ${CYAN}/dashboard - ダッシュボード（トップページ）${NC}"
    echo -e "  ${CYAN}/appointments - 予約管理${NC}"
    echo -e "  ${CYAN}/patients - 患者管理${NC}"
    echo -e "  ${CYAN}/book/manual - 新規予約登録${NC}"
    
    echo -e "\n${GREEN}Railsサーバー起動中...${NC}"
    echo -e "${YELLOW}停止: Ctrl+C${NC}"
    echo -e "${YELLOW}※初回起動は時間がかかる場合があります${NC}\n"
    
    # Railsサーバー起動
    ruby bin/rails server -b 0.0.0.0 -p 3000
}

# メイン実行
main() {
    check_postgres
    check_redis
    setup_environment
    setup_rails_dependencies
    prepare_database
    start_server
}

# 実行
main