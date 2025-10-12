# Dify + pgvector 開発環境（Udemy 受講者向け）

ローカルで Dify OSS と PostgreSQL(pgvector) + Redis をすぐに起動できる最小構成です。ブラウザから Dify コンソールにアクセスし、ベクトルDBに文書を取り込み、キャラクターAIの試作が行えます。

- アクセスURL: http://localhost:8080
- Dify Web(内部): http://localhost:3000
- Dify API(内部): http://localhost:5001
- pgAdmin 等は含みません（任意）

## 1. 必要要件
- Docker 24+ / Docker Compose v2+
- CPU/RAM: 2C/4GB 以上推奨
- ポート使用: 8080, 3000, 5001, 6379, 5432

## 2. 使い方

1) .env の作成

```bash
cp .env.example .env
# 必要に応じてパスワード等を編集
```

2) 起動

```bash
docker compose up -d
# 初回はDB初期化のため30-60秒程度お待ちください
```

3) アクセス

- ブラウザで http://localhost:8080 を開く
- 初期セットアップウィザードで管理者ユーザーを作成
- データセット作成→文書アップロード→アプリ作成の順で体験可能

4) ログ確認/停止

```bash
docker compose logs -f --tail=100
docker compose down -v   # ボリュームも削除（データ消去）
```

## 3. 構成

- reverse-proxy: Nginx。`/console/api/*` を `dify-api:5001` へフォワード、その他を `dify-web:3000` へ。
- dify-web: Web UI。起動時に静的JS内の `127.0.0.1:5001` などを `http://localhost:8080/console/api` に書き換えます（entrypoint）。
- dify-api: Dify API。
- dify-worker: バックグラウンドワーカー（APIイメージの MODE=worker）。
- redis: Celery ブローカー兼キャッシュ。
- db: PostgreSQL + pgvector 拡張（`pgvector/pgvector:pg16`）。

## 3.5 最短ルート（20〜30分でキャラAI）

所要目安: 画像の初回pull 5〜10分 + 初期セットアップ 3〜5分 + データセット＆アプリ作成 10〜15分。

1) リポジトリ取得と起動

```bash
git clone https://github.com/togashira/dify_vectordb_autoprograming.git
cd dify_vectordb_autoprograming
cp .env.example .env
docker compose up -d
docker compose logs -f --tail=100   # 初回は30〜60秒ほど待機
```

2) ブラウザでアクセス
- http://localhost:8080 を開く
- 初回セットアップで管理者を作成

3) モデル/埋め込み設定（Difyの画面内）
- Settings → Model Providers で OpenAI などを有効化（API Key 必要）
- Embedding を1つ有効化（例: text-embedding-3-small）

4) データセット作成
- Datasets → New → PDF/テキストを1つアップロード → インデックス化完了まで待つ

5) アプリ（キャラクターAI）作成
- Apps → Create App → Chatflow（または Chatbot）
- ワークフローで Knowledge ノードを追加してデータセットを接続
- System Prompt にキャラ設定（口調/性格/禁止事項など）を記述
- Preview で会話テスト → Publish

これでローカルで「最初の応答」まで到達します。

## 4. よくあるトラブル

- 8080 へアクセスすると 502/504: 起動直後は API が初期化中の可能性。30-60秒待ってリロード。
- ブラウザ拡張MetaMask等でコンソールエラー: 他ウォレット拡張と競合する場合あり。別プロファイル/シークレットウィンドウで回避可。
- ポート衝突: `docker compose ps` で使用状況を確認し、.env のポートを変更。
- Dockerが重い/遅い: Docker Desktop → Resources でメモリ4〜6GBに増やすと安定しやすい（Macの場合）。

## 5. アンインストール（データ消去）

```bash
docker compose down -v
```

## 7. 次のステップ（AWS で公開運用）

ローカルでの体験後は、AWS（ECS Fargate + RDS pgvector + ElastiCache + ALB + HTTPS）へ展開して公開運用が可能です。講座の後半で、以下を扱います。
- コンテナのECRミラー、タスク定義（api/web/worker）
- ALBでのホスト/パスルーティングとHTTPS（ACM）
- Secrets/SSM/KMS、NATレス運用（VPCエンドポイント）
- 監視・ログ（CloudWatch Logs）、トラブル対応（ターゲットヘルス/ルール）

## 6. ライセンス

## 8. Cursor を使って「ぎゃるでれら」を作る

以下の指示書を Cursor に読み込ませて、短時間でキャラクターAIを作れます。
- `cursor/INSTRUCTIONS_GYARU_CINDERELLA.md`
- アップロード用サンプル: `samples/gyaru_cinderella_profile.md`

このテンプレート自体は MIT ライセンス（必要に応じて変更可）。Dify本体のライセンスは公式に従います。
