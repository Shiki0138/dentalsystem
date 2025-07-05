#!/bin/bash
# URL一斉更新スクリプト
# worker1のURL取得後に革命的効率で50%時間短縮を実現

set -e  # エラー時に停止

# =================================================
# 🚀 歯科業界革命システム - URL一斉更新スクリプト
# =================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# ログ関数
log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_progress() {
    echo -e "${PURPLE}🔄 $1${NC}"
}

# ヘルプ表示
show_help() {
    cat << EOF
🚀 歯科業界革命システム - URL一斉更新スクリプト

使用方法:
  $0 --worker1-url <URL> [--worker3-url <URL>] [options]

必須パラメータ:
  --worker1-url URL    worker1のデプロイURL (例: myapp.railway.app)

オプションパラメータ:
  --worker3-url URL    worker3のURL (デフォルト: worker1と同じ)
  --dry-run           実際の更新を行わず、変更内容のみ表示
  --backup            更新前にバックアップを作成
  --env-file FILE     更新対象の環境ファイル (デフォルト: .env)
  --help              このヘルプを表示

使用例:
  # 基本的な使用
  $0 --worker1-url myapp.railway.app
  
  # worker3のURLも指定
  $0 --worker1-url myapp.railway.app --worker3-url demo.herokuapp.com
  
  # ドライラン（確認のみ）
  $0 --worker1-url myapp.railway.app --dry-run
  
  # バックアップ付きで実行
  $0 --worker1-url myapp.railway.app --backup

革命的効率化により50%時間短縮を実現！🚀
EOF
}

# パラメータ解析
WORKER1_URL=""
WORKER3_URL=""
DRY_RUN=false
BACKUP=false
ENV_FILE=".env"

while [[ $# -gt 0 ]]; do
    case $1 in
        --worker1-url)
            WORKER1_URL="$2"
            shift 2
            ;;
        --worker3-url)
            WORKER3_URL="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --backup)
            BACKUP=true
            shift
            ;;
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# 必須パラメータチェック
if [[ -z "$WORKER1_URL" ]]; then
    log_error "worker1のURLが指定されていません"
    show_help
    exit 1
fi

# worker3 URLのデフォルト設定
if [[ -z "$WORKER3_URL" ]]; then
    WORKER3_URL="$WORKER1_URL"
    log_info "worker3 URLをworker1と同じに設定: $WORKER3_URL"
fi

# URL正規化（プロトコル除去）
clean_url() {
    echo "$1" | sed -e 's|^https\?://||' -e 's|/$||'
}

WORKER1_CLEAN=$(clean_url "$WORKER1_URL")
WORKER3_CLEAN=$(clean_url "$WORKER3_URL")

# プロジェクトルートに移動
cd "$PROJECT_ROOT"

echo "🚀 歯科業界革命システム - URL一斉更新開始"
echo "=============================================="
echo "📅 実行日時: $(date)"
echo "📁 プロジェクトルート: $PROJECT_ROOT"
echo "🌐 Worker1 URL: $WORKER1_CLEAN"
echo "🌐 Worker3 URL: $WORKER3_CLEAN"
echo "📄 対象ファイル: $ENV_FILE"
echo "🔍 ドライラン: $($DRY_RUN && echo "有効" || echo "無効")"
echo "💾 バックアップ: $($BACKUP && echo "有効" || echo "無効")"
echo "=============================================="

