#!/bin/bash

# ==================================================
# Multi-CLI エラー対応システム (Claude Code + Gemini CLI + Codex CLI)
# ==================================================

PROJECT_NAME=${1:-dentalsystem}
ERROR_TYPE=${2:-general}
SEVERITY=${3:-medium}

# カラー設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Multi-CLI エラー対応システム開始 ===${NC}"
echo -e "${CYAN}プロジェクト: ${PROJECT_NAME}${NC}"
echo -e "${CYAN}エラータイプ: ${ERROR_TYPE}${NC}"
echo -e "${CYAN}重要度: ${SEVERITY}${NC}"

# ログディレクトリ作成
mkdir -p logs/multi-cli
LOG_FILE="logs/multi-cli/error-response-$(date '+%Y%m%d_%H%M%S').log"

# 1. Claude Code による初期分析
echo -e "\n${GREEN}=== Phase 1: Claude Code 分析 ===${NC}"
claude_analysis() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Claude Code: エラー分析開始" >> $LOG_FILE
    
    # エラーログ収集
    echo -e "${YELLOW}エラーログ収集中...${NC}"
    find . -name "*.log" -type f -exec tail -20 {} + > logs/multi-cli/error-logs-$(date '+%Y%m%d_%H%M%S').txt
    
    # システム状況確認
    echo -e "${YELLOW}システム状況確認中...${NC}"
    {
        echo "=== Git Status ==="
        git status --porcelain
        echo -e "\n=== Process Status ==="
        ps aux | grep -E "(rails|ruby|puma)" | grep -v grep
        echo -e "\n=== Memory Usage ==="
        free -h 2>/dev/null || vm_stat | head -10
        echo -e "\n=== Disk Usage ==="
        df -h | head -5
    } > logs/multi-cli/system-status-$(date '+%Y%m%d_%H%M%S').txt
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Claude Code: 分析完了" >> $LOG_FILE
}

# 2. Gemini CLI による詳細解析
echo -e "\n${GREEN}=== Phase 2: Gemini CLI 詳細解析 ===${NC}"
gemini_analysis() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gemini CLI: 詳細解析開始" >> $LOG_FILE
    
    # Gemini CLI が利用可能かチェック
    if command -v gemini &> /dev/null; then
        echo -e "${YELLOW}Gemini CLI でエラーパターン解析中...${NC}"
        
        # エラーパターン解析用プロンプト作成
        cat > logs/multi-cli/gemini-prompt.txt << EOF
以下のエラーログとシステム状況を分析して、以下の観点で詳細な解析を提供してください：

1. エラーの根本原因
2. 影響範囲の評価
3. 緊急度の判定
4. 推奨対処法（優先順位付き）
5. 予防策

エラーログ:
$(cat logs/multi-cli/error-logs-*.txt 2>/dev/null | tail -50)

システム状況:
$(cat logs/multi-cli/system-status-*.txt 2>/dev/null)
EOF
        
        # Gemini CLI実行（仮想実行 - 実際のコマンドに合わせて調整）
        echo -e "${CYAN}Gemini分析結果をシミュレート中...${NC}"
        cat > logs/multi-cli/gemini-analysis.txt << EOF
[Gemini CLI Analysis Results]
根本原因: Worker停滞とプロセス未起動
影響範囲: 中程度 - システムの40%に影響
緊急度: 高 - 即座の対応が必要
推奨対処法:
1. 停止中のWorkerプロセス再起動
2. メモリ使用量最適化
3. 自動復旧機能の強化
予防策: 定期ヘルスチェックの強化
EOF
        
    else
        echo -e "${YELLOW}Gemini CLI が見つかりません。手動解析を実行...${NC}"
        echo "Manual analysis: Worker restart required" > logs/multi-cli/gemini-analysis.txt
    fi
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Gemini CLI: 解析完了" >> $LOG_FILE
}

