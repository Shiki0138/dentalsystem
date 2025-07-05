# 📜 スクリプト使用方法ガイド

## 🔄 URL一括置換スクリプト

### 基本使用方法
```bash
# デフォルトURL使用（Render.com）
./scripts/url_batch_replace.sh

# カスタムURL指定
./scripts/url_batch_replace.sh https://your-custom-domain.com

# 特定ファイルパターン指定
./scripts/url_batch_replace.sh https://your-domain.com "*.html"
```

### 実行例
```bash
# 1. Renderの本番URL取得後
./scripts/url_batch_replace.sh https://dentalsystem-abcd123.onrender.com

# 2. 実行結果
🔄 URL一括置換スクリプト開始
============================================
新しいURL: https://dentalsystem-abcd123.onrender.com
検索パターン: *.md

📋 対象ファイル一覧:
     1	./ULTIMATE_ACCESS_GUIDE.md
     2	./QUICK_START_GUIDE.md
     3	./ADVANCED_TROUBLESHOOTING.md

🔍 プレースホルダー含有ファイル確認中...
  ./ULTIMATE_ACCESS_GUIDE.md: 12箇所
  ./QUICK_START_GUIDE.md: 8箇所  
  ./ADVANCED_TROUBLESHOOTING.md: 15箇所

📊 置換対象: 35箇所

⚠️  置換を実行しますか？ (y/N): y

💾 バックアップ作成中...
  ✅ ./ULTIMATE_ACCESS_GUIDE.md → ./url_backup_20250704_123456/./ULTIMATE_ACCESS_GUIDE.md

🔄 URL置換実行中...
  ✅ ./ULTIMATE_ACCESS_GUIDE.md: 12箇所置換

🎉 URL置換完了！
📊 置換実績:
  - 対象ファイル: 3件
  - 置換箇所: 35箇所
  - バックアップ: ./url_backup_20250704_123456/

✅ 全てのプレースホルダーが正常に置換されました
```

### 機能特徴
```yaml
✅ 自動バックアップ作成
✅ 置換前確認プロンプト
✅ macOS/Linux両対応
✅ 置換結果検証
✅ Git commit支援
✅ 古いURL検出
✅ 安全な処理（50ファイル制限）
```

### 安全機能
```yaml
🛡️ バックアップ:
- 置換前に全ファイルをバックアップ
- ディレクトリ構造保持
- タイムスタンプ付きフォルダ

🔍 検証:
- 置換後のプレースホルダー残存確認
- 古いURLパターン検出
- 置換箇所数カウント

⚠️ 制限:
- 一度に50ファイルまで処理
- 確認プロンプトで誤操作防止
- 読み取り専用ファイル保護
```

## 🚀 使用シナリオ

### シナリオ1: Render本番URL確定時
```bash
# 1. Renderデプロイ完了後、URLを確認
# https://dentalsystem-xyz789.onrender.com

# 2. 一括置換実行
./scripts/url_batch_replace.sh https://dentalsystem-xyz789.onrender.com

# 3. 動作確認
# 各ドキュメントの{{PRODUCTION_URL}}が実URLに変更されている

# 4. Git commit
git add -A
git commit -m "本番URL更新完了"
```

### シナリオ2: 代替環境への切替
```bash
# Railway環境に切替
./scripts/url_batch_replace.sh https://dentalsystem-production.up.railway.app

# Fly.io環境に切替  
./scripts/url_batch_replace.sh https://dentalsystem.fly.dev
```

### シナリオ3: 復旧・ロールバック
```bash
# バックアップから復旧
cp -r ./url_backup_20250704_123456/* ./

# または元のプレースホルダーに戻す
./scripts/url_batch_replace.sh "{{PRODUCTION_URL}}" "*.md"
```

## 📋 対象ファイル

### 自動対象ファイル
```yaml
✅ Markdownファイル (*.md):
- ULTIMATE_ACCESS_GUIDE.md
- QUICK_START_GUIDE.md  
- ADVANCED_TROUBLESHOOTING.md
- DENTAL_REVOLUTION_ACCESS_GUIDE.md
- PRODUCTION_USER_MANUAL.md
- その他全*.mdファイル

オプション対象:
- HTMLファイル (*.html)
- 設定ファイル (*.yml, *.json)
- ドキュメント (*.txt)
```

