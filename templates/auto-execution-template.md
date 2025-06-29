# 🤖 自動実行テンプレート

## 📋 boss1向け自動実行指示

### コメント欄で停滞しない自動実行方法

```bash
# 1. 受信後即座に実行（待機なし）
echo "指示受信 - 即座に実行開始"

# 2. コマンドを実行
[実行するコマンド]

# 3. 完了ログ記録
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AUTO_EXEC] [$PROJECT_NAME] [boss1] 自動実行完了: [コマンド内容]" >> development/development_log.txt

# 4. 即座に次の指示送信（待機せずに）
./agent-send.sh $PROJECT_NAME worker1 "次の指示"
./agent-send.sh $PROJECT_NAME worker2 "次の指示"
# (以下同様)

# 5. バックグラウンド処理開始
[監視コマンド] &

echo "自動実行サイクル開始"
```

## 🚨 停滞防止の重要ポイント

### ❌ 避けるべき行動
- コメント欄での長時間待機
- ユーザー入力待ち
- 手動確認の要求
- 複数段階の承認プロセス

### ✅ 推奨する行動
- 受信即座の実行
- ログ記録の自動化
- バックグラウンド処理の活用
- 連続指示の送信

## 📝 自動実行スクリプトテンプレート

```bash
#!/bin/bash
# boss1-auto-execution.sh

PROJECT_NAME=${1:-dentalsystem}
COMMAND=${2:-"default_command"}

echo "=== 自動実行開始 ==="
echo "プロジェクト: $PROJECT_NAME"
echo "コマンド: $COMMAND"

# 即座に実行
eval "$COMMAND"

# ログ記録
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AUTO_EXEC] [$PROJECT_NAME] [boss1] $COMMAND" >> development/development_log.txt

# 次の指示を自動送信
for i in {1..5}; do
    ./agent-send.sh $PROJECT_NAME worker$i "自動実行サイクル継続"
done

echo "=== 自動実行完了 ==="
```

## 🔄 継続的自動実行システム

### バックグラウンド監視の開始
```bash
# 監視システムを30分間隔で自動実行
./scripts/monitoring-unified.sh dentalsystem continuous &

# プロセスIDを記録
echo $! > ./tmp/monitoring_pid.txt
```

### 自動サイクルの維持
```bash
# 無限ループでの自動指示送信
while true; do
    # 全workerに指示送信
    for i in {1..5}; do
        ./agent-send.sh $PROJECT_NAME worker$i "継続作業実行"
    done
    
    # 30分待機
    sleep 1800
done &
```

## 📊 自動実行ログフォーマット

```
[YYYY-MM-DD HH:MM:SS] [AUTO_EXEC] [PROJECT_NAME] [AGENT] [ACTION] 詳細内容
```

### 例
```
[2025-06-29 23:15:00] [AUTO_EXEC] [dentalsystem] [boss1] MONITORING_START バックグラウンド監視開始
[2025-06-29 23:15:01] [AUTO_EXEC] [dentalsystem] [boss1] WORKER_NOTIFY 全worker自動指示送信完了
```