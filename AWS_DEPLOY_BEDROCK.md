# AWS 展開ガイド（Bedrock: Titan v2 Embeddings + Claude 2）

本ドキュメントは、ローカルで作成した Dify 環境を AWS にデプロイする際の実践ガイドです。要件は以下の通り:
- Embeddings: Amazon Bedrock Titan v2（例: `amazon.titan-embed-text-v2`）
- Chat Model: Bedrock Claude 2（例: `anthropic.claude-v2`／`anthropic.claude-v2:1`）
- NAT なし（Private サブネット + VPC エンドポイント）で AWS 内完結運用

注意: モデルID/提供リージョンは時期により変化します。利用リージョンで `list-foundation-models` の結果を確認して選択してください。

## 1. アーキテクチャ概要
- ECS Fargate（awsvpc）上に Dify: `api`/`web`/`worker` コンテナをデプロイ
- データ: RDS for PostgreSQL（pgvector拡張有効）、ElastiCache Redis（Celeryブローカー兼キャッシュ）
- ALB: `Host=dify.<domain>` → `web:3000`、`Path=/console/api/*` → `api:5001`
- NAT なし運用: 下記 VPC エンドポイントを作成
  - Interface: `com.amazonaws.<region>.ecr.api`, `ecr.dkr`, `logs`, `secretsmanager`, `ssm`, `kms`, `sts`, `bedrock-runtime`
  - Gateway: S3（コンテナpull時や一部SDKのS3アクセス用に推奨）

## 2. コンテナイメージ
- `dify-api`, `dify-web`, `dify-worker`（worker は api イメージ + `MODE=worker`）
- 可能なら ECR にミラー（NAT なしで安定取得するため）
- web の Next.js バンドルが `localhost:5001` を参照してしまう問題に対しては、起動時エントリポイントで `/console/api` に書き換え（本テンプレのローカル構成と同様）か、ビルド時に `NEXT_PUBLIC_API_URL` を正しく注入

## 3. IAM とロール
- Task Execution Role: ECR pull、CloudWatch Logs 出力
- Task Role（アプリ実行権限）:
  - `bedrock:InvokeModel`, `bedrock:InvokeModelWithResponseStream`（モデル ARN/正規表現でスコープ）
  - `kms:Decrypt`（必要に応じ Secrets/SSM を暗号化解除）
  - S3（使用する場合のみ）
- ベストプラクティスとして、最小権限 + 明示スコープ（Model ARN/ログ/パラメータ）

## 4. ネットワークとセキュリティ
- サブネット: Private 2AZ 以上、Public サブネットに ALB
- セキュリティグループ:
  - ALB → ECS タスク: 3000/tcp（web）、5001/tcp（api）を許可
  - タスク → RDS: 5432/tcp、タスク → Redis: 6379/tcp
  - タスク → VPCE: Interface エンドポイントの SG に対し適切に許可
- ALB ルール（HTTPS推奨）:
  - Host: `dify.<domain>` → `dify-webapi-tg`（port 3000）
  - Host + Path: `dify.<domain>` + `/console/api/*` → `dify-api-tg`（port 5001）
- Health Check:
  - web TG: `/`（200）
  - api TG: `/api/openapi.json` もしくは `/health`（Dify バージョンにより応答可否が異なる場合あり）。動作が不安定な場合は `/console/api/system-features` を暫定採用しても良いが、本番は `/api/*` の直指定を推奨。

## 5. 環境変数（代表）
- 共通:
  - `APP_URL` = `https://dify.<domain>`
  - `CONSOLE_URL` = `https://dify.<domain>`
  - `REDIS_URL` = `redis://<redis-endpoint>:6379/0`
  - `CELERY_BROKER_URL` = `redis://<redis-endpoint>:6379/1`
  - `DATABASE_URL` = `postgresql://<user>:<pass>@<rds-endpoint>:5432/<db>`
  - `SECRET_KEY` = ランダム安全値（Secrets Manager 推奨）
- web（必要に応じて）:
  - `NEXT_PUBLIC_API_URL` = `https://dify.<domain>/console/api`
- API からの Bedrock 利用は、基本的に Dify の管理画面 Settings → Model Providers で Bedrock を選択し、リージョンを指定。ECS の Task Role で権限付与していれば、キーを直記不要（ローカルキー無指定で IAM 経由呼び出し）。

## 6. Dify 設定（Bedrock）
1) Dify コンソール → Settings → Model Providers → Amazon Bedrock を有効化
2) Region を指定（例: `ap-northeast-1`）
3) Embedding Model に Titan v2 を選択（例: `amazon.titan-embed-text-v2`）
4) Chat Model に Claude 2 を選択（例: `anthropic.claude-v2`）
5) 保存してテスト

補足: モデルの地域提供状況により、`anthropic.claude-3` 系が推奨される場合があります。要件が「Claude 2 固定」の場合は、利用リージョンの提供可否を事前に確認してください。

## 7. ストレージ（任意）
- オブジェクトストレージとして S3 を用いる場合、Dify 側の Storage 設定で S3 を指定し、VPCE/S3権限を付与

## 8. デプロイ手順の流れ（概略）
1) ECR リポジトリ作成 & イメージ push（api/web/worker）
2) RDS（pgvector）、ElastiCache（Redis）用意
3) VPC エンドポイント作成（上記）
4) IAM ロール（Execution/Task）作成 & 権限付与
5) ECS タスク定義（環境変数/ポート/ログ/ヘルスチェック）
6) ECS サービス（`dify-webapi`）作成（2つの TG をマッピング: web:3000 と api:5001）
7) ALB HTTPS リスナーとルール（Host/Path）
8) ACM 証明書（DNS 検証）+ Route53/Cloudflare 側 DNS 設定
9) Dify コンソールで Bedrock モデルを設定（Titan v2 / Claude 2）
10) ブラウザで確認（キャッシュ無効でハードリロード）

## 9. トラブルシュート
- `502/503/504` 応答:
  - ALB → タスク SG のポート許可（3000/5001）を確認
  - TG Health Check のパスが適正か
  - ルールの Host/Path の優先度衝突や誤りがないか
- `dify-web` が `127.0.0.1:5001` を参照:
  - `NEXT_PUBLIC_API_URL` を `https://dify.<domain>/console/api` に設定
  - もしくは起動時エントリポイントで静的アセットの置換を実施
- Bedrock エラー:
  - Task Role に `bedrock:InvokeModel` 権限があるか、モデルARN範囲が正しいか
  - VPCE（bedrock-runtime）が紐付いたサブネット/SGで到達可能か

