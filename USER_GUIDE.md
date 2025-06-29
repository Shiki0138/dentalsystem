# 🚀 Dental System ユーザーガイド

## 📌 はじめに

Dental Systemは、tmuxとClaude Codeを活用したマルチエージェント開発システムです。
複数のAIエージェントが協調して歯科医院管理システムを開発します。

## 🎯 システムの特徴

- **完全自動起動**: tmuxセッション、ペイン分割、Claude Code起動まで全自動
- **シンプルな操作**: 1コマンドで全システム起動
- **自動監視**: 5分間隔でシステム状態を監視、問題があればboss1に通知
- **効率的な開発**: 6人のエージェントが同時並行で開発

## 🚀 クイックスタート

### ステップ1: システム起動
```bash
# 全システムを1コマンドで起動
./start.sh dentalsystem
```

これだけで以下が自動実行されます：
- ✅ tmuxセッション作成（エージェント用、プレジデント用）
- ✅ 6ペイン + 1ペインの自動分割
- ✅ 全ペインでClaude Code起動
- ✅ 監視システム起動（5分間隔）

### ステップ2: セッション確認
```bash
# 起動したセッションを確認
tmux ls

# 出力例：
dentalsystem_multiagent: 1 windows
dentalsystem_president: 1 windows
```

### ステップ3: セッションに接続
```bash
# エージェントの画面を見る
tmux attach-session -t dentalsystem_multiagent

# プレジデントの画面を見る
tmux attach-session -t dentalsystem_president
```

### ステップ4: 開発開始
```bash
# PRESIDENTに開始指示を送信
./agent-send.sh dentalsystem president "あなたはpresidentです。指示書に従って"
```

## 📱 tmuxの基本操作

### セッション操作
- **セッションから離脱**: `Ctrl+b`, `d`
- **セッション一覧表示**: `tmux ls`
- **セッションに再接続**: `tmux attach-session -t [セッション名]`

### ペイン操作（セッション内）
- **ペイン間移動**: `Ctrl+b`, 矢印キー
- **ペイン番号で移動**: `Ctrl+b`, `q`, 番号
- **ペインをスクロール**: `Ctrl+b`, `[`, 矢印キー（`q`で終了）

## 🔧 個別起動（必要な場合）

```bash
# エージェントのみ起動
./setup-agents.sh dentalsystem

# プレジデントのみ起動
./setup-president.sh dentalsystem
```

## 📨 メッセージ送信

```bash
# 基本形式
./agent-send.sh [プロジェクト名] [エージェント名] "[メッセージ]"

# 例
./agent-send.sh dentalsystem boss1 "エラーを確認してください"
./agent-send.sh dentalsystem worker1 "テストを実行してください"
```

## 🛡️ 監視システムについて

- **自動起動**: setup-president.sh実行時に自動起動
- **監視間隔**: 5分ごと
- **通知先**: boss1のチャットボックス
- **通知条件**: 
  - エラー3件以上
  - Worker停滞2人以上
- **スマート通知**: boss1が稼働中は通知をスキップ

## 🎯 エージェントの役割

### PRESIDENT（1ペイン）
- プロジェクト統括
- 開発ルール管理
- 品質承認

### boss1（ペイン0）
- チームリーダー
- タスク配分
- 監視通知受信

### worker1-5（ペイン1-5）
- 開発実行
- 相互連携
- 進捗報告

## 📝 重要なファイル

### 開発ルール
```bash
# 必ず遵守すべきルール（デプロイ考慮開発を含む）
cat development/development_rules.md
```

### プロジェクト仕様書
```bash
# プロジェクトの詳細仕様
cat specifications/project_spec.md

# 仕様書を編集した場合の変換
./scripts/convert_spec.sh
```

### 開発ログ
```bash
# 全ての作業履歴
cat development/development_log.txt

# リアルタイムで監視
tail -f development/development_log.txt
```

## ❓ トラブルシューティング

### Q: セッションが見つからない
```bash
# セッション一覧を確認
tmux ls

# システムを再起動
./start.sh dentalsystem
```

### Q: Claude Codeが起動していない
```bash
# 手動で起動（通常は不要）
tmux send-keys -t [セッション名]:[ペイン番号] 'claude --dangerously-skip-permissions' C-m
```

### Q: 監視システムの状態確認
```bash
# プロセス確認
ps aux | grep monitor_dentalsystem

# 環境変数確認
cat .env_dentalsystem
```

### Q: 開発が停滞している
```bash
# 開発ログを確認
tail -50 development/development_log.txt

# 監視システムが5分ごとに自動チェックしていますが、
# 手動で状況確認を送ることも可能
./agent-send.sh dentalsystem boss1 "現在の状況を報告してください"
```

## 💡 便利なコマンド

```bash
# システム状態確認
./scripts/monitoring-unified.sh dentalsystem check

# 開発ログ確認
tail -f development/development_log.txt

# 仕様書変換
./scripts/convert_spec.sh

# 高度な管理（必要な場合のみ）
./claude-auto-manager.sh dentalsystem status
```

## 📋 開発フロー

1. **起動**: `./start.sh dentalsystem`
2. **指示**: PRESIDENTに開始指示
3. **監視**: 自動監視が問題を検出
4. **開発**: エージェントが協調作業
5. **確認**: セッションに接続して進捗確認

## 🏆 ベストプラクティス

### 1. デプロイを考慮した開発
- ローカルと本番環境の差異を常に意識
- 環境変数の完全なドキュメント化
- 依存関係の明確な管理

### 2. 定期的な状況確認
```bash
# 開発ログを定期的に確認
tail -f development/development_log.txt

# システムヘルスチェック
./scripts/monitoring-unified.sh dentalsystem check
```

### 3. 仕様書の更新時
```bash
# 仕様書を編集
vim specifications/project_spec.txt

# 変換・配布
./scripts/convert_spec.sh

# 全エージェントに通知
./agent-send.sh dentalsystem boss1 "仕様書が更新されました"
```

## 🎉 まとめ

Dental Systemは、複雑なマルチエージェント開発を簡単に実現します。
1コマンドで全てが起動し、自動監視により安定した開発が可能です。

開発ルールを遵守し、デプロイ時のエラーを未然に防ぐ開発を心がけましょう！

困ったときは開発ログとこのガイドを確認してください！