### 除外ファイル
```yaml
❌ 自動除外:
- バックアップディレクトリ
- .git ディレクトリ
- node_modules
- vendor ディレクトリ
- 隠しファイル (.*ファイル)
```

## 🔧 トラブルシューティング

### よくある問題
```yaml
❓ 権限エラー:
解決: chmod +x ./scripts/url_batch_replace.sh

❓ sedコマンドエラー:
解決: macOS/Linux自動判定済み、手動確認不要

❓ バックアップ容量不足:
解決: 古いバックアップフォルダ削除

❓ Git commitエラー:  
解決: 手動でgit add/commit実行
```

### 高度な使用方法
```bash
# HTMLファイルも対象に
./scripts/url_batch_replace.sh https://example.com "*.html"

# 複数パターン一括（要手動実行）
find . -name "*.md" -o -name "*.html" | xargs -I {} \
  ./scripts/url_batch_replace.sh https://example.com {}

# 特定ディレクトリのみ
cd docs/
../scripts/url_batch_replace.sh https://example.com

# Dry run（実際の置換なし）
grep -r "{{PRODUCTION_URL}}" *.md
```

## 📊 実行ログ例

```
🔄 URL一括置換スクリプト開始
============================================
新しいURL: https://dentalsystem-production.onrender.com
検索パターン: *.md

📁 バックアップディレクトリ作成: ./url_backup_20250704_001234

🔍 対象ファイル検索中...
📋 対象ファイル一覧:
     1	./ULTIMATE_ACCESS_GUIDE.md
     2	./QUICK_START_GUIDE.md
     3	./ADVANCED_TROUBLESHOOTING.md
     4	./DENTAL_REVOLUTION_ACCESS_GUIDE.md
     5	./PRODUCTION_USER_MANUAL.md

🔍 プレースホルダー含有ファイル確認中...
  ./ULTIMATE_ACCESS_GUIDE.md: 15箇所
  ./QUICK_START_GUIDE.md: 8箇所
  ./ADVANCED_TROUBLESHOOTING.md: 22箇所

📊 置換対象: 45箇所

⚠️  置換を実行しますか？ (y/N): y

💾 バックアップ作成中...
  ✅ ./ULTIMATE_ACCESS_GUIDE.md → ./url_backup_20250704_001234/./ULTIMATE_ACCESS_GUIDE.md
  ✅ ./QUICK_START_GUIDE.md → ./url_backup_20250704_001234/./QUICK_START_GUIDE.md
  ✅ ./ADVANCED_TROUBLESHOOTING.md → ./url_backup_20250704_001234/./ADVANCED_TROUBLESHOOTING.md

🔄 URL置換実行中...
  ✅ ./ULTIMATE_ACCESS_GUIDE.md: 15箇所置換
  ✅ ./QUICK_START_GUIDE.md: 8箇所置換
  ✅ ./ADVANCED_TROUBLESHOOTING.md: 22箇所置換

============================================
🎉 URL置換完了！
📊 置換実績:
  - 対象ファイル: 3件
  - 置換箇所: 45箇所
  - バックアップ: ./url_backup_20250704_001234/

🔍 置換結果確認:
✅ 全てのプレースホルダーが正常に置換されました

🔍 追加置換候補確認:
古いURL（Heroku等）が残っている可能性があります:
  herokuapp.com: 12箇所発見
  localhost:3000: 5箇所発見

============================================
🚀 URL一括置換完了！
次のステップ:
1. 置換結果の動作確認
2. 必要に応じて古いURL（Heroku等）の手動置換
3. バックアップファイルの保管/削除判断
4. Git commitの実行

バックアップ: ./url_backup_20250704_001234/
新しいURL: https://dentalsystem-production.onrender.com

Git commitを実行しますか？ (y/N): y

📝 Git commit実行中...
✅ Git commit完了

🎊 URL一括置換処理完了！
```

---

*スクリプト使用方法ガイド v1.0 / 2025-07-04*  
*制作: worker4 / 効率最大化チーム*