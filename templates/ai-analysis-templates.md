# 🤖 AI Trio Analysis Templates

## 📋 各AIエージェントの役割と分析テンプレート

### 🎯 PRESIDENT (統括・実行・最終決定)
**役割**: 各AIからの分析結果を統合し、最終的な解決策を実行
**テンプレート**:
```
## 統合分析結果
**問題**: [エラーの概要]
**Claude Code分析**: [実装面の問題]
**Gemini CLI分析**: [環境面の問題]  
**Codex CLI分析**: [コード品質面の問題]

## 最終判断
**原因**: [根本原因]
**解決策**: [実行する解決策]
**優先度**: [高/中/低]
```

### 💻 Claude Code (実装・技術詳細分析)
**役割**: Rails実装、データベース、API等の技術的詳細分析
**分析コマンド**:
```bash
./scripts/ai-send-analysis.sh dentalsystem claude_code implementation "分析結果"
```
**テンプレート**:
```
## 実装分析レポート
**エラータイプ**: [構文エラー/ランタイムエラー/ロジックエラー]
**発生箇所**: [ファイル名:行番号]
**技術的原因**: [具体的な実装問題]
**依存関係**: [関連する機能への影響]
**修正アプローチ**: [推奨する修正方法]
**テスト要件**: [修正後に必要なテスト]
```

### 💎 Gemini CLI (システム環境・設定分析)
**役割**: 環境変数、データベース設定、外部サービス連携等の分析
**分析コマンド**:
```bash
./scripts/ai-send-analysis.sh dentalsystem gemini_cli environment "分析結果"
```
**テンプレート**:
```
## 環境分析レポート
**環境チェック**: [開発/本番/テスト環境の状態]
**設定ファイル**: [config/database.yml, .env等の問題]
**外部依存**: [PostgreSQL, Redis, 外部API等の状態]
**権限問題**: [ファイル権限、データベース権限等]
**ネットワーク**: [ポート使用状況、接続問題]
**推奨アクション**: [環境修正の手順]
```

### 🔧 Codex CLI (コード品質・最適化分析)
**役割**: コード品質、パフォーマンス、セキュリティ面の分析
**分析コマンド**:
```bash
./scripts/ai-send-analysis.sh dentalsystem codex_cli code_quality "分析結果"
```
**テンプレート**:
```
## コード品質分析レポート
**品質スコア**: [現在の品質評価]
**パフォーマンス**: [応答時間、メモリ使用量等]
**セキュリティ**: [脆弱性、セキュリティホール]
**保守性**: [コードの可読性、構造の問題]
**ベストプラクティス**: [Rails規約、設計パターン]
**最適化提案**: [具体的な改善案]
```

## 🔄 協調分析ワークフロー

### Phase 1: 個別分析
1. **Claude Code**: 技術実装面の詳細分析
2. **Gemini CLI**: 環境・設定面の分析
3. **Codex CLI**: コード品質・最適化分析

### Phase 2: 結果統合
1. 各AIがPRESIDENTに分析結果送信
2. PRESIDENTが結果を統合・評価
3. 優先度付けと解決策決定

### Phase 3: 実行
1. PRESIDENTが最終解決策を実行
2. 実行結果を各AIに共有
3. 継続監視と改善サイクル

## 📊 分析結果の送信例

```bash
# Claude Code から実装分析結果を送信
./scripts/ai-send-analysis.sh dentalsystem claude_code implementation \
"Railsアプリケーションの起動エラー。config/application.rbでBootstrapの読み込み順序に問題。Gemfileの依存関係を修正し、bundle installを再実行する必要がある。"

# Gemini CLI から環境分析結果を送信  
./scripts/ai-send-analysis.sh dentalsystem gemini_cli environment \
"PostgreSQL接続設定は正常。Rubyバージョン3.3.8は適切。ポート3000競合のため代替ポート使用推奨。Redis起動済み確認。"

# Codex CLI からコード品質分析結果を送信
./scripts/ai-send-analysis.sh dentalsystem codex_cli code_quality \
"security.rakeに構文エラー。正規表現の記述に問題。削除済みだが、同様のパターンが他のファイルにも存在する可能性。全体的なコードレビューが必要。"
```

## 🎯 成功指標
- **分析精度**: 各AI専門分野での高精度分析
- **協調効率**: AIエージェント間の効果的な情報共有
- **解決速度**: 統合分析による迅速な問題解決
- **品質向上**: 多角的分析による根本原因の特定