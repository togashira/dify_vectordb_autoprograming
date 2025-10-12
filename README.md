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

## 4. よくあるトラブル

- 8080 へアクセスすると 502/504: 起動直後は API が初期化中の可能性。30-60秒待ってリロード。
- ブラウザ拡張MetaMask等でコンソールエラー: 他ウォレット拡張と競合する場合あり。別プロファイル/シークレットウィンドウで回避可。
- ポート衝突: `docker compose ps` で使用状況を確認し、.env のポートを変更。

## 5. アンインストール（データ消去）

```bash
docker compose down -v
```

## 6. ライセンス

このテンプレート自体は MIT ライセンス（必要に応じて変更可）。Dify本体のライセンスは公式に従います。