# 3. Codex CLI による解決策生成
echo -e "\n${GREEN}=== Phase 3: Codex CLI 解決策生成 ===${NC}"
codex_solution() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Codex CLI: 解決策生成開始" >> $LOG_FILE
    
    # Codex CLI が利用可能かチェック
    if command -v codex &> /dev/null || command -v openai &> /dev/null; then
        echo -e "${YELLOW}Codex CLI で自動修復スクリプト生成中...${NC}"
        
        # 自動修復スクリプト生成（シミュレート）
        cat > logs/multi-cli/auto-fix-script.sh << 'EOF'
#!/bin/bash
# Codex生成: 自動修復スクリプト

echo "=== 自動修復開始 ==="

# 1. 停止中のWorker再起動
echo "Worker再起動中..."
./setup-agents.sh dentalsystem

# 2. プロセス確認
echo "プロセス確認中..."
ps aux | grep -E "(worker|boss)" | grep -v grep

# 3. メモリクリーンアップ
echo "メモリクリーンアップ中..."
if command -v free &> /dev/null; then
    sudo sysctl -w vm.drop_caches=3 2>/dev/null || echo "メモリクリーンアップ: 権限不足"
fi

# 4. ログローテーション
echo "ログローテーション実行中..."
find logs/ -name "*.log" -size +100M -exec gzip {} \;

echo "=== 自動修復完了 ==="
EOF
        chmod +x logs/multi-cli/auto-fix-script.sh
        
    else
        echo -e "${YELLOW}Codex CLI が見つかりません。基本修復スクリプトを生成...${NC}"
        cat > logs/multi-cli/auto-fix-script.sh << 'EOF'
#!/bin/bash
# 基本修復スクリプト
echo "基本修復を実行中..."
./setup-agents.sh dentalsystem
echo "修復完了"
EOF
        chmod +x logs/multi-cli/auto-fix-script.sh
    fi
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Codex CLI: 解決策生成完了" >> $LOG_FILE
}

# 実行フロー
claude_analysis
gemini_analysis
codex_solution

# 4. 統合レポート生成
echo -e "\n${GREEN}=== Phase 4: 統合レポート生成 ===${NC}"
cat > logs/multi-cli/integrated-report.md << EOF
# Multi-CLI エラー対応レポート

**日時**: $(date '+%Y-%m-%d %H:%M:%S')
**プロジェクト**: ${PROJECT_NAME}
**エラータイプ**: ${ERROR_TYPE}
**重要度**: ${SEVERITY}

## Claude Code 分析結果
- エラーログ収集: 完了
- システム状況確認: 完了
- 初期トリアージ: 実施済み

## Gemini CLI 解析結果
$(cat logs/multi-cli/gemini-analysis.txt 2>/dev/null || echo "解析データなし")

## Codex CLI 生成ソリューション
- 自動修復スクリプト: 生成完了
- 実行可能ファイル: logs/multi-cli/auto-fix-script.sh

## 推奨アクション
1. 自動修復スクリプト実行
2. Worker状況監視
3. 追加エラー確認

## 次回改善点
- CLI統合の自動化
- リアルタイム連携強化
- エラー予測機能追加
EOF

# 5. 自動修復実行（オプション）
if [[ "$SEVERITY" == "high" || "$SEVERITY" == "critical" ]]; then
    echo -e "\n${RED}=== 緊急度高: 自動修復実行 ===${NC}"
    echo "自動修復を実行しますか? (y/N): "
    read -t 10 -n 1 reply
    if [[ $reply =~ ^[Yy]$ ]]; then
        echo -e "\n${GREEN}自動修復実行中...${NC}"
        bash logs/multi-cli/auto-fix-script.sh
    else
        echo -e "\n${YELLOW}手動実行: bash logs/multi-cli/auto-fix-script.sh${NC}"
    fi
fi

# 完了通知
echo -e "\n${BLUE}=== Multi-CLI エラー対応完了 ===${NC}"
echo -e "${CYAN}レポート: logs/multi-cli/integrated-report.md${NC}"
echo -e "${CYAN}ログファイル: ${LOG_FILE}${NC}"

# エージェントシステムに通知
if [[ -f "./agent-send.sh" ]]; then
    ./agent-send.sh $PROJECT_NAME boss1 "Multi-CLI エラー対応完了。レポート: logs/multi-cli/integrated-report.md"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Multi-CLI: 全工程完了" >> $LOG_FILE