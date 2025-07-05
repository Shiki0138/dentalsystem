# 🛡️ 歯科業界革命システム バックアップ戦略

**策定日:** 2025-07-04  
**策定者:** worker5  
**対象システム:** 歯科クリニック予約・業務管理システム  
**目標:** 史上最強の事業継続性を実現

---

## 📋 バックアップ戦略概要

### 🎯 RTO/RPO目標
- **RTO (Recovery Time Objective)**: **30分以内**
- **RPO (Recovery Point Objective)**: **5分以内**
- **年間稼働率目標**: **99.99%**（ダウンタイム52.6分/年）

### 🔄 3-2-1ルール適用
- **3つのコピー**: 本番データ + 2つのバックアップ
- **2つの異なるメディア**: ローカルディスク + クラウドストレージ
- **1つのオフサイト**: AWS S3（別リージョン）

---

## 🗄️ バックアップ対象と頻度

### 1. データベース（PostgreSQL）
| バックアップタイプ | 頻度 | 保存期間 | 保存先 |
|----------------|------|---------|--------|
| **フルバックアップ** | 毎日 02:00 | 30日間 | S3 + ローカル |
| **差分バックアップ** | 6時間毎 | 7日間 | S3 + ローカル |
| **トランザクションログ** | 5分毎 | 3日間 | S3（即時転送） |
| **論理バックアップ** | 週1回 | 90日間 | S3（圧縮） |

### 2. アプリケーションデータ
| データ種別 | バックアップ頻度 | 保存期間 | 特記事項 |
|----------|--------------|---------|---------|
| **アップロードファイル** | リアルタイム | 永続 | S3に即時同期 |
| **設定ファイル** | 変更時 | 無期限 | Git + S3 |
| **ログファイル** | 日次 | 90日間 | S3（圧縮） |
| **セッションデータ** | - | - | Redisレプリケーション |

### 3. システム構成
| 対象 | バックアップ方法 | 頻度 | 保存先 |
|-----|---------------|------|--------|
| **Dockerイメージ** | レジストリプッシュ | ビルド時 | ECR |
| **インフラ構成** | Terraform state | 変更時 | S3（暗号化） |
| **シークレット** | AWS Secrets Manager | 変更時 | 自動レプリケーション |

---

## 🚀 バックアップ実装

### PostgreSQLバックアップスクリプト
```bash
#!/bin/bash
# /opt/backup/postgres-backup.sh

set -euo pipefail

# 設定
DB_NAME="dental_production"
BACKUP_DIR="/backup/postgres"
S3_BUCKET="dental-revolution-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# バックアップ実行関数
perform_backup() {
    local backup_type=$1
    local backup_file="${BACKUP_DIR}/${backup_type}_${TIMESTAMP}.sql.gz"
    
    echo "[$(date)] Starting ${backup_type} backup..."
    
    case $backup_type in
        "full")
            pg_dump -Fc -Z9 $DB_NAME > "${backup_file}"
            ;;
        "incremental")
            pg_basebackup -D "${BACKUP_DIR}/base_${TIMESTAMP}" -Ft -z -P
            ;;
        "wal")
            rsync -av $PGDATA/pg_wal/ "${BACKUP_DIR}/wal/"
            ;;
    esac
    
    # S3にアップロード
    aws s3 cp "${backup_file}" "s3://${S3_BUCKET}/postgres/${backup_type}/" \
        --storage-class STANDARD_IA \
        --server-side-encryption AES256
    
    # 成功通知
    notify_backup_status "success" "${backup_type}"
}

# 保存期間管理
cleanup_old_backups() {
    # ローカルクリーンアップ
    find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete
    
    # S3ライフサイクルポリシー適用確認
    aws s3api get-bucket-lifecycle-configuration --bucket $S3_BUCKET
}

# 整合性検証
verify_backup() {
    local backup_file=$1
    
    # チェックサム検証
    sha256sum -c "${backup_file}.sha256"
    
    # テストリストア（別環境）
    pg_restore --list "${backup_file}" > /dev/null
}

# 監視通知
notify_backup_status() {
    local status=$1
    local backup_type=$2
    
    curl -X POST $SLACK_WEBHOOK_URL \
        -H 'Content-Type: application/json' \
        -d "{\"text\":\"Backup ${status}: ${backup_type} at ${TIMESTAMP}\"}"
}

# メイン処理
main() {
    perform_backup "full"
    verify_backup "${BACKUP_DIR}/full_${TIMESTAMP}.sql.gz"
    cleanup_old_backups
}

main "$@"
```

