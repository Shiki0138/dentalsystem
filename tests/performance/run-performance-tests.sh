#!/bin/bash

# 🦷 Dental System - Performance Test Runner
# Execute comprehensive performance testing suite

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="${BASE_URL:-http://localhost:3000}"
RESULTS_DIR="tests/performance/results"
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")

# Create results directory
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}🦷 歯科システム パフォーマンステスト実行開始${NC}"
echo -e "${BLUE}目標: 95パーセンタイル < 1秒, 100仮想ユーザー${NC}"
echo "=========================================="

# Check if k6 is installed
if ! command -v k6 &> /dev/null; then
    echo -e "${RED}❌ k6がインストールされていません${NC}"
    echo "インストール方法:"
    echo "macOS: brew install k6"
    echo "Ubuntu: sudo apt-get install k6"
    echo "Windows: choco install k6"
    exit 1
fi

# Check if Rails server is running
echo -e "${YELLOW}🔍 Railsサーバー接続チェック...${NC}"
if ! curl -s "$BASE_URL" > /dev/null; then
    echo -e "${RED}❌ Railsサーバーが$BASE_URLで応答していません${NC}"
    echo "サーバーを起動してください: rails server"
    exit 1
fi
echo -e "${GREEN}✅ サーバー接続確認${NC}"

# Function to run k6 test with proper output
run_k6_test() {
    local test_file=$1
    local test_name=$2
    local output_file="$RESULTS_DIR/${test_name}_${TIMESTAMP}"
    
    echo -e "${YELLOW}🚀 $test_name 実行中...${NC}"
    
    # Run k6 with multiple output formats
    k6 run \
        --out json="$output_file.json" \
        --out summary="$output_file.txt" \
        --env BASE_URL="$BASE_URL" \
        "$test_file" | tee "$output_file.log"
    
    local exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ $test_name 完了${NC}"
        return 0
    else
        echo -e "${RED}❌ $test_name 失敗 (終了コード: $exit_code)${NC}"
        return 1
    fi
}

# Function to check test results
check_test_results() {
    local test_name=$1
    local result_file="$RESULTS_DIR/${test_name}_${TIMESTAMP}.json"
    
    if [ -f "$result_file" ]; then
        echo -e "${BLUE}📊 $test_name 結果分析:${NC}"
        
        # Extract key metrics using jq (if available)
        if command -v jq &> /dev/null; then
            local avg_duration=$(jq -r '.metrics.http_req_duration.values.avg // "N/A"' "$result_file")
            local p95_duration=$(jq -r '.metrics.http_req_duration.values["p(95)"] // "N/A"' "$result_file")
            local error_rate=$(jq -r '.metrics.http_req_failed.values.rate // "N/A"' "$result_file")
            local total_requests=$(jq -r '.metrics.http_reqs.values.count // "N/A"' "$result_file")
            
            echo "  平均応答時間: ${avg_duration}ms"
            echo "  95パーセンタイル: ${p95_duration}ms"
            echo "  エラー率: ${error_rate}"
            echo "  総リクエスト数: ${total_requests}"
            
            # Check if 95th percentile meets requirement (< 1000ms)
            if [ "$p95_duration" != "N/A" ] && [ "$p95_duration" != "null" ]; then
                local p95_int=$(echo "$p95_duration" | cut -d'.' -f1)
                if [ "$p95_int" -lt 1000 ]; then
                    echo -e "  ${GREEN}✅ 95パーセンタイル目標達成 (< 1秒)${NC}"
                else
                    echo -e "  ${RED}❌ 95パーセンタイル目標未達成 (>= 1秒)${NC}"
                fi
            fi
        else
            echo "  jqがインストールされていないため、詳細分析をスキップ"
        fi
        echo ""
    fi
}

# Test execution sequence
TESTS_PASSED=0
TESTS_TOTAL=0

