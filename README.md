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

**重要**: `.env` ファイルの `POSTGRES_PASSWORD` と `docker-compose.yml` のデフォルト値が一致していることを確認してください。不一致の場合、データベース接続エラーが発生します。

2) 起動

```bash
docker compose up -d
# 初回はDB初期化のため30-60秒程度お待ちください
```

3) データベースマイグレーション（初回のみ必須）

```bash
# データベーステーブルを作成
docker compose exec dify-api flask db upgrade
```

4) アクセス

- ブラウザで http://localhost:8080 を開く
- **重要**: 初回は `/install` ページにアクセスして初期セットアップを完了
- 管理者ユーザーを作成（メールアドレス、名前、パスワードを設定）
- セットアップ完了後、http://localhost:8080/apps でメイン画面にアクセス可能
- データセット作成→文書アップロード→アプリ作成の順で体験可能

5) ログ確認/停止

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

## 4. ベクトルDB戦略の選択

このプロジェクトを開始する前に、pgvectorの運用戦略を選択してください。用途・規模・チーム体制に応じて最適なアプローチが異なります。

### 選択肢

#### 【選択肢 A】Dify + pgvector デフォルト構成（推奨・本テンプレート採用）

Difyが自動管理するpgvectorをそのまま使用。インデックスタイプ・距離メトリック・検索パラメータはすべてDify側で制御されます。

**✅ 推奨シーン:**
- ベクトル数: 〜10万件程度
- 用途: 学習、プロトタイプ、MVP、小〜中規模アプリ
- チーム: 個人〜小規模（DBA不在でもOK）
- 開発速度: 最速で動かしたい
- 保守: シンプルさ・保守性を重視

**メリット:**
- ✅ 設定不要、すぐに使える（5〜10分で起動）
- ✅ Difyのアップデートに自動追従
- ✅ ベストプラクティスが適用される
- ✅ トラブルシューティングが容易
- ✅ ドキュメント・コミュニティサポート豊富

**デメリット:**
- ❌ 検索速度の最適化余地が限定的
- ❌ インデックスタイプを選べない（Difyの判断に依存）
- ❌ 大規模データ（10万件超）では速度低下の可能性
- ❌ 詳細なチューニングができない

**実装難易度:** ⭐☆☆☆☆（初心者OK）

---

#### 【選択肢 B】pgvector 独自最適化 + Dify連携

pgvectorのインデックス（HNSW/IVFFLAT）を独自に構築・最適化し、DifyからはカスタマイズされたDBを参照する構成。

**✅ 推奨シーン:**
- ベクトル数: 10万件以上
- 用途: 本番環境、収益化プロダクト、大規模サービス
- チーム: DBA・インフラエンジニアがいる
- パフォーマンス: レスポンス100ms以下など厳格な要件
- 同時接続: 数百〜数千ユーザー

**メリット:**
- ✅ 検索速度を最大限に最適化可能
- ✅ データ特性に応じたインデックス選択（HNSW/IVFFLAT）
- ✅ パラメータチューニングで精度・速度を調整
- ✅ スケーラビリティの向上

**デメリット:**
- ❌ 初期設定に専門知識が必要（pgvector、SQLチューニング）
- ❌ Difyのマイグレーションと競合するリスク
- ❌ Difyアップデート時に設定の再確認が必要
- ❌ トラブル時の切り分けが複雑
- ❌ 保守コスト増（モニタリング、再インデックス等）

**実装難易度:** ⭐⭐⭐⭐☆（上級者向け）

---

### 判断フローチャート

```
開始
 │
 ├─ ベクトル数は10万件以下？
 │   ├─ YES → 【選択肢 A】Difyデフォルト（推奨）
 │   └─ NO  → 次へ
 │
 ├─ DBA・インフラエンジニアがいる？
 │   ├─ NO  → 【選択肢 A】Difyデフォルト（推奨）
 │   └─ YES → 次へ
 │
 ├─ レスポンス速度に厳格な要件がある？（100ms以下など）
 │   ├─ NO  → 【選択肢 A】Difyデフォルト（推奨）
 │   └─ YES → 【選択肢 B】独自最適化を検討
 │
 └─ 本番環境で収益化している？
     ├─ NO  → 【選択肢 A】Difyデフォルト（推奨）
     └─ YES → 【選択肢 B】独自最適化を検討
```

