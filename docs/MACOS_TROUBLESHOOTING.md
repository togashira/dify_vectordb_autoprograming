# macOS環境でのDify 1.9.1ローカル構築トラブルシューティング

**対象環境**: macOS（M1/M2/Intel）  
**Difyバージョン**: 0.11.1（本リポジトリ）/ 1.9.1（旧バージョン参考）  
**作成日**: 2025年11月2日

---

## 🎯 このガイドについて

macOS（特にApple Silicon M1/M2）でDifyをローカル構築する際に遭遇しやすい**plugin-daemon関連のエラー**と、その他の典型的な問題の解決方法をまとめています。

---

## 📋 事前チェックリスト

構築を始める前に、以下を確認してください。

### 必須環境
- [ ] **Docker Desktop for Mac**: 最新版（4.25以上推奨）
- [ ] **Git**: インストール済み
- [ ] **ディスク空き容量**: 最低10GB以上
- [ ] **メモリ**: 8GB以上（16GB推奨）
- [ ] **Docker Desktopの設定**:
  - Resources → Memory: 最低4GB（8GB推奨）
  - Resources → Disk: 60GB以上

### 確認コマンド
```bash
# Dockerバージョン確認
docker --version
docker compose version

# Dockerが起動しているか確認
docker ps

# 利用可能なメモリ確認
docker info | grep "Total Memory"
```

---

## 🚨 よくある問題と解決策

### 問題1: plugin-daemon起動エラー（最頻出）

#### 症状
```bash
docker compose up -d
# または
docker compose logs dify-api

# エラーメッセージ例:
# Error: Failed to connect to plugin daemon
# Connection refused: localhost:5003
# plugin-daemon: no such container
```

#### 原因
- Dify 0.11.1では**plugin-daemon機能がデフォルト無効**
- docker-compose.ymlにplugin-daemonサービスが含まれていない
- 環境変数で有効化しようとするとエラーになる

#### 解決策A: plugin-daemon無効で起動（推奨）

本リポジトリの`docker-compose.yml`は既に対応済みです。

```bash
# .envファイルを確認
cat .env.example

# 以下の設定を確認（または追加）
PLUGIN_ENABLED=false
DISABLE_PLUGIN_MANAGER=true
```

```bash
# 起動
docker compose up -d

# ログ確認（エラーがないか）
docker compose logs -f --tail=100
```

#### 解決策B: plugin-daemon機能を有効化（上級者向け）

plugin機能が必要な場合（通常は不要）:

1. **docker-compose.ymlにplugin-daemonサービスを追加**

```yaml
# docker-compose.ymlに追加
  dify-plugin-daemon:
    image: langgenius/dify-plugin-daemon:0.11.1
    restart: always
    environment:
      - PLUGIN_DAEMON_KEY=${PLUGIN_DAEMON_KEY:-your-secret-key-here}
    ports:
      - "5003:5003"
    volumes:
      - plugin-data:/app/plugins
    networks:
      - dify-network

volumes:
  plugin-data:
```

2. **.envに環境変数を追加**

```bash
# .env
PLUGIN_ENABLED=true
DISABLE_PLUGIN_MANAGER=false
PLUGIN_DAEMON_KEY=your-secret-key-here
PLUGIN_DAEMON_HOST=dify-plugin-daemon
PLUGIN_DAEMON_PORT=5003
```

3. **再起動**

```bash
docker compose down
docker compose up -d
```

---

### 問題2: M1/M2 Macでのアーキテクチャエラー

#### 症状
```bash
docker compose up -d

# エラー:
# no matching manifest for linux/arm64/v8
# The requested image's platform (linux/amd64) does not match
```

#### 原因
- Apple Silicon（M1/M2）はARM64アーキテクチャ
- 一部のDockerイメージがARM64に対応していない

#### 解決策A: Rosetta 2エミュレーション（推奨）

Docker Desktop設定で有効化:

1. Docker Desktop を開く
2. **Settings** → **Features in development**
3. **Use Rosetta for x86/amd64 emulation on Apple Silicon** を✅有効化
4. Docker Desktopを再起動

```bash
# 再度起動
docker compose up -d
```

#### 解決策B: プラットフォーム指定

```bash
# docker-compose.ymlの各サービスに追加
services:
  dify-web:
    platform: linux/amd64  # 追加
    image: langgenius/dify-web:0.11.1
    # ...
```

---

### 問題3: データベース接続エラー

