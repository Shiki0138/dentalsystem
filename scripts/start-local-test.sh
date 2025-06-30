#!/bin/bash

# ==================================================
# 歯科クリニックシステム ローカルテスト環境起動
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
echo -e "${PURPLE}    歯科クリニックシステム ローカルテスト環境${NC}"
echo -e "${PURPLE}===================================================${NC}"

# Phase 1: 環境チェック
check_environment() {
    echo -e "\n${BLUE}=== Phase 1: 環境チェック ===${NC}"
    
    # Ruby環境確認
    if command -v ruby &> /dev/null; then
        RUBY_VERSION=$(ruby -v | awk '{print $2}')
        echo -e "${GREEN}✅ Ruby: $RUBY_VERSION${NC}"
    else
        echo -e "${RED}❌ Rubyがインストールされていません${NC}"
        exit 1
    fi
    
    # PostgreSQL確認
    if command -v psql &> /dev/null; then
        echo -e "${GREEN}✅ PostgreSQL: インストール済み${NC}"
    else
        echo -e "${YELLOW}⚠️ PostgreSQLが見つかりません${NC}"
        echo -e "${CYAN}Dockerを使用してPostgreSQLを起動します${NC}"
    fi
    
    # Redis確認
    if command -v redis-cli &> /dev/null; then
        echo -e "${GREEN}✅ Redis: インストール済み${NC}"
    else
        echo -e "${YELLOW}⚠️ Redisが見つかりません${NC}"
        echo -e "${CYAN}Dockerを使用してRedisを起動します${NC}"
    fi
}

# Phase 2: Docker Composeでサービス起動
setup_docker_services() {
    echo -e "\n${BLUE}=== Phase 2: Dockerサービス起動 ===${NC}"
    
    # docker-compose.yml作成
    cat > docker-compose.test.yml << 'EOF'
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: dental_system_development
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      
  redis:
    image: redis:7
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
EOF
    
    echo -e "${CYAN}PostgreSQLとRedisを起動中...${NC}"
    docker-compose -f docker-compose.test.yml up -d
    
    # サービス起動待機
    echo -e "${YELLOW}サービス起動待機中...${NC}"
    sleep 5
    
    echo -e "${GREEN}✅ Dockerサービス起動完了${NC}"
}

# Phase 3: 依存関係インストール
install_dependencies() {
    echo -e "\n${BLUE}=== Phase 3: 依存関係インストール ===${NC}"
    
    # .envファイル確認・作成
    if [ ! -f ".env" ]; then
        echo -e "${CYAN}.envファイル作成中...${NC}"
        cp .env.example .env
        
        # ローカル環境用の設定を追加
        cat >> .env << 'EOF'

# ローカルテスト環境設定
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres
REDIS_URL=redis://localhost:6379/0
EOF
    fi
    
    echo -e "${CYAN}gem依存関係インストール中...${NC}"
    bundle install --path vendor/bundle
    
    echo -e "${GREEN}✅ 依存関係インストール完了${NC}"
}

# Phase 4: データベース準備
setup_database() {
    echo -e "\n${BLUE}=== Phase 4: データベース準備 ===${NC}"
    
    echo -e "${CYAN}データベース作成中...${NC}"
    bundle exec rails db:create RAILS_ENV=development
    
    echo -e "${CYAN}マイグレーション実行中...${NC}"
    bundle exec rails db:migrate RAILS_ENV=development
    
    echo -e "${CYAN}初期データ投入中...${NC}"
    # サンプルデータ作成
    cat > db/seeds_test.rb << 'EOF'
# 管理者ユーザー作成
admin = User.create!(
  email: 'admin@dental.jp',
  password: 'password123',
  name: '管理者',
  role: 'admin',
  confirmed_at: Time.current
)

# 歯科医師ユーザー作成
dentist = User.create!(
  email: 'dentist@dental.jp',
  password: 'password123',
  name: '山田太郎',
  role: 'dentist',
  confirmed_at: Time.current
)

# 受付スタッフユーザー作成
staff = User.create!(
  email: 'staff@dental.jp',
  password: 'password123',
  name: '鈴木花子',
  role: 'staff',
  confirmed_at: Time.current
)

puts "✅ テストユーザー作成完了"
puts "  管理者: admin@dental.jp / password123"
puts "  歯科医師: dentist@dental.jp / password123"
puts "  受付スタッフ: staff@dental.jp / password123"

# サンプル患者データ作成
10.times do |i|
  Patient.create!(
    name: "患者#{i+1}",
    email: "patient#{i+1}@example.com",
    phone: "03-#{rand(1000..9999)}-#{rand(1000..9999)}",
    birth_date: (20..70).to_a.sample.years.ago,
    gender: ['male', 'female'].sample,
    address: "東京都渋谷区#{i+1}丁目",
    notes: "定期検診の患者です。"
  )
end

puts "✅ サンプル患者データ作成完了"

# サンプル予約データ作成
Patient.all.each do |patient|
  # 今日の予約
  if rand(2) == 0
    Appointment.create!(
      patient: patient,
      appointment_date: Date.today + rand(9..17).hours,
      status: ['confirmed', 'visited', 'cancelled'].sample,
      treatment_type: ['定期検診', '虫歯治療', 'クリーニング', '歯周病治療'].sample,
      notes: "予約メモ"
    )
  end
  
  # 今後の予約
  if rand(2) == 0
    Appointment.create!(
      patient: patient,
      appointment_date: Date.today + rand(1..30).days + rand(9..17).hours,
      status: 'confirmed',
      treatment_type: ['定期検診', '虫歯治療', 'クリーニング', '歯周病治療'].sample,
      notes: "次回予約"
    )
  end
end

puts "✅ サンプル予約データ作成完了"
EOF
    
    bundle exec rails db:seed:load RAILS_ENV=development
    bundle exec rails runner db/seeds_test.rb RAILS_ENV=development
    
    echo -e "${GREEN}✅ データベース準備完了${NC}"
}