---

### 比較表

| 項目 | 選択肢 A: Difyデフォルト | 選択肢 B: 独自最適化 |
|------|------------------------|-------------------|
| **初期構築時間** | 5〜10分 | 2〜5日 |
| **検索速度（小規模）** | 十分高速 | やや高速 |
| **検索速度（大規模）** | 低下する可能性 | 最適化可能 |
| **精度調整** | Dify設定のみ | 詳細チューニング可 |
| **保守コスト** | 低い | 高い |
| **Dify更新追従性** | 自動 | 手動確認必要 |
| **トラブル対応** | 容易 | 複雑 |
| **必要スキル** | Docker基礎 | PostgreSQL、pgvector |
| **ドキュメント** | 豊富 | 少ない |
| **推奨データ規模** | 〜10万件 | 10万件〜 |

---

### 本テンプレートの採用戦略

**このリポジトリは【選択肢 A】を採用しています。**

理由:
- 対象: Udemy受講者（学習・プロトタイプ作成）
- 目的: 最短時間でキャラクターAI体験
- 規模: 小〜中規模想定
- 保守性: シンプルさを最優先

**選択肢 Bを希望する場合:**

本テンプレートはそのままでは対応していません。以下の手順で独自に実装してください:

1. `db/init.sql` を作成してHNSW/IVFFLATインデックスを定義
2. `docker-compose.yml` の `db` セクションに初期化スクリプトをマウント
3. Difyのマイグレーション後に手動でインデックス再構築
4. パフォーマンスモニタリングとチューニング

参考リソース:
- pgvector公式: https://github.com/pgvector/pgvector
- HNSW vs IVFFLAT: https://github.com/pgvector/pgvector#indexing

**重要:** 独自最適化はDify公式サポート範囲外です。トラブル時は自己解決が必要です。

---

### よくある質問

**Q1: 後から選択肢Aから選択肢Bに移行できる？**

A: 可能ですが、以下の作業が必要です:
- 既存データのバックアップ
- インデックスの再構築（数時間〜数日）
- Difyとの互換性確認
- 動作検証

データ量が増えてから移行するより、最初から選択肢Bで始める方が効率的です。

**Q2: 選択肢Aでも十分な速度が出る？**

A: 以下の条件であれば十分です:
- ベクトル数: 〜10万件
- 同時接続: 〜100ユーザー
- 検索レスポンス: 500ms〜1秒程度で許容

それ以上の規模・速度が必要な場合は選択肢Bを検討してください。

**Q3: 選択肢Aでパフォーマンス問題が出たらどうする？**

段階的な対応:
1. PostgreSQL/Redisのリソース増強（メモリ、CPU）
2. Dify側の検索パラメータ調整（取得件数、スコア閾値）
3. それでも不足なら選択肢Bへの移行を検討

---

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

2) データベースマイグレーション（初回のみ必須）

```bash
# データベーステーブルを作成
docker compose exec dify-api flask db upgrade
```

3) ブラウザでアクセス
- http://localhost:8080/install を開く（**重要**: `/install` ページにアクセス）
- 初回セットアップで管理者を作成
- セットアップ完了後、http://localhost:8080/apps でメイン画面にアクセス

4) モデル/埋め込み設定（Difyの画面内）
- Settings → Model Providers で OpenAI などを有効化（API Key 必要）
- Embedding を1つ有効化（例: text-embedding-3-small）

5) データセット作成
- Datasets → New → PDF/テキストを1つアップロード → インデックス化完了まで待つ

6) アプリ（キャラクターAI）作成
- Apps → Create App → Chatflow（または Chatbot）
- ワークフローで Knowledge ノードを追加してデータセットを接続
- System Prompt にキャラ設定（口調/性格/禁止事項など）を記述
- Preview で会話テスト → Publish