#### 症状
```bash
docker compose logs dify-api

# エラー:
# sqlalchemy.exc.OperationalError: could not connect to server
# FATAL: password authentication failed for user "dify"
```

#### 原因
- `.env`と`docker-compose.yml`のパスワード不一致
- PostgreSQLコンテナの初期化失敗

#### 解決策

1. **パスワードを統一**

```bash
# .envファイル
POSTGRES_USER=dify
POSTGRES_PASSWORD=changeme
POSTGRES_DB=dify
```

```yaml
# docker-compose.ymlで確認
environment:
  - POSTGRES_USER=${POSTGRES_USER:-dify}
  - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-changeme}
  - POSTGRES_DB=${POSTGRES_DB:-dify}
```

2. **データベース完全リセット**

```bash
# 全コンテナとボリューム削除
docker compose down -v

# 再起動
docker compose up -d

# ログ確認
docker compose logs db -f
```

---

### 問題4: マイグレーションエラー

#### 症状
```bash
docker compose logs dify-api

# エラー:
# alembic.util.exc.CommandError: Target database is not up to date
# sqlalchemy.exc.ProgrammingError: relation "xxx" does not exist
```

#### 原因
- データベーステーブルが作成されていない
- マイグレーションが実行されていない

#### 解決策

```bash
# マイグレーション実行（初回起動後必須）
docker compose exec dify-api flask db upgrade

# 成功メッセージ例:
# INFO  [alembic.runtime.migration] Running upgrade -> xxx
# INFO  [alembic.runtime.migration] Running upgrade xxx -> yyy
```

**重要**: 初回起動後、`/install`ページにアクセスする前に必ず実行してください。

---

### 問題5: ポート競合

#### 症状
```bash
docker compose up -d

# エラー:
# Error: Bind for 0.0.0.0:8080 failed: port is already allocated
```

#### 原因
- 既に8080ポートを使用しているアプリケーションがある
- 他のDockerコンテナが8080を使用中

#### 解決策A: 使用中のポートを確認

```bash
# macOSでポート使用状況確認
lsof -i :8080

# 実行中のプロセスを確認
# COMMAND   PID   USER   FD   TYPE
# nginx     1234  user   6u   IPv4

# プロセスを停止
kill -9 1234
```

#### 解決策B: ポート番号変更

```bash
# .envファイル
HOST_PORT=8081  # 8080から変更

# または docker-compose.yml で直接変更
ports:
  - "8081:80"  # 8080から8081に変更
```

```bash
# 再起動
docker compose down
docker compose up -d

# アクセス
open http://localhost:8081
```

---

### 問題6: Redis接続エラー

#### 症状
```bash
docker compose logs dify-api

# エラー:
# redis.exceptions.ConnectionError: Error connecting to Redis
# Connection refused
```

#### 原因
- Redisコンテナが起動していない
- ネットワーク設定の問題

#### 解決策

```bash
# Redisコンテナ状態確認
docker compose ps redis

# Redisログ確認
docker compose logs redis

# Redisが起動していない場合、再起動
docker compose restart redis

# それでもダメなら完全再起動
docker compose down
docker compose up -d
```

---

### 問題7: ヘルスチェック失敗（dify-web）

#### 症状
```bash
docker compose ps

# STATE列:
# dify-web   starting (health: starting)
# または
# dify-web   unhealthy
```

#### 原因
- dify-webコンテナの起動に時間がかかっている
- メモリ不足
- ヘルスチェック設定が厳しすぎる

#### 解決策A: 待機時間を延長

通常、1-2分待つと`healthy`になります。

```bash
# 状態を継続監視
watch -n 5 'docker compose ps'

# ログ確認
docker compose logs -f dify-web
```

#### 解決策B: Docker Desktopのメモリ増量

1. Docker Desktop → **Settings** → **Resources**
2. **Memory**: 8GB以上に増やす
3. **Apply & Restart**

---

## ✅ 正常起動の確認手順

### ステップ1: 全コンテナが起動しているか確認

```bash
docker compose ps

# 期待する出力（全て State: running, health: healthy）:
# NAME                STATE               PORTS
# dify-api            running (healthy)   5001/tcp
# dify-web            running (healthy)   3000/tcp
# dify-worker         running             
# db                  running (healthy)   5432/tcp
# redis               running (healthy)   6379/tcp
# nginx               running             0.0.0.0:8080->80/tcp
```