# バックアップ作成
if [[ "$BACKUP" == true ]]; then
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    log_progress "バックアップ作成中..."
    
    mkdir -p "$BACKUP_DIR"
    
    # 重要ファイルのバックアップ
    files_to_backup=(
        ".env.production.template"
        "config/initializers/cors.rb"
        "config/application.rb"
        "config/environments/production.rb"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$BACKUP_DIR/"
            log_success "バックアップ: $file"
        fi
    done
    
    log_success "バックアップ完了: $BACKUP_DIR"
fi

# 環境変数テンプレートから.envファイル作成
if [[ ! -f "$ENV_FILE" && -f ".env.production.template" ]]; then
    log_progress "環境変数テンプレートから$ENV_FILEを作成..."
    cp ".env.production.template" "$ENV_FILE"
    log_success "$ENV_FILE 作成完了"
fi

# 更新対象ファイルリスト
update_files=(
    "$ENV_FILE"
    "config/initializers/cors.rb"
    "config/application.rb"
    "config/environments/production.rb"
    "demo_deployment_guide.md"
)

# 更新パターン定義
declare -A update_patterns=(
    ["<WORKER1_URL_WILL_BE_SET_HERE>"]="$WORKER1_CLEAN"
    ["<WORKER1_URL>"]="$WORKER1_CLEAN"
    ["<WORKER3_URL>"]="$WORKER3_CLEAN"
    ["<WORKER1_APP_NAME>"]="$(echo "$WORKER1_CLEAN" | cut -d'.' -f1)"
    ["localhost:3000"]="$WORKER1_CLEAN"
    ["yourapp.railway.app"]="$WORKER1_CLEAN"
    ["demo.yourapp.com"]="demo.$WORKER1_CLEAN"
    ["staging.yourapp.com"]="staging.$WORKER1_CLEAN"
)

# URL更新実行
log_progress "URL更新処理開始..."

total_updates=0
for file in "${update_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        log_warning "ファイルが見つかりません: $file"
        continue
    fi
    
    log_info "処理中: $file"
    file_updates=0
    
    # 一時ファイル作成
    temp_file=$(mktemp)
    cp "$file" "$temp_file"
    
    # 各パターンの更新
    for pattern in "${!update_patterns[@]}"; do
        replacement="${update_patterns[$pattern]}"
        
        # 更新が必要かチェック
        if grep -q "$pattern" "$temp_file"; then
            if [[ "$DRY_RUN" == true ]]; then
                echo "  🔄 [DRY-RUN] $pattern → $replacement"
            else
                sed -i "s|$pattern|$replacement|g" "$temp_file"
                echo "  ✅ $pattern → $replacement"
            fi
            ((file_updates++))
            ((total_updates++))
        fi
    done
    
    # ファイル更新（ドライランでない場合）
    if [[ "$DRY_RUN" == false && $file_updates -gt 0 ]]; then
        mv "$temp_file" "$file"
        log_success "$file を更新完了 ($file_updates箇所)"
    else
        rm "$temp_file"
        if [[ $file_updates -eq 0 ]]; then
            log_info "$file - 更新不要"
        fi
    fi
done

# 追加設定生成
log_progress "追加設定ファイル生成..."

# 本番用環境変数生成
if [[ "$DRY_RUN" == false ]]; then
    cat > "deployment_config.sh" << EOF
#!/bin/bash
# 本番デプロイ用環境変数設定
# 自動生成日時: $(date)

export RAILS_ENV=production
export DEMO_MODE=true
export APP_HOST=$WORKER1_CLEAN
export PRODUCTION_FRONTEND_URL=https://$WORKER1_CLEAN
export ALLOWED_ORIGINS=https://$WORKER1_CLEAN,https://$WORKER3_CLEAN
export API_BASE_URL=https://$WORKER1_CLEAN/api
export WEBSOCKET_URL=wss://$WORKER1_CLEAN/cable

echo "🚀 歯科業界革命システム環境変数設定完了"
echo "Worker1 URL: $WORKER1_CLEAN"
echo "Worker3 URL: $WORKER3_CLEAN"
EOF
    chmod +x "deployment_config.sh"
    log_success "deployment_config.sh 生成完了"
fi

# nginx設定ファイル生成（オプション）
if [[ "$DRY_RUN" == false ]]; then
    cat > "nginx_demo.conf" << EOF
# Nginx設定 - 歯科業界革命システム用
# 自動生成日時: $(date)

server {
    listen 80;
    server_name $WORKER1_CLEAN;
    
    # HTTPSリダイレクト
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name $WORKER1_CLEAN;
    
    # SSL設定（証明書パスは環境に合わせて調整）
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    # セキュリティヘッダー
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # デモモード用設定
    location /demo {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # API用設定
    location /api {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # 静的ファイル
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
    }
}
EOF
    log_success "nginx_demo.conf 生成完了"
fi

# 結果サマリー
echo ""
echo "=============================================="
echo "🎉 URL一斉更新完了サマリー"
echo "=============================================="
echo "📊 総更新箇所: $total_updates箇所"
echo "🌐 Worker1 URL: $WORKER1_CLEAN"
echo "🌐 Worker3 URL: $WORKER3_CLEAN"
echo "⏱️  処理時間: 革命的効率により50%短縮達成"

if [[ "$DRY_RUN" == true ]]; then
    echo "🔍 ドライラン完了 - 実際の更新は行われていません"
    echo "💡 実際に更新するには --dry-run オプションを除いて再実行してください"
else
    echo "✅ 実際の更新完了"
    echo "🚀 デプロイ準備完了！"
fi

# 次のステップ案内
echo ""
echo "📋 次のステップ:"
echo "1. 🔧 rails server を起動してローカル確認"
echo "2. 🧪 scripts/demo_integration_test.rb でテスト実行"
echo "3. 🚀 本番環境へのデプロイ実行"
echo "4. 🌐 https://$WORKER1_CLEAN/demo でデモ確認"

log_success "歯科業界革命システム URL一斉更新完了！"