これでローカルで「最初の応答」まで到達します。

## 5. よくあるトラブル

### 5.1 初期セットアップ関連
- **管理画面が表示されない**: `http://localhost:8080/install` にアクセスして初期セットアップを完了してください
- **ローディング画面から進まない**: データベースマイグレーションが未実行の可能性があります。`docker compose exec dify-api flask db upgrade` を実行してください
- **セットアップAPIエラー**: データベース接続設定を確認してください（`.env` と `docker-compose.yml` のパスワード一致）

### 5.2 接続・起動関連
- **8080 へアクセスすると 502/504**: 起動直後は API が初期化中の可能性。30-60秒待ってリロード
- **データベース接続エラー**: `.env` の `POSTGRES_PASSWORD` と `docker-compose.yml` のデフォルト値が一致しているか確認
- **ポート衝突**: `docker compose ps` で使用状況を確認し、.env のポートを変更
- **Dockerが重い/遅い**: Docker Desktop → Resources でメモリ4〜6GBに増やすと安定しやすい（Macの場合）

### 5.3 ブラウザ関連
- **ブラウザ拡張MetaMask等でコンソールエラー**: 他ウォレット拡張と競合する場合あり。別プロファイル/シークレットウィンドウで回避可
- **API接続エラー**: ブラウザの開発者ツールでネットワークタブを確認し、APIエンドポイントが正しく呼び出されているか確認

### 5.4 トラブルシューティング手順
```bash
# 1. コンテナの状態確認
docker compose ps

# 2. ログ確認
docker compose logs dify-api --tail=20
docker compose logs dify-web --tail=20

# 3. データベース接続確認
docker compose exec dify-api python -c "import psycopg2; conn = psycopg2.connect('postgresql://dify:changeme@db:5432/dify'); print('Connection successful')"

# 4. API動作確認
curl -s http://localhost:8080/console/api/setup

# 5. 再起動
docker compose restart
```

## 6. アンインストール（データ消去）

```bash
docker compose down -v
```

## 7. 重要なナレッジ・ベストプラクティス

### 7.1 バージョン管理（最重要）

#### ✅ 推奨: 安定版を固定
```yaml
# docker-compose.yml
dify-web:
  image: docker.io/langgenius/dify-web:0.11.1  # 固定バージョン
dify-api:
  image: docker.io/langgenius/dify-api:0.11.1
dify-worker:
  image: docker.io/langgenius/dify-api:0.11.1
```

#### ❌ 本番環境で避けるべきパターン
```yaml
dify-web:
  image: docker.io/langgenius/dify-web:latest  # 予期せぬ更新で動かなくなる
```

**理由:**
- `latest`は最新版に自動更新され、予期せぬ変更が入る
- プラグイン機能（0.12.x以降）が不安定でエラーが多発
- 破壊的変更が入る可能性がある

**バージョン選択ガイド:**
- ✅ **0.11.1**: 安定版（推奨・このテンプレートで使用）
- ✅ **0.10.x**: より安定だが古い
- ⚠️ **0.12.x以降**: プラグイン機能追加、不安定
- ❌ **latest**: 本番環境では避ける

### 7.2 プラグイン機能の無効化

#### プラグインエラーとは？
```
エラー例:
Failed to request plugin daemon, url: plugin/[UUID]/management/models
Failed to request plugin daemon, url: plugin/[UUID]/management/install/tasks
```

このエラーは Dify 0.12.x以降で頻発する問題です。

#### 推奨設定（0.11.1 + プラグイン無効化）
```yaml
services:
  dify-web:
    image: docker.io/langgenius/dify-web:0.11.1  # 安定版

  dify-api:
    image: docker.io/langgenius/dify-api:0.11.1  # 安定版
    environment:
      - PLUGIN_ENABLED=false
      - DISABLE_PLUGIN_MANAGER=true

  dify-worker:
    image: docker.io/langgenius/dify-api:0.11.1  # 安定版
    environment:
      - PLUGIN_ENABLED=false
      - DISABLE_PLUGIN_MANAGER=true
```

