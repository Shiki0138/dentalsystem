#!/bin/bash
# 🔄 URL一括置換スクリプト
# 本番URL確定後にプレースホルダーを実URLに一括置換

set -e

# 色付きメッセージ
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 URL一括置換スクリプト開始${NC}"
echo "============================================"

# 設定
PLACEHOLDER="{{PRODUCTION_URL}}"
DEFAULT_URL="https://dentalsystem-production.onrender.com"
BACKUP_DIR="./url_backup_$(date +%Y%m%d_%H%M%S)"
SEARCH_PATTERN="*.md"

# パラメータ確認
if [ "$#" -eq 0 ]; then
    echo -e "${YELLOW}使用方法: $0 <新しいURL> [検索パターン]${NC}"
    echo "例: $0 https://your-domain.com"
    echo "例: $0 https://your-domain.com \"*.html\""
    echo ""
    echo -e "${BLUE}デフォルトURL使用: ${DEFAULT_URL}${NC}"
    NEW_URL="$DEFAULT_URL"
else
    NEW_URL="$1"
fi

if [ "$#" -ge 2 ]; then
    SEARCH_PATTERN="$2"
fi

echo -e "${GREEN}新しいURL: ${NEW_URL}${NC}"
echo -e "${GREEN}検索パターン: ${SEARCH_PATTERN}${NC}"
echo ""

# バックアップディレクトリ作成
echo -e "${BLUE}📁 バックアップディレクトリ作成: ${BACKUP_DIR}${NC}"
mkdir -p "$BACKUP_DIR"

# 対象ファイル検索
echo -e "${BLUE}🔍 対象ファイル検索中...${NC}"
TARGET_FILES=$(find . -name "$SEARCH_PATTERN" -type f | grep -v "$BACKUP_DIR" | head -50)

if [ -z "$TARGET_FILES" ]; then
    echo -e "${RED}❌ 対象ファイルが見つかりません${NC}"
    exit 1
fi

echo -e "${GREEN}📋 対象ファイル一覧:${NC}"
echo "$TARGET_FILES" | nl

# プレースホルダー含有ファイル確認
echo ""
echo -e "${BLUE}🔍 プレースホルダー含有ファイル確認中...${NC}"
PLACEHOLDER_FILES=""
TOTAL_COUNT=0

for file in $TARGET_FILES; do
    count=$(grep -c "$PLACEHOLDER" "$file" 2>/dev/null || echo "0")
    if [ "$count" -gt 0 ]; then
        PLACEHOLDER_FILES="$PLACEHOLDER_FILES $file"
        TOTAL_COUNT=$((TOTAL_COUNT + count))
        echo -e "${YELLOW}  $file: ${count}箇所${NC}"
    fi
done

if [ -z "$PLACEHOLDER_FILES" ]; then
    echo -e "${GREEN}✅ プレースホルダーは見つかりませんでした（既に置換済み）${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}📊 置換対象: ${TOTAL_COUNT}箇所${NC}"

# 確認プロンプト
echo ""
echo -e "${YELLOW}⚠️  置換を実行しますか？ (y/N):${NC}"
read -r CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ 置換をキャンセルしました${NC}"
    exit 0
fi

# バックアップ作成
echo ""
echo -e "${BLUE}💾 バックアップ作成中...${NC}"
for file in $PLACEHOLDER_FILES; do
    # ディレクトリ構造を保持してバックアップ
    backup_path="$BACKUP_DIR/$file"
    mkdir -p "$(dirname "$backup_path")"
    cp "$file" "$backup_path"
    echo -e "${GREEN}  ✅ $file → $backup_path${NC}"
done

# URL置換実行
echo ""
echo -e "${BLUE}🔄 URL置換実行中...${NC}"
REPLACED_COUNT=0