### 自動バックアップCronジョブ
```cron
# /etc/cron.d/dental-backup

# PostgreSQL フルバックアップ（毎日2時）
0 2 * * * postgres /opt/backup/postgres-backup.sh full

# PostgreSQL 差分バックアップ（6時間毎）
0 */6 * * * postgres /opt/backup/postgres-backup.sh incremental

# WALアーカイブ（5分毎）
*/5 * * * * postgres /opt/backup/postgres-backup.sh wal

# アプリケーションファイル同期（毎時）
0 * * * * root aws s3 sync /app/storage s3://dental-revolution-backups/files/

# ログローテーション&バックアップ（毎日3時）
0 3 * * * root /opt/backup/log-backup.sh
```

### S3バケットポリシー
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DentalBackupAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/dental-backup-role"
      },
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::dental-revolution-backups/*",
        "arn:aws:s3:::dental-revolution-backups"
      ]
    },
    {
      "Sid": "RequireEncryption",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::dental-revolution-backups/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "AES256"
        }
      }
    }
  ]
}
```

---

## 🔄 リストア手順

### 1. 緊急時リストア（RTO: 30分）
```bash
#!/bin/bash
# emergency-restore.sh

# 1. 最新バックアップ取得
LATEST_BACKUP=$(aws s3 ls s3://dental-revolution-backups/postgres/full/ | tail -1 | awk '{print $4}')
aws s3 cp "s3://dental-revolution-backups/postgres/full/${LATEST_BACKUP}" /tmp/

# 2. データベース停止
docker-compose stop app
docker-compose stop postgres

# 3. リストア実行
docker-compose run --rm postgres pg_restore \
    --clean --if-exists --no-owner --no-privileges \
    -d dental_production "/tmp/${LATEST_BACKUP}"

# 4. サービス再開
docker-compose up -d

# 5. ヘルスチェック
curl -f http://localhost/health || exit 1

echo "緊急リストア完了: $(date)"
```

### 2. ポイントインタイムリカバリ（PITR）
```bash
#!/bin/bash
# point-in-time-recovery.sh

TARGET_TIME="2025-07-04 12:00:00"

# 1. ベースバックアップリストア
pg_basebackup -D /var/lib/postgresql/restore -R

# 2. recovery.conf設定
cat > /var/lib/postgresql/restore/recovery.conf <<EOF
restore_command = 'aws s3 cp s3://dental-revolution-backups/wal/%f %p'
recovery_target_time = '${TARGET_TIME}'
recovery_target_action = 'promote'
EOF

# 3. PostgreSQL起動
pg_ctl -D /var/lib/postgresql/restore start
```

---

## 📊 バックアップ監視

### 監視項目
| 項目 | 閾値 | アラート |
|-----|------|---------|
| バックアップ成功率 | < 99% | Critical |
| バックアップ所要時間 | > 30分 | Warning |
| ストレージ使用率 | > 80% | Warning |
| 最終バックアップ経過時間 | > 24時間 | Critical |

### 監視ダッシュボード
```yaml
# Prometheus監視ルール
groups:
  - name: backup_monitoring
    rules:
      - alert: BackupFailed
        expr: backup_success_rate < 0.99
        for: 5m
        annotations:
          summary: "バックアップ失敗率が上昇"
          
      - alert: BackupDelayed
        expr: time() - backup_last_success_timestamp > 86400
        annotations:
          summary: "24時間以上バックアップが実行されていません"
```

---

## 🧪 災害復旧テスト計画

### 四半期毎のDRテスト
1. **フルリストアテスト**（所要時間: 2時間）
   - 本番環境の完全復元
   - データ整合性確認
   - アプリケーション動作確認

2. **部分リストアテスト**（所要時間: 30分）
   - 特定テーブルのみ復元
   - 特定期間のデータ復元

3. **フェイルオーバーテスト**（所要時間: 1時間）
   - レプリカへの切り替え
   - DNS切り替え確認
   - 監視アラート確認

### テスト成功基準
- RTO達成率: 100%
- RPO達成率: 100%
- データ整合性: 100%
- アプリケーション正常動作: 100%

---

## 🚨 緊急連絡体制

### エスカレーションフロー
1. **Level 1** (0-15分): オンコールエンジニア対応
2. **Level 2** (15-30分): チームリーダーエスカレーション
3. **Level 3** (30分以上): CTO/経営層通知

### 連絡先
- **オンコール**: #oncall-dental-revolution
- **緊急電話**: 080-xxxx-xxxx（24時間対応）
- **ステータスページ**: https://status.dental-revolution.com

---

## 📈 継続的改善

### 月次レビュー項目
- バックアップ成功率分析
- リストア時間の最適化
- ストレージコスト最適化
- 新技術の評価（増分永久バックアップ等）

### 改善目標
- RTO: 30分 → 15分（6ヶ月以内）
- RPO: 5分 → 1分（1年以内）
- ストレージコスト: 20%削減（年間）

---

**策定完了:** 歯科業界革命を支える鉄壁のバックアップ戦略を確立