**理由:**
- ✅ プラグイン機能がないため安定
- ✅ `plugin-daemon`サービス不要
- ✅ エラーが発生しない
- ✅ 基本機能（Knowledge、RAG、Workflow等）は十分に使える
- ✅ 本番環境に適している

**0.12.x以降（latest含む）の問題点:**
- ❌ プラグイン機能追加により不安定
- ❌ `plugin-daemon`サービスが必要（設定が複雑）
- ❌ 公式ドキュメント不足
- ❌ エラーログが大量に出る
- ❌ データベースにプラグイン情報が残り、ダウングレードが困難

**プラグインを使いたい場合（非推奨）:**

```yaml
services:
  # 既存のサービス...

  plugin-daemon:
    image: docker.io/langgenius/dify-plugin-daemon:latest
    ports:
      - "5002:5002"
    environment:
      - PLUGIN_DAEMON_PORT=5002
      - PLUGIN_STORAGE_TYPE=local
      - PLUGIN_STORAGE_LOCAL_ROOT=/app/plugins
    volumes:
      - plugin-data:/app/plugins
    restart: always

  dify-api:
    image: docker.io/langgenius/dify-api:latest  # 0.12.x以降
    environment:
      - PLUGIN_ENABLED=true
      - PLUGIN_DAEMON_URL=http://plugin-daemon:5002

  dify-worker:
    image: docker.io/langgenius/dify-api:latest
    environment:
      - PLUGIN_ENABLED=true
      - PLUGIN_DAEMON_URL=http://plugin-daemon:5002

volumes:
  plugin-data: {}
```

**注意:**
- 設定が複雑で、トラブルシューティングが必要
- ドキュメント不足のため、試行錯誤が必要
- 本番環境では推奨しない

### 7.3 Celery Worker設定の注意点

#### 必須設定（0.11.1の既知バグ対応）
```yaml
dify-worker:
  entrypoint: []  # デフォルトentrypointを無効化
  command: ["/bin/bash", "-c", "cd /app/api && celery -A app.celery worker -P gevent -c 1 --loglevel INFO -Q dataset,generation,mail,ops_trace"]
```

**理由:**
- デフォルトの`entrypoint.sh`にCeleryオプション解析のバグがある
- エラー: `Error: Invalid value for '-l' / '--loglevel': '-Q' is not one of...`
- Embedding処理がキューイングで止まる原因になる

**重要なパラメータ:**
- `-Q dataset,generation,mail,ops_trace`: 処理するキューを明示的に指定
- `-P gevent`: geventプールを使用（推奨）
- `-c 1`: ワーカープロセス数（必要に応じて調整）

### 7.4 データベース設定の多層化

#### 必須: 3種類すべて設定
```yaml
dify-api:
  environment:
    # レイヤー1: 基本的なDB URL
    - DATABASE_URL=postgresql://dify:changeme@db:5432/dify
    
    # レイヤー2: SQLAlchemy用（古いコード）
    - SQLALCHEMY_DATABASE_URI=postgresql://dify:changeme@db:5432/dify
    
    # レイヤー3: 個別パラメータ（新しいコード）
    - DB_HOST=db
    - DB_PORT=5432
    - DB_USERNAME=dify
    - DB_PASSWORD=changeme
    - DB_DATABASE=dify
```

**理由:**
- Difyのコードベースが統一されていない
- 古い部分は`SQLALCHEMY_DATABASE_URI`を参照
- 新しい部分は個別パラメータ(`DB_HOST`等)を参照
- 1つだけ設定すると一部機能が動かない

**トラブル例:**
- `DATABASE_URL`だけ設定 → 接続エラー
- 個別パラメータだけ設定 → 一部APIが500エラー

### 7.5 Redis設定の明示化

