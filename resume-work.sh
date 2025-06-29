#!/bin/bash

# 🔄 ClaudeAuto 作業再開スクリプト
# 予期せぬシャットダウン後の作業再開を支援

echo "================================================"
echo " 🔄 ClaudeAuto 作業再開システム"
echo "================================================"

# プロジェクト名の確認
if [ -z "$1" ]; then
    echo -n "再開するプロジェクト名を入力してください: "
    read PROJECT_NAME
else
    PROJECT_NAME=$1
fi

# 環境変数ファイルの確認
ENV_FILE=".env_${PROJECT_NAME}"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ エラー: プロジェクト '${PROJECT_NAME}' が見つかりません"
    echo "利用可能なプロジェクト:"
    ls .env_* 2>/dev/null | sed 's/.env_/  - /'
    exit 1
fi

# 環境変数の読み込み
source "$ENV_FILE"
echo "✅ プロジェクト '${PROJECT_NAME}' を読み込みました"

echo ""
echo "📋 開発状況の確認中..."
echo "================================================"

# 開発ルールの表示
echo ""
echo "📏 開発ルール (development/development_rules.md):"
echo "------------------------------------------------"
head -20 development/development_rules.md
echo "... (以下省略)"

# 仕様書の確認
echo ""
echo "📄 プロジェクト仕様書 (specifications/project_spec.md):"
echo "------------------------------------------------"
if [ -f "specifications/project_spec.md" ]; then
    head -20 specifications/project_spec.md
    echo "... (以下省略)"
else
    echo "⚠️  仕様書が見つかりません。変換が必要かもしれません。"
fi

# 開発ログの最新状況
echo ""
echo "📊 最新の開発ログ (development/development_log.txt):"
echo "------------------------------------------------"
if [ -f "development/development_log.txt" ]; then
    tail -20 development/development_log.txt
else
    echo "⚠️  開発ログが見つかりません。"
fi

# 作業状態の確認
echo ""
echo "🔍 現在の作業状態:"
echo "------------------------------------------------"
CYCLE_NUM=$(ls ./tmp/cycle_*.txt 2>/dev/null | wc -l)
COMPLETED_WORKERS=$(ls ./tmp/worker*_done.txt 2>/dev/null | wc -l)

echo "- 完了サイクル数: $CYCLE_NUM"
echo "- 完了済みworker数: $COMPLETED_WORKERS / 5"

if [ -f "./tmp/worker1_done.txt" ]; then
    echo ""
    echo "最後の作業内容:"
    for i in {1..5}; do
        if [ -f "./tmp/worker${i}_done.txt" ]; then
            echo "  worker${i}: $(cat ./tmp/worker${i}_done.txt)"
        fi
    done
fi

# 再開オプションの表示
echo ""
echo "================================================"
echo " 🚀 作業再開オプション"
echo "================================================"
echo ""
echo "1) PRESIDENTに作業継続を指示"
echo "2) boss1に現在の状況確認を指示"
echo "3) 全workerに状態確認を指示"
echo "4) 開発ログの詳細を確認"
echo "5) 仕様書を再変換・配布"
echo "6) 新しいサイクルを開始"
echo "7) 手動でメッセージを送信"
echo "0) 終了"
echo ""
echo -n "選択してください [0-7]: "
read CHOICE

case $CHOICE in
    1)
        echo ""
        echo "📤 PRESIDENTに作業継続を指示します..."
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RESUME] [$PROJECT_NAME] [SYSTEM] 作業再開 - PRESIDENTへ指示" >> development/development_log.txt
        
        # tmuxペインでPRESIDENTに指示
        tmux send-keys -t ${PROJECT_NAME}:0.0 "
        echo '================================================'
        echo ' 🔄 作業再開指示'
        echo '================================================'
        echo ''
        echo 'あなたはPRESIDENTです。'
        echo '作業が中断されていたため、以下を実行してください：'
        echo ''
        echo '1. 開発ログを確認して現在の進捗を把握'
        echo '2. 必要に応じて仕様書を再配布'
        echo '3. boss1に作業継続を指示'
        echo ''
        cat development/development_rules.md | head -10
        echo ''
        tail -10 development/development_log.txt
        " Enter
        ;;
        
    2)
        echo ""
        echo "📤 boss1に状況確認を指示します..."
        ./agent-send.sh $PROJECT_NAME boss1 "作業再開します。現在の状況を確認して、必要な指示を出してください。開発ログと仕様書を確認することを忘れずに。"
        ;;
        
    3)
        echo ""
        echo "📤 全workerに状態確認を指示します..."
        for i in {1..5}; do
            ./agent-send.sh $PROJECT_NAME worker$i "作業を再開します。現在の作業状態を確認し、仕様書に従って作業を継続してください。"
        done
        ;;
        
    4)
        echo ""
        echo "📊 開発ログ全体を表示します..."
        less development/development_log.txt
        ;;
        
    5)
        echo ""
        echo "📄 仕様書を再変換・配布します..."
        ./scripts/convert_spec.sh
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RESUME] [$PROJECT_NAME] [SYSTEM] 仕様書再変換・配布" >> development/development_log.txt
        
        # 全エージェントに通知
        ./agent-send.sh $PROJECT_NAME boss1 "仕様書が再配布されました。specifications/project_spec.md を確認してください。"
        for i in {1..5}; do
            ./agent-send.sh $PROJECT_NAME worker$i "仕様書が再配布されました。specifications/project_spec.md を確認してください。"
        done
        ;;
        
    6)
        echo ""
        echo "🔄 新しいサイクルを開始します..."
        # 完了ファイルをクリア
        rm -f ./tmp/worker*_done.txt
        
        # 新サイクル開始
        NEXT_CYCLE=$((CYCLE_NUM + 1))
        touch ./tmp/cycle_${NEXT_CYCLE}.txt
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [RESUME] [$PROJECT_NAME] [SYSTEM] サイクル${NEXT_CYCLE}開始" >> development/development_log.txt
        
        ./agent-send.sh $PROJECT_NAME boss1 "サイクル${NEXT_CYCLE}を開始してください。仕様書を確認して、全workerに適切な指示を出してください。"
        ;;
        
    7)
        echo ""
        echo "📤 手動メッセージ送信"
        echo -n "送信先 (president/boss1/worker1-5): "
        read TARGET
        echo -n "メッセージ: "
        read MESSAGE
        
        ./agent-send.sh $PROJECT_NAME $TARGET "$MESSAGE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [MANUAL] [$PROJECT_NAME] [SYSTEM] $TARGET へ手動メッセージ送信" >> development/development_log.txt
        ;;
        
    0)
        echo "終了します。"
        exit 0
        ;;
        
    *)
        echo "無効な選択です。"
        exit 1
        ;;
esac

echo ""
echo "✅ 処理が完了しました。"
echo ""
echo "💡 ヒント:"
echo "- tmuxでペインを確認: tmux attach -t $PROJECT_NAME"
echo "- 開発ログを監視: tail -f development/development_log.txt"
echo "- 自動サイクルを開始: ./boss-auto-cycle.sh $PROJECT_NAME"