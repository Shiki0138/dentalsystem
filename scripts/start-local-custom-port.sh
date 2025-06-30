#!/bin/bash

# ==================================================
# 歯科クリニックシステム カスタムポート起動
# ==================================================

# デフォルトポート設定（引数で変更可能）
PORT=${1:-3456}

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}===================================================${NC}"
echo -e "${PURPLE}    歯科クリニックシステム 起動${NC}"
echo -e "${PURPLE}    ポート: $PORT${NC}"
echo -e "${PURPLE}===================================================${NC}"

# ポート使用状況確認
check_port() {
    echo -e "\n${BLUE}=== ポート確認 ===${NC}"
    
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${RED}❌ ポート $PORT は既に使用中です${NC}"
        echo -e "${YELLOW}別のポートを指定してください:${NC}"
        echo -e "${CYAN}./scripts/start-local-custom-port.sh 3457${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ ポート $PORT は利用可能です${NC}"
    fi
}

# PostgreSQL確認
check_postgres() {
    echo -e "\n${BLUE}=== PostgreSQL確認 ===${NC}"
    
    if pg_isready > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PostgreSQL: 稼働中${NC}"
    else
        echo -e "${YELLOW}PostgreSQL起動中...${NC}"
        brew services start postgresql 2>/dev/null || {
            echo -e "${YELLOW}PostgreSQLを手動で起動してください:${NC}"
            echo -e "${CYAN}pg_ctl -D /usr/local/var/postgres start${NC}"
            exit 1
        }
        sleep 3
    fi
}

# Redis確認
check_redis() {
    echo -e "\n${BLUE}=== Redis確認 ===${NC}"
    
    if redis-cli ping > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Redis: 稼働中${NC}"
    else
        echo -e "${YELLOW}Redis起動中...${NC}"
        brew services start redis 2>/dev/null || {
            echo -e "${YELLOW}Redisを手動で起動してください:${NC}"
            echo -e "${CYAN}redis-server${NC}"
            exit 1
        }
        sleep 3
    fi
}

# 環境設定
setup_environment() {
    echo -e "\n${BLUE}=== 環境設定 ===${NC}"
    
    # .envファイル確認
    if [ ! -f ".env" ]; then
        echo -e "${CYAN}.envファイル作成中...${NC}"
        cp .env.example .env
        
        # ローカル用設定追加
        cat >> .env << EOF

# ローカル環境設定
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USERNAME=$USER
DATABASE_PASSWORD=
REDIS_URL=redis://localhost:6379/0
PORT=$PORT
EOF
        echo -e "${GREEN}✅ .envファイル作成完了${NC}"
    fi
}

# データベース確認
check_database() {
    echo -e "\n${BLUE}=== データベース確認 ===${NC}"
    
    # データベース存在確認
    if psql -lqt | cut -d \| -f 1 | grep -qw dental_system_development; then
        echo -e "${GREEN}✅ データベース: 存在${NC}"
    else
        echo -e "${CYAN}データベース作成中...${NC}"
        createdb dental_system_development
        
        # マイグレーション実行
        echo -e "${CYAN}マイグレーション実行中...${NC}"
        ruby bin/rails db:migrate RAILS_ENV=development
    fi
    
    # テストユーザー作成
    echo -e "${CYAN}テストユーザー確認中...${NC}"
    ruby bin/rails runner "
      # 受付スタッフユーザー作成
      staff = User.find_or_create_by(email: 'staff@dental.jp') do |u|
        u.password = 'password123'
        u.name = '鈴木花子（受付）'
        u.role = 'staff'
      end
      
      # 歯科医師ユーザー作成
      dentist = User.find_or_create_by(email: 'dentist@dental.jp') do |u|
        u.password = 'password123'
        u.name = '山田太郎（歯科医師）'
        u.role = 'dentist'
      end
      
      # 管理者ユーザー作成
      admin = User.find_or_create_by(email: 'admin@dental.jp') do |u|
        u.password = 'password123'
        u.name = '管理者'
        u.role = 'admin'
      end
      
      puts '✅ テストユーザー準備完了'
      
      # サンプル患者データ（少数）
      3.times do |i|
        Patient.find_or_create_by(email: \"patient#{i+1}@example.com\") do |p|
          p.name = \"テスト患者#{i+1}\"
          p.phone = \"03-0000-000#{i+1}\"
          p.birth_date = 30.years.ago
          p.gender = ['male', 'female'].sample
          p.address = \"東京都渋谷区テスト#{i+1}丁目\"
        end
      end
      
      puts '✅ サンプル患者データ準備完了'
    " 2>/dev/null || echo "データ準備スキップ"
}

# サーバー起動
start_server() {
    echo -e "\n${GREEN}===================================================${NC}"
    echo -e "${GREEN}    歯科クリニックシステム 起動準備完了！${NC}"
    echo -e "${GREEN}===================================================${NC}"
    
    echo -e "\n${PURPLE}🌐 アクセス情報${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}URL:${NC} ${CYAN}http://localhost:$PORT${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "\n${PURPLE}👤 ログイン情報${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}受付スタッフ:${NC} ${CYAN}staff@dental.jp / password123${NC}"
    echo -e "${YELLOW}歯科医師:${NC}     ${CYAN}dentist@dental.jp / password123${NC}"
    echo -e "${YELLOW}管理者:${NC}       ${CYAN}admin@dental.jp / password123${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "\n${PURPLE}📱 主要画面${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}ダッシュボード:${NC} ${CYAN}http://localhost:$PORT/dashboard${NC}"
    echo -e "${YELLOW}予約管理:${NC}       ${CYAN}http://localhost:$PORT/appointments${NC}"
    echo -e "${YELLOW}患者管理:${NC}       ${CYAN}http://localhost:$PORT/patients${NC}"
    echo -e "${YELLOW}新規予約:${NC}       ${CYAN}http://localhost:$PORT/book/manual${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "\n${YELLOW}📌 操作方法${NC}"
    echo -e "  1. 上記URLをブラウザで開く"
    echo -e "  2. 受付スタッフでログイン"
    echo -e "  3. ダッシュボードで本日の予約確認"
    echo -e "  4. 各機能をテスト"
    
    echo -e "\n${RED}停止: Ctrl+C${NC}"
    echo -e "${YELLOW}※起動に時間がかかる場合があります${NC}\n"
    
    # Railsサーバー起動
    echo -e "${GREEN}Railsサーバー起動中...${NC}"
    ruby bin/rails server -b 0.0.0.0 -p $PORT
}

# メイン実行
main() {
    check_port
    check_postgres
    check_redis
    setup_environment
    check_database
    start_server
}

# ポート番号の妥当性チェック
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
    echo -e "${RED}エラー: 無効なポート番号です${NC}"
    echo -e "${YELLOW}1024-65535の範囲で指定してください${NC}"
    exit 1
fi

# 実行
main