#### 推奨設定
```yaml
dify-api:
  environment:
    - REDIS_URL=redis://redis:6379/0
    - CELERY_BROKER_URL=redis://redis:6379/1  # 別DB番号
    - REDIS_HOST=redis
    - REDIS_PORT=6379
    - REDIS_DB=0
```

**理由:**
- デフォルトで`localhost:6379`を参照するコードがある
- Docker環境では`redis`ホスト名が必要
- CeleryとキャッシュでDB番号を分けると安全

**トラブル例:**
- Redis設定なし → ログインできない（500エラー）
- localhost参照 → コンテナ間通信失敗

### 7.6 ベクトルDB（pgvector）設定

#### 必須設定
```yaml
dify-api:
  environment:
    - VECTOR_STORE=pgvector
    - PGVECTOR_HOST=db
    - PGVECTOR_PORT=5432
    - PGVECTOR_USER=dify
    - PGVECTOR_PASSWORD=changeme
    - PGVECTOR_DATABASE=dify
```

**理由:**
- デフォルトは`None`でエラーになる: `Unsupported vector db type None`
- PostgreSQLと同じ接続情報を使う
- 明示的に`pgvector`を指定しないと認識されない

### 7.7 パスワード一致の重要性

#### チェックポイント
```bash
# .env
POSTGRES_PASSWORD=changeme

# docker-compose.yml
environment:
  - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-changeme}  # デフォルト値も一致させる
```

**よくあるミス:**
- `.env`に`changeme`、`docker-compose.yml`に`dify123` → 不一致でDB接続エラー
- `.env`ファイルが読み込まれないケース → デフォルト値が使われる

**確認方法:**
```bash
# コンテナ内の環境変数を確認
docker compose exec dify-api env | grep POSTGRES_PASSWORD
docker compose exec db env | grep POSTGRES_PASSWORD
```

### 7.8 初回マイグレーション必須

#### 必ず実行
```bash
# コンテナ起動後、初回のみ必須
docker compose exec dify-api flask db upgrade
```

**理由:**
- データベーステーブルが作成されていないと500エラー
- `/install`画面がローディングで止まる
- セットアップAPIが`table does not exist`エラー

**所要時間の目安:**
```
初回マイグレーション: 30秒〜1分
  - 全テーブル作成（約50個）
  - インデックス作成
  - 初期データ投入

マイグレーション済み（変更なし）: 5〜15秒
  - バージョンチェックのみ

バージョンアップ時: 15秒〜2分
  - 新テーブル追加
  - カラム追加/変更
  - データ移行

※コンテナ起動直後は遅い（Pythonロード時間含む）
※「INFO [alembic.runtime.migration] Will assume transactional DDL.」が出れば正常動作中
```

**確認方法:**
```bash
# マイグレーション状態を確認
docker compose exec dify-api flask db current

# マイグレーション履歴を確認
docker compose exec dify-api flask db history
```

**マイグレーションが遅い場合:**
```bash
# 1. コンテナが完全に起動するまで待つ（30秒程度）
docker compose ps

# 2. APIログを確認
docker compose logs dify-api --tail=20

# 3. データベース接続確認
docker compose exec db psql -U dify -d dify -c "SELECT 1;"
```

### 7.9 バージョンアップ時の安全な手順

```bash
# 1. バックアップ（必須）
docker compose exec db pg_dump -U dify dify > backup_$(date +%Y%m%d).sql

# 2. イメージバージョン変更
# docker-compose.yml の 0.11.1 → 0.11.2

# 3. コンテナ再作成
docker compose down
docker compose pull
docker compose up -d

# 4. マイグレーション実行
docker compose exec dify-api flask db upgrade

# 5. 動作確認
curl http://localhost:8080/console/api/setup
docker compose logs dify-api --tail=50
```

**注意点:**
- マイナーバージョンアップでも破壊的変更がある可能性
- 必ずバックアップを取る
- 可能ならテスト環境で先に試す

### 7.10 セキュリティ対策

#### 本番環境では必ず実施

```bash
# 1. 強力なパスワード生成
POSTGRES_PASSWORD=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 32)

# 2. .envファイルをGit管理から除外
echo ".env" >> .gitignore

# 3. .envファイルのパーミッション制限
chmod 600 .env

# 4. 不要なポートを閉じる
# docker-compose.ymlでポート公開を最小限に
```

#### APIキー管理
```bash
# OpenAI APIキーは必ず.envに保存
# docker-compose.ymlに直接書かない
OPENAI_API_KEY=sk-xxx...
```

### 7.11 モニタリング・デバッグ

#### ログ確認
```bash
# エラーログのみ表示
docker compose logs dify-api --since 1h | grep -i error

# リアルタイムログ監視
docker compose logs -f dify-api dify-worker

# 特定時間範囲のログ
docker compose logs dify-api --since 2025-01-01T00:00:00 --until 2025-01-01T23:59:59
```

#### リソース監視
```bash
# コンテナのリソース使用状況
docker stats

# ディスク使用量
docker system df
```

#### データベース接続テスト
```bash
# Python経由でDB接続確認
docker compose exec dify-api python -c "from extensions.ext_database import db; print(db.engine.url)"

# psql経由でDB接続確認
docker compose exec db psql -U dify -d dify -c "SELECT COUNT(*) FROM accounts;"
```

### 7.12 バックアップ戦略

#### データベースバックアップ
```bash
# バックアップ作成
docker compose exec db pg_dump -U dify dify > backup.sql

# リストア
cat backup.sql | docker compose exec -T db psql -U dify -d dify
```

#### ボリュームバックアップ
```bash
# PostgreSQLデータ
docker run --rm -v dify_vectordb_autoprograming_pg-data:/data -v $(pwd):/backup alpine tar czf /backup/pg-data-backup.tar.gz /data

# ストレージデータ
docker run --rm -v dify_vectordb_autoprograming_storage-data:/data -v $(pwd):/backup alpine tar czf /backup/storage-backup.tar.gz /data
```

### 7.13 トラブルシューティングチェックリスト

#### 問題: 500 Internal Server Error
```bash
# 1. ログ確認
docker compose logs dify-api --tail=50

# 2. マイグレーション実行
docker compose exec dify-api flask db upgrade

# 3. データベース接続確認
docker compose exec dify-api python -c "import psycopg2; conn = psycopg2.connect('postgresql://dify:changeme@db:5432/dify'); print('OK')"

# 4. 環境変数確認
docker compose exec dify-api env | grep -E "(DATABASE|POSTGRES|REDIS)"
```

#### 問題: Embedding処理が進まない
```bash
# 1. Worker起動確認
docker compose ps dify-worker

# 2. Workerログ確認
docker compose logs dify-worker --tail=50

# 3. Celeryキュー確認
docker compose exec dify-api python -c "from celery import Celery; app = Celery(broker='redis://redis:6379/1'); print(app.control.inspect().active())"
```

#### 問題: プラグインエラー

**エラーメッセージ:**
```
Failed to request plugin daemon, url: plugin/[UUID]/management/models
Failed to request plugin daemon, url: plugin/[UUID]/management/install/tasks
```

**原因:**
1. Dify 0.12.x以降のプラグイン機能が有効化されている
2. `plugin-daemon`サービスが起動していない（docker-compose.ymlに存在しない）
3. データベースにプラグイン関連情報が残っている

**解決策1: バージョンダウングレード（推奨・最も簡単）**
```yaml
# docker-compose.yml を以下に変更
services:
  dify-web:
    image: docker.io/langgenius/dify-web:0.11.1  # latest → 0.11.1

  dify-api:
    image: docker.io/langgenius/dify-api:0.11.1  # latest → 0.11.1
    environment:
      - PLUGIN_ENABLED=false
      - DISABLE_PLUGIN_MANAGER=true
      # ... その他の環境変数

  dify-worker:
    image: docker.io/langgenius/dify-api:0.11.1  # latest → 0.11.1
    environment:
      - PLUGIN_ENABLED=false
      - DISABLE_PLUGIN_MANAGER=true
      # ... その他の環境変数
```

