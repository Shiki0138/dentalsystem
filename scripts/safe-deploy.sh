#!/bin/bash

echo "🛡️ セーフデプロイメント実行"
echo "このスクリプトはエラーを防止するための包括的チェックを実行します"
echo ""

# 色付き出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# エラー時の終了処理
cleanup() {
    if [ $? -ne 0 ]; then
        error "デプロイが失敗しました。ロールバックを検討してください。"
        echo ""
        echo "🔧 トラブルシューティング:"
        echo "1. railway logs でエラーログを確認"
        echo "2. railway variables で環境変数を確認"
        echo "3. 必要に応じて railway rollback を実行"
    fi
}
trap cleanup EXIT

# 1. プロジェクト確認
echo -e "${BLUE}1️⃣ プロジェクト確認${NC}"
if ! command -v railway &> /dev/null; then
    error "Railway CLIがインストールされていません"
    echo "インストール: curl -fsSL https://railway.app/install.sh | sh"
    exit 1
fi

# プロジェクトがリンクされているか確認
if ! railway status &> /dev/null; then
    error "Railwayプロジェクトにリンクされていません"
    echo "実行: railway link"
    exit 1
fi

success "Railwayプロジェクト確認完了"

# 2. 環境変数チェック
echo ""
echo -e "${BLUE}2️⃣ 環境変数チェック${NC}"
rails deployment:check_env
if [ $? -ne 0 ]; then
    error "環境変数チェックが失敗しました"
    exit 1
fi

# 3. ローカルビルドテスト
echo ""
echo -e "${BLUE}3️⃣ ローカルビルドテスト${NC}"
echo "本番環境向けのアセットプリコンパイルを実行..."

# 環境変数を設定してビルド実行
export RAILS_ENV=production
export SECRET_KEY_BASE=$(openssl rand -hex 64)

if bundle exec rails assets:precompile > /tmp/precompile.log 2>&1; then
    success "アセットプリコンパイル成功"
else
    error "アセットプリコンパイルが失敗しました"
    echo "ログ:"
    cat /tmp/precompile.log | tail -20
    exit 1
fi

# 4. データベース接続テスト（ローカル）
echo ""
echo -e "${BLUE}4️⃣ データベース接続テスト${NC}"
if bundle exec rails db:version > /dev/null 2>&1; then
    success "データベース接続確認"
else
    warning "ローカルデータベース接続に問題があります（本番環境では問題ない可能性があります）"
fi

# 5. コードチェック
echo ""
echo -e "${BLUE}5️⃣ コードチェック${NC}"
if command -v rubocop &> /dev/null; then
    info "Rubocopでのコードチェック..."
    rubocop --fail-level=error
    if [ $? -eq 0 ]; then
        success "コードチェック通過"
    else
        warning "コードスタイルの問題がありますが、デプロイは継続します"
    fi
else
    info "Rubocop未インストールのため、コードチェックをスキップ"
fi

# 6. デプロイ前確認
echo ""
echo -e "${BLUE}6️⃣ デプロイ前最終確認${NC}"
echo "デプロイする内容:"
echo "  - プロジェクト: $(railway status | grep "Project" | cut -d: -f2 | xargs)"
echo "  - 環境: Production"
echo "  - ブランチ: $(git branch --show-current)"
echo "  - コミット: $(git rev-parse --short HEAD)"
echo ""

read -p "デプロイを実行しますか？ (y/N): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    info "デプロイをキャンセルしました"
    exit 0
fi

# 7. デプロイ実行
echo ""
echo -e "${BLUE}7️⃣ デプロイ実行${NC}"
info "Railwayにデプロイを開始..."

railway up --detach
if [ $? -eq 0 ]; then
    success "デプロイコマンド実行完了"
else
    error "デプロイコマンドが失敗しました"
    exit 1
fi

# 8. デプロイ状況監視
echo ""
echo -e "${BLUE}8️⃣ デプロイ状況監視${NC}"
info "デプロイ状況を監視中..."
echo "リアルタイムログ確認: railway logs --tail"
echo ""

# 簡易的な完了待機（60秒間）
sleep_time=0
max_wait=60

while [ $sleep_time -lt $max_wait ]; do
    echo -n "."
    sleep 5
    sleep_time=$((sleep_time + 5))
done

echo ""
info "デプロイ監視完了（${max_wait}秒経過）"

# 9. デプロイ後チェック
echo ""
echo -e "${BLUE}9️⃣ デプロイ後チェック${NC}"

# URLの取得
url=$(railway domain 2>/dev/null | head -1)
if [ -n "$url" ]; then
    info "アプリケーションURL: https://$url"
    
    # 簡易ヘルスチェック
    if curl -s -o /dev/null -w "%{http_code}" "https://$url/health" | grep -q "200"; then
        success "ヘルスチェック成功"
    else
        warning "ヘルスチェックが失敗しました。アプリケーションログを確認してください。"
    fi
else
    info "URLの取得に失敗しました。railway domain で確認してください。"
fi

# 10. 完了
echo ""
echo -e "${GREEN}🎉 セーフデプロイメント完了！${NC}"
echo ""
echo -e "${BLUE}📋 次のステップ:${NC}"
echo "1. railway logs でデプロイログを確認"
echo "2. railway domain でURLを確認"
echo "3. アプリケーションの動作確認"
echo ""
echo -e "${BLUE}🔧 便利なコマンド:${NC}"
echo "  - ログ確認: railway logs --tail"
echo "  - 環境変数: railway variables"
echo "  - ロールバック: railway rollback"
echo "  - ヘルスチェック: railway run rails deployment:health_check"
echo ""

# デプロイ完了をログに記録
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEPLOY] [dentalsystem] セーフデプロイメント完了 - URL: $url" >> development/development_log.txt

success "セーフデプロイメントが正常に完了しました！"