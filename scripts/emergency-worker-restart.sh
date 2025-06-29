#!/bin/bash
# 緊急Worker再起動スクリプト

PROJECT_NAME=${1:-dentalsystem}
CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')

echo "=== 緊急Worker再起動実行 ==="
echo "プロジェクト: $PROJECT_NAME"
echo "実行時刻: $CURRENT_TIME"

# 停滞Worker特定
STALLED_WORKERS=()
for i in {1..5}; do
    if [ ! -f "./tmp/worker${i}_done.txt" ]; then
        STALLED_WORKERS+=($i)
        echo "Worker${i}: 停滞中"
    else
        LAST_UPDATE=$(stat -f "%m" "./tmp/worker${i}_done.txt" 2>/dev/null || stat -c "%Y" "./tmp/worker${i}_done.txt" 2>/dev/null)
        CURRENT_TIMESTAMP=$(date +%s)
        DIFF=$((CURRENT_TIMESTAMP - LAST_UPDATE))
        if [ $DIFF -gt 3600 ]; then  # 1時間以上古い
            STALLED_WORKERS+=($i)
            echo "Worker${i}: タイムアウト (${DIFF}秒経過)"
        fi
    fi
done

# 緊急ログ記録
echo "[$CURRENT_TIME] [EMERGENCY] [$PROJECT_NAME] Worker緊急再起動実行 - 停滞Workers: ${STALLED_WORKERS[*]}" >> development/development_log.txt

# 停滞Workerに緊急指示送信
for worker in "${STALLED_WORKERS[@]}"; do
    echo "Worker${worker}に緊急再指示送信中..."
    ./agent-send.sh $PROJECT_NAME worker$worker "【緊急再起動】あなたはworker${worker}です。エラー監視システムが停滞を検出しました。即座に以下を実行: 1) 現在の作業状況確認 2) 未完了作業の緊急完了 3) 完了ファイル作成 4) boss1への緊急報告"
    echo "[$CURRENT_TIME] [EMERGENCY] [$PROJECT_NAME] Worker${worker}緊急再指示送信完了" >> development/development_log.txt
done

# Boss1への統合報告
if [ ${#STALLED_WORKERS[@]} -gt 0 ]; then
    ./agent-send.sh $PROJECT_NAME boss1 "【緊急報告】エラー監視システムが${#STALLED_WORKERS[@]}名のWorker停滞を検出。緊急再指示を実施しました。停滞Workers: ${STALLED_WORKERS[*]}。即座にステータス確認と対応をお願いします。"
    echo "[$CURRENT_TIME] [EMERGENCY] [$PROJECT_NAME] Boss1緊急報告完了" >> development/development_log.txt
fi

# Presidentへの最終報告
./agent-send.sh $PROJECT_NAME president "【緊急対応完了】エラー監視システム問題調査・対応完了。停滞Worker${#STALLED_WORKERS[@]}名に緊急再指示実施。システム安定性確保のため継続監視中です。"

echo "=== 緊急対応完了 ==="
echo "停滞Worker数: ${#STALLED_WORKERS[@]}"
echo "再指示送信完了: $(date)"