```bash
# コンテナ再作成
docker compose down
docker compose pull
docker compose up -d
```

**解決策2: データベースクリーンアップ（データ保持したい場合）**
```bash
# 1. バックアップ（必須）
docker compose exec db pg_dump -U dify dify > backup_$(date +%Y%m%d).sql

# 2. プラグイン関連テーブルをクリア
docker compose exec db psql -U dify -d dify << EOF
TRUNCATE TABLE account_plugin_permissions CASCADE;
TRUNCATE TABLE tenant_plugin_auto_upgrade_strategies CASCADE;
TRUNCATE TABLE pipeline_recommended_plugins CASCADE;
DELETE FROM installed_apps WHERE app_id LIKE '%plugin%';
EOF

# 3. コンテナ再起動
docker compose restart dify-api dify-worker
```

**解決策3: 完全リセット（データ削除OK）**
```bash
# すべて停止
docker compose down

# データベースボリューム削除
docker volume rm dify_vectordb_autoprograming_pg-data

# 再起動
docker compose up -d

# マイグレーション
docker compose exec dify-api flask db upgrade
```

**なぜ0.11.1を使うのか？**
- ✅ プラグイン機能がないため安定
- ✅ 基本機能は十分に使える
- ✅ エラーが発生しない
- ❌ 0.12.x以降: プラグイン機能追加、`plugin-daemon`サービスが必要、ドキュメント不足、不安定

## 8. チェックリスト（保存版）

### 初回セットアップ時
- [ ] バージョンを固定（0.11.1など、latest禁止）
- [ ] プラグイン無効化（`PLUGIN_ENABLED=false`）
- [ ] DB設定3種類すべて設定（`DATABASE_URL`, `SQLALCHEMY_DATABASE_URI`, 個別パラメータ）
- [ ] Redis設定を明示的に設定（`REDIS_HOST=redis`）
- [ ] ベクトルDB設定（`VECTOR_STORE=pgvector`）
- [ ] Worker command明示的に設定（entrypoint無効化）
- [ ] `.env`と`docker-compose.yml`のパスワード一致確認
- [ ] 初回マイグレーション実行（`flask db upgrade`）
- [ ] `.env`を`.gitignore`に追加
- [ ] 強力なパスワード設定（本番環境）

### トラブル発生時
- [ ] コンテナ状態確認（`docker compose ps`）
- [ ] ログ確認（`docker compose logs [service] --tail=50`）
- [ ] マイグレーション実行（`flask db upgrade`）
- [ ] データベース接続確認
- [ ] 環境変数確認（`docker compose exec dify-api env`）
- [ ] コンテナ再起動（`docker compose restart`）
- [ ] 完全リセット（最終手段: `docker compose down -v`）

## 9. 次のステップ（AWS で公開運用）

ローカルでの体験後は、AWS（ECS Fargate + RDS pgvector + ElastiCache + ALB + HTTPS）へ展開して公開運用が可能です。講座の後半で、以下を扱います。
- コンテナのECRミラー、タスク定義（api/web/worker）
- ALBでのホスト/パスルーティングとHTTPS（ACM）
- Secrets/SSM/KMS、NATレス運用（VPCエンドポイント）
- 監視・ログ（CloudWatch Logs）、トラブル対応（ターゲットヘルス/ルール）

詳細手順は `AWS_DEPLOY_BEDROCK.md` を参照（Bedrock Titan v2 Embeddings + Claude 2、NATレス運用）。

## 10. Cursor を使って「ぎゃるでれら」を作る

以下の指示書を Cursor に読み込ませて、短時間でキャラクターAIを作れます。
- `cursor/INSTRUCTIONS_GYARU_CINDERELLA.md`
- アップロード用サンプル: `samples/gyaru_cinderella_profile.md`

## 11. ライセンス

このテンプレート自体は MIT ライセンス（必要に応じて変更可）。Dify本体のライセンスは公式に従います。