for file in $PLACEHOLDER_FILES; do
    # sedで置換（macOS/BSD sed対応）
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|$PLACEHOLDER|$NEW_URL|g" "$file"
    else
        # Linux
        sed -i "s|$PLACEHOLDER|$NEW_URL|g" "$file"
    fi
    
    # 置換後の確認
    new_count=$(grep -c "$NEW_URL" "$file" 2>/dev/null || echo "0")
    echo -e "${GREEN}  ✅ $file: ${new_count}箇所置換${NC}"
    REPLACED_COUNT=$((REPLACED_COUNT + new_count))
done

# 結果表示
echo ""
echo "============================================"
echo -e "${GREEN}🎉 URL置換完了！${NC}"
echo -e "${GREEN}📊 置換実績:${NC}"
echo -e "  - 対象ファイル: $(echo $PLACEHOLDER_FILES | wc -w | tr -d ' ')件"
echo -e "  - 置換箇所: ${REPLACED_COUNT}箇所"
echo -e "  - バックアップ: ${BACKUP_DIR}/"
echo ""

# 置換確認
echo -e "${BLUE}🔍 置換結果確認:${NC}"
remaining=$(grep -r "$PLACEHOLDER" $PLACEHOLDER_FILES 2>/dev/null | wc -l | tr -d ' ')
if [ "$remaining" -eq 0 ]; then
    echo -e "${GREEN}✅ 全てのプレースホルダーが正常に置換されました${NC}"
else
    echo -e "${RED}⚠️  未置換のプレースホルダーが ${remaining}箇所 残っています${NC}"
    echo -e "${YELLOW}詳細:${NC}"
    grep -r "$PLACEHOLDER" $PLACEHOLDER_FILES 2>/dev/null || true
fi

# 置換後ファイル一覧
echo ""
echo -e "${BLUE}📋 置換後ファイル内容確認（最初の3行）:${NC}"
for file in $PLACEHOLDER_FILES; do
    echo -e "${YELLOW}--- $file ---${NC}"
    head -3 "$file" | grep -E "(http|URL|production)" | head -1
done

# 追加の置換確認
echo ""
echo -e "${BLUE}🔍 追加置換候補確認:${NC}"
echo -e "${YELLOW}古いURL（Heroku等）が残っている可能性があります:${NC}"

# 古いURLパターンを検索
OLD_PATTERNS=("herokuapp.com" "localhost:3000" "localhost:3001" "127.0.0.1")
for pattern in "${OLD_PATTERNS[@]}"; do
    count=$(grep -r "$pattern" $TARGET_FILES 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        echo -e "${YELLOW}  ${pattern}: ${count}箇所発見${NC}"
    fi
done

# 完了メッセージ
echo ""
echo "============================================"
echo -e "${GREEN}🚀 URL一括置換完了！${NC}"
echo -e "${BLUE}次のステップ:${NC}"
echo "1. 置換結果の動作確認"
echo "2. 必要に応じて古いURL（Heroku等）の手動置換"
echo "3. バックアップファイルの保管/削除判断"
echo "4. Git commitの実行"
echo ""
echo -e "${GREEN}バックアップ: ${BACKUP_DIR}/${NC}"
echo -e "${GREEN}新しいURL: ${NEW_URL}${NC}"

# オプション: 自動Git commit
echo ""
echo -e "${YELLOW}Git commitを実行しますか？ (y/N):${NC}"
read -r GIT_CONFIRM

if [[ "$GIT_CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}📝 Git commit実行中...${NC}"
    git add $PLACEHOLDER_FILES
    git commit -m "🔄 Update production URL to $NEW_URL

- Replaced {{PRODUCTION_URL}} placeholder in $(echo $PLACEHOLDER_FILES | wc -w | tr -d ' ') files
- Total replacements: $REPLACED_COUNT locations
- Backup created: $BACKUP_DIR/

🦷 Dental Revolution System - Production URL Update"
    echo -e "${GREEN}✅ Git commit完了${NC}"
else
    echo -e "${YELLOW}ℹ️  Git commitはスキップされました${NC}"
    echo "手動でcommitする場合:"
    echo "git add $PLACEHOLDER_FILES"
    echo "git commit -m 'Update production URL'"
fi

echo ""
echo -e "${GREEN}🎊 URL一括置換処理完了！${NC}"