# Phase 5: アセット準備
prepare_assets() {
    echo -e "\n${BLUE}=== Phase 5: アセット準備 ===${NC}"
    
    echo -e "${CYAN}アセットプリコンパイル中...${NC}"
    bundle exec rails assets:precompile RAILS_ENV=development
    
    echo -e "${GREEN}✅ アセット準備完了${NC}"
}

# Phase 6: サーバー起動
start_server() {
    echo -e "\n${BLUE}=== Phase 6: サーバー起動 ===${NC}"
    
    # Sidekiq起動（バックグラウンド）
    echo -e "${CYAN}Sidekiq起動中...${NC}"
    nohup bundle exec sidekiq -e development > logs/sidekiq.log 2>&1 &
    SIDEKIQ_PID=$!
    echo $SIDEKIQ_PID > tmp/pids/sidekiq.pid
    
    echo -e "\n${GREEN}===================================================${NC}"
    echo -e "${GREEN}    歯科クリニックシステム 起動準備完了！${NC}"
    echo -e "${GREEN}===================================================${NC}"
    
    echo -e "\n${YELLOW}ログイン情報:${NC}"
    echo -e "  ${CYAN}管理者: admin@dental.jp / password123${NC}"
    echo -e "  ${CYAN}歯科医師: dentist@dental.jp / password123${NC}"
    echo -e "  ${CYAN}受付スタッフ: staff@dental.jp / password123${NC}"
    
    echo -e "\n${YELLOW}アクセスURL:${NC}"
    echo -e "  ${CYAN}http://localhost:3000${NC}"
    
    echo -e "\n${YELLOW}主要機能:${NC}"
    echo -e "  ${CYAN}/dashboard - ダッシュボード（本日の予約一覧）${NC}"
    echo -e "  ${CYAN}/appointments - 予約管理${NC}"
    echo -e "  ${CYAN}/patients - 患者管理${NC}"
    echo -e "  ${CYAN}/book/manual - 手動予約登録${NC}"
    
    echo -e "\n${GREEN}Railsサーバー起動中...${NC}"
    echo -e "${YELLOW}停止する場合は Ctrl+C を押してください${NC}"
    
    # Railsサーバー起動
    bundle exec rails server -b 0.0.0.0 -p 3000
}

# クリーンアップ関数
cleanup() {
    echo -e "\n${YELLOW}クリーンアップ中...${NC}"
    
    # Sidekiq停止
    if [ -f tmp/pids/sidekiq.pid ]; then
        kill $(cat tmp/pids/sidekiq.pid) 2>/dev/null
        rm tmp/pids/sidekiq.pid
    fi
    
    # Dockerサービス停止
    docker-compose -f docker-compose.test.yml down
    
    echo -e "${GREEN}クリーンアップ完了${NC}"
}

# 終了時のクリーンアップ設定
trap cleanup EXIT

# メイン実行
main() {
    check_environment
    setup_docker_services
    install_dependencies
    setup_database
    prepare_assets
    start_server
}

# ディレクトリ作成
mkdir -p tmp/pids logs

# 実行
main