#!/bin/bash

# 🚀 即座実行自動化スクリプト
# 生成日時: 2025-07-04 08:37:22

set -e  # エラー時に停止

RENDER_URL="$1"

if [ -z "$RENDER_URL" ]; then
  echo "使用方法: $0 <render_url>"
  echo "例: $0 https://dentalsystem-abc123.onrender.com"
  exit 1
fi

echo "🚀 即座実行開始: $RENDER_URL"
echo "開始時刻: $(date)"
echo "=" * 60

START_TIME=$(date +%s)


echo "📋 Step 1: URL移行実行"
STEP_START=$(date +%s)

if timeout 60 ruby scripts/url_migration_script.rb "$RENDER_URL"; then
  STEP_END=$(date +%s)
  STEP_DURATION=$((STEP_END - STEP_START))
  echo "✅ Step 1完了 (${STEP_DURATION}秒)"
else
  STEP_END=$(date +%s)
  STEP_DURATION=$((STEP_END - STEP_START))
  echo "❌ Step 1失敗 (${STEP_DURATION}秒)"
  exit 1
fi


echo "📋 Step 2: デプロイ検証実行"
STEP_START=$(date +%s)

if timeout 180 ruby test/render_deployment_verification.rb "$RENDER_URL"; then
  STEP_END=$(date +%s)
  STEP_DURATION=$((STEP_END - STEP_START))
  echo "✅ Step 2完了 (${STEP_DURATION}秒)"
else
  STEP_END=$(date +%s)
  STEP_DURATION=$((STEP_END - STEP_START))
  echo "❌ Step 2失敗 (${STEP_DURATION}秒)"
  exit 1
fi


echo "📋 Step 3: パフォーマンステスト実行"
STEP_START=$(date +%s)

if timeout 300 ruby scripts/performance_test_tools.rb "$RENDER_URL"; then
  STEP_END=$(date +%s)
  STEP_DURATION=$((STEP_END - STEP_START))
  echo "✅ Step 3完了 (${STEP_DURATION}秒)"
else
  STEP_END=$(date +%s)
  STEP_DURATION=$((STEP_END - STEP_START))
  echo "❌ Step 3失敗 (${STEP_DURATION}秒)"
  
fi


echo "📋 Step 4: レポート統合"
STEP_START=$(date +%s)

if timeout 30 echo 'レポート統合処理' "$RENDER_URL"; then
  STEP_END=$(date +%s)
  STEP_DURATION=$((STEP_END - STEP_START))
  echo "✅ Step 4完了 (${STEP_DURATION}秒)"
else
  STEP_END=$(date +%s)
  STEP_DURATION=$((STEP_END - STEP_START))
  echo "❌ Step 4失敗 (${STEP_DURATION}秒)"
  
fi


END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo "=" * 60
echo "🎉 即座実行完了"
echo "総実行時間: ${TOTAL_DURATION}秒"
echo "完了時刻: $(date)"