### ステップ2: Webアクセス確認

```bash
# ブラウザで開く
open http://localhost:8080

# または curl で確認
curl -I http://localhost:8080
# HTTP/1.1 200 OK
```

### ステップ3: API動作確認

```bash
# ヘルスチェック
curl http://localhost:8080/console/api/health

# 期待する出力:
# {"status":"ok"}
```

### ステップ4: 初期セットアップ

1. **http://localhost:8080/install** にアクセス
2. **管理者アカウント作成**:
   - Email: your-email@example.com
   - Name: Admin User
   - Password: 安全なパスワード
3. セットアップ完了後、http://localhost:8080/apps にリダイレクト

---

## 🛠️ デバッグコマンド集

### コンテナ状態確認
```bash
# 全コンテナの状態
docker compose ps

# 詳細情報
docker compose ps --all
docker stats
```

### ログ確認
```bash
# 全サービスのログ（リアルタイム）
docker compose logs -f --tail=100

# 特定サービスのログ
docker compose logs -f dify-api
docker compose logs -f dify-web
docker compose logs -f db

# エラーのみ表示
docker compose logs | grep -i error
docker compose logs | grep -i fail
```

### コンテナ内部調査
```bash
# dify-apiコンテナに入る
docker compose exec dify-api bash

# データベースに接続
docker compose exec db psql -U dify -d dify

# Redisに接続
docker compose exec redis redis-cli
> PING
# PONG
```

### ネットワーク確認
```bash
# Dockerネットワーク一覧
docker network ls

# 詳細情報
docker network inspect dify_default
```

### リソース使用状況
```bash
# メモリ・CPU使用率
docker stats

# ディスク使用量
docker system df

# 不要なデータ削除（注意）
docker system prune -a --volumes
```

---

## 🔄 完全リセット手順

全てのトラブルが解決しない場合、クリーンな状態から再構築:

```bash
# ステップ1: 全コンテナ停止・削除
docker compose down -v

# ステップ2: Dockerイメージ削除（オプション）
docker rmi $(docker images 'langgenius/dify-*' -q)

# ステップ3: Docker Desktopを再起動
# GUI: Docker Desktop → Troubleshoot → Restart Docker Desktop

# ステップ4: リポジトリを再クローン（オプション）
cd ~/
mv dify_vectordb_autoprograming dify_vectordb_autoprograming.backup
git clone https://github.com/togashira/dify_vectordb_autoprograming.git
cd dify_vectordb_autoprograming

# ステップ5: .envファイル設定
cp .env.example .env
# 必要に応じて編集

# ステップ6: 起動
docker compose up -d

# ステップ7: マイグレーション
sleep 30  # データベース起動待機
docker compose exec dify-api flask db upgrade

# ステップ8: 確認
docker compose ps
open http://localhost:8080/install
```

---

## 📚 参考情報

### 公式ドキュメント
- Dify公式: https://docs.dify.ai/
- Docker Desktop for Mac: https://docs.docker.com/desktop/mac/

### このリポジトリの関連ドキュメント
- `README.md` - 基本的な起動手順
- `docs/RECORDING_SCRIPT_01.md` - 詳細な構築手順
- `.env.example` - 環境変数の説明

### よくある質問

**Q: M1 MacでRosetta 2を有効化すべき？**  
A: はい。Difyの一部イメージがAMD64専用のため、Rosetta 2エミュレーションを有効化することを強く推奨します。

**Q: plugin-daemon機能は必要？**  
A: ほとんどの場合不要です。基本的なRAG機能にはplugin-daemonは必要ありません。

**Q: メモリ不足でクラッシュする**  
A: Docker Desktopのメモリを8GB以上に設定してください。特にM1/M2 Macではエミュレーションによりメモリ使用量が増加します。

**Q: 起動に時間がかかる**  
A: 初回起動時は5-10分かかることがあります。`docker compose logs -f`でログを監視してください。

---

## 🚨 緊急時の連絡先

### コミュニティサポート
- Dify Discord: https://discord.gg/FngNHpbcY7
- GitHub Issues: https://github.com/langgenius/dify/issues

### このリポジトリのIssues
- https://github.com/togashira/dify_vectordb_autoprograming/issues

---

**最終更新**: 2025年11月2日  
**テスト環境**: macOS Sonoma 14.x, Docker Desktop 4.25+  
**動作確認**: M1 Mac, M2 Mac, Intel Mac