echo -e "${BLUE}📋 テスト実行計画:${NC}"
echo "1. 負荷テスト (Load Test) - 95p<1s, 100VU"
echo "2. ストレステスト (Stress Test) - システム限界特定"
echo "3. スパイクテスト (Spike Test) - 突然の負荷急増"
echo ""

# 1. Load Test
echo -e "${YELLOW}=== 1. 負荷テスト開始 ===${NC}"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if run_k6_test "tests/performance/k6-load-test.js" "load_test"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    check_test_results "load_test"
fi

# Wait between tests to let system stabilize
echo -e "${YELLOW}⏳ システム安定化待機 (30秒)...${NC}"
sleep 30

# 2. Stress Test
echo -e "${YELLOW}=== 2. ストレステスト開始 ===${NC}"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if run_k6_test "tests/performance/k6-stress-test.js" "stress_test"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    check_test_results "stress_test"
fi

# Wait between tests
echo -e "${YELLOW}⏳ システム安定化待機 (30秒)...${NC}"
sleep 30

# 3. Spike Test
echo -e "${YELLOW}=== 3. スパイクテスト開始 ===${NC}"
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if run_k6_test "tests/performance/k6-spike-test.js" "spike_test"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    check_test_results "spike_test"
fi

# Generate comprehensive report
echo -e "${BLUE}📊 総合レポート生成中...${NC}"
REPORT_FILE="$RESULTS_DIR/performance_report_${TIMESTAMP}.md"

cat > "$REPORT_FILE" << EOF
# 🦷 歯科システム パフォーマンステスト結果

## テスト実行概要
- **実行日時**: $(date "+%Y年%m月%d日 %H:%M:%S")
- **対象URL**: $BASE_URL
- **実行環境**: $(uname -s) $(uname -r)
- **テスト結果**: $TESTS_PASSED/$TESTS_TOTAL 成功

## テスト目標
- ✅ 95パーセンタイル応答時間 < 1秒
- ✅ 100仮想ユーザー同時負荷
- ✅ エラー率 < 1%
- ✅ システム安定性確認

## 実行テスト
1. **負荷テスト** - 段階的負荷増加 (最大100VU)
2. **ストレステスト** - システム限界特定 (最大500VU)
3. **スパイクテスト** - 突然の負荷急増 (最大600VU)

## 結果ファイル
- 負荷テスト: load_test_${TIMESTAMP}.*
- ストレステスト: stress_test_${TIMESTAMP}.*
- スパイクテスト: spike_test_${TIMESTAMP}.*

## 推奨アクション
EOF

# Add recommendations based on test results
if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    cat >> "$REPORT_FILE" << EOF
✅ **全テスト成功** - システムは本番環境デプロイ可能な性能基準を満たしています。

### 次のステップ
1. 本番環境でのモニタリング設定
2. 自動スケーリング設定の検証
3. 定期的なパフォーマンステストの実施
EOF
else
    cat >> "$REPORT_FILE" << EOF
⚠️ **一部テスト失敗** - パフォーマンス改善が必要です。

### 改善推奨事項
1. データベースクエリの最適化
2. キャッシュ戦略の見直し
3. サーバーリソースの増強検討
4. コードプロファイリングの実施
EOF
fi

# Final summary
echo ""
echo "=========================================="
echo -e "${BLUE}🏁 パフォーマンステスト完了${NC}"
echo -e "結果: ${TESTS_PASSED}/${TESTS_TOTAL} テスト成功"

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "${GREEN}✅ 全テスト成功 - 目標性能達成！${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  一部テスト失敗 - 改善が必要です${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📁 結果ファイル場所: $RESULTS_DIR${NC}"
echo -e "${BLUE}📊 詳細レポート: $REPORT_FILE${NC}"
echo ""
echo -e "${BLUE}💡 詳細分析のため、各JSONファイルをk6 Cloudや${NC}"
echo -e "${BLUE}   Grafana + InfluxDBで可視化することを推奨します${NC}"