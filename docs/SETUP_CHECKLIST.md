# Difyローカル構築チェックポイント

**対象**: macOS/Linux/Windows  
**Difyバージョン**: 0.11.1  
**作成日**: 2025年11月2日

---

## 📋 構築手順チェックリスト

このチェックリストに従って、段階的にDifyを構築してください。各ステップで✅をつけながら進めることで、問題の早期発見が可能です。

---

## Phase 1: 事前準備

### ✅ チェックポイント1-1: 環境確認

- [ ] **Dockerインストール確認**
  ```bash
  docker --version
  # 期待: Docker version 24.0以上
  
  docker compose version
  # 期待: Docker Compose version v2.20以上
  ```

- [ ] **Docker起動確認**
  ```bash
  docker ps
  # エラーが出ないこと
  ```

- [ ] **Gitインストール確認**
  ```bash
  git --version
  # 期待: git version 2.x以上
  ```

- [ ] **ディスク容量確認**
  ```bash
  df -h .
  # 期待: 10GB以上の空き容量
  ```

- [ ] **メモリ確認（macOSの場合）**
  - Docker Desktop → Settings → Resources
  - Memory: 8GB以上を推奨
  - 最低でも4GB以上

**トラブル時**: `docs/MACOS_TROUBLESHOOTING.md`の「事前チェックリスト」を参照

---

### ✅ チェックポイント1-2: リポジトリクローン

- [ ] **クローン実行**
  ```bash
  git clone https://github.com/togashira/dify_vectordb_autoprograming.git
  cd dify_vectordb_autoprograming
  ```

- [ ] **ファイル確認**
  ```bash
  ls -la
  # 期待: docker-compose.yml, .env.example, README.md が存在
  ```

- [ ] **ブランチ確認**
  ```bash
  git branch
  # 期待: * main
  ```

---

### ✅ チェックポイント1-3: 環境変数設定

- [ ] **.envファイル作成**
  ```bash
  cp .env.example .env
  ```

- [ ] **.env内容確認**
  ```bash
  cat .env
  ```

- [ ] **必須項目の確認**
  ```bash
  # 以下の項目が設定されているか確認
  grep "POSTGRES_PASSWORD" .env
  grep "SECRET_KEY" .env
  
  # plugin-daemon無効の確認
  grep "PLUGIN_ENABLED=false" .env
  grep "DISABLE_PLUGIN_MANAGER=true" .env
  ```

**重要**: パスワードはそのままでOK（ローカル開発用）

---

## Phase 2: 初回起動

### ✅ チェックポイント2-1: Dockerイメージダウンロード

- [ ] **イメージプル開始**
  ```bash
  docker compose pull
  ```

- [ ] **ダウンロード完了確認**
  ```bash
  # 以下のイメージがダウンロードされること
  docker images | grep langgenius
  # langgenius/dify-web
  # langgenius/dify-api
  ```

**所要時間**: 5-10分（回線速度による）

---

### ✅ チェックポイント2-2: コンテナ起動

- [ ] **起動コマンド実行**
  ```bash
  docker compose up -d
  ```

- [ ] **起動ログ確認**
  ```bash
  docker compose logs -f --tail=50
  ```

- [ ] **エラーチェック**
  ```bash
  docker compose logs | grep -i error
  docker compose logs | grep -i fail
  
  # エラーがある場合は下記参照
  ```

**期待する出力**: 各サービスが`started`と表示される

**よくあるエラー**:
- `plugin-daemon` エラー → `docs/MACOS_TROUBLESHOOTING.md`の問題1参照
- `port already allocated` → 問題5参照
- `no matching manifest` (M1/M2 Mac) → 問題2参照

---

### ✅ チェックポイント2-3: コンテナ状態確認

- [ ] **全コンテナ起動確認**
  ```bash
  docker compose ps
  ```

- [ ] **期待する状態**
  ```
  NAME          STATE               HEALTH
  dify-api      running             healthy (または starting)
  dify-web      running             healthy (または starting)
  dify-worker   running             
  db            running             healthy
  redis         running             healthy
  nginx         running             
  ```

- [ ] **起動待機（初回は2-3分待つ）**
  ```bash
  # 30秒ごとに状態確認
  watch -n 30 'docker compose ps'
  ```

**注意**: `dify-web`が`starting`の場合、1-2分待ってください。

---

### ✅ チェックポイント2-4: データベースマイグレーション（重要）

- [ ] **マイグレーション実行**
  ```bash
  docker compose exec dify-api flask db upgrade
  ```

- [ ] **成功メッセージ確認**
  ```
  INFO  [alembic.runtime.migration] Running upgrade
  INFO  [alembic.runtime.migration] Context impl PostgresqlImpl.
  ```

- [ ] **エラーがある場合**
  ```bash
  # データベースが起動していない可能性
  docker compose logs db
  
  # 再起動
  docker compose restart db
  sleep 10
  docker compose exec dify-api flask db upgrade
  ```

**このステップを忘れると**: `/install`ページでエラーが発生します。

---

## Phase 3: 動作確認

### ✅ チェックポイント3-1: Webアクセス確認

- [ ] **ブラウザでアクセス**
  ```bash
  # macOS
  open http://localhost:8080
  
  # Linux
  xdg-open http://localhost:8080
  
  # または手動でブラウザに入力
  ```

- [ ] **ページ表示確認**
  - `/install`ページが表示される
  - または既にセットアップ済みの場合は`/apps`にリダイレクト

- [ ] **curlで確認（オプション）**
  ```bash
  curl -I http://localhost:8080
  # 期待: HTTP/1.1 200 OK
  ```

**エラーの場合**:
- `Connection refused` → nginxコンテナのログ確認
- `502 Bad Gateway` → dify-webのログ確認

---

### ✅ チェックポイント3-2: API動作確認

- [ ] **ヘルスチェックエンドポイント**
  ```bash
  curl http://localhost:8080/console/api/health
  # 期待: {"status":"ok"}
  ```

- [ ] **機能エンドポイント**
  ```bash
  curl http://localhost:8080/console/api/features
  # 期待: JSON応答（200 OK）
  ```

**エラーの場合**:
- `401 Unauthorized` → 正常（認証前）
- `500 Internal Server Error` → dify-apiログ確認
- `Connection refused` → nginxの設定確認

---

### ✅ チェックポイント3-3: 初期セットアップ

- [ ] **/installページアクセス**
  - URL: http://localhost:8080/install

- [ ] **管理者アカウント作成**
  - Email: （あなたのメールアドレス）
  - Name: （あなたの名前）
  - Password: （安全なパスワード）

- [ ] **セットアップ完了確認**
  - `/apps`ページにリダイレクトされる
  - "Create your first app"ボタンが表示される

---

### ✅ チェックポイント3-4: データセット作成テスト

- [ ] **ナレッジベース作成**
  1. 左メニュー「Knowledge」をクリック
  2. 「Create Knowledge」ボタン
  3. 名前: "Test Dataset"
  4. 「Create」

- [ ] **ドキュメントアップロード**
  1. 「Add Document」
  2. サンプルファイル選択（`samples/cinderella_story.md`を推奨）
  3. アップロード完了待機

- [ ] **インデックス作成確認**
  ```bash
  # ログでインデックス作成を確認
  docker compose logs dify-worker | grep -i "index"
  ```

---

## Phase 4: トラブルシューティング

### ✅ チェックポイント4-1: ログ確認

問題が発生した場合、まずログを確認:

- [ ] **全体ログ**
  ```bash
  docker compose logs -f --tail=100
  ```

- [ ] **サービス別ログ**
  ```bash
  # API
  docker compose logs -f dify-api --tail=50
  
  # Web
  docker compose logs -f dify-web --tail=50
  
  # Worker
  docker compose logs -f dify-worker --tail=50
  
  # DB
  docker compose logs -f db --tail=50
  ```

- [ ] **エラー抽出**
  ```bash
  docker compose logs | grep -i "error\|fail\|exception"
  ```

---

### ✅ チェックポイント4-2: リソース確認

- [ ] **メモリ使用量**
  ```bash
  docker stats
  # dify-api, dify-webが異常に高くないか確認
  ```

- [ ] **ディスク使用量**
  ```bash
  docker system df
  ```

- [ ] **ネットワーク確認**
  ```bash
  docker network ls
  docker network inspect dify_default
  ```

---

### ✅ チェックポイント4-3: 再起動手順

問題が解決しない場合:

- [ ] **ソフト再起動**
  ```bash
  docker compose restart
  ```

- [ ] **ハード再起動**
  ```bash
  docker compose down
  docker compose up -d
  ```

- [ ] **完全クリーン再起動**
  ```bash
  # データも削除（注意！）
  docker compose down -v
  docker compose up -d
  sleep 30
  docker compose exec dify-api flask db upgrade
  ```

---

## Phase 5: 本番運用準備

### ✅ チェックポイント5-1: セキュリティ設定

- [ ] **SECRET_KEY変更**
  ```bash
  # .envファイル
  SECRET_KEY=$(openssl rand -hex 32)
  echo "SECRET_KEY=$SECRET_KEY" >> .env
  ```

- [ ] **データベースパスワード変更**
  ```bash
  # .env
  POSTGRES_PASSWORD=your-secure-password-here
  ```

- [ ] **再起動して反映**
  ```bash
  docker compose down -v
  docker compose up -d
  ```

---

### ✅ チェックポイント5-2: バックアップ設定

- [ ] **データベースバックアップ**
  ```bash
  docker compose exec db pg_dump -U dify dify > backup_$(date +%Y%m%d).sql
  ```

- [ ] **ボリュームバックアップ**
  ```bash
  # docker volumeの場所確認
  docker volume inspect dify_db-data
  ```

---

### ✅ チェックポイント5-3: モニタリング設定

- [ ] **ログローテーション設定**
  ```bash
  # docker-compose.ymlに追加
  logging:
    driver: "json-file"
    options:
      max-size: "10m"
      max-file: "3"
  ```

- [ ] **定期ヘルスチェック**
  ```bash
  # cronで設定
  */5 * * * * curl -sf http://localhost:8080/console/api/health || echo "Dify is down" | mail -s "Alert" admin@example.com
  ```

---

## 📊 トラブルシューティングフローチャート

```
起動失敗？
  ├─ YES → docker compose logs でエラー確認
  │         ├─ plugin-daemon error → MACOS_TROUBLESHOOTING.md 問題1
  │         ├─ port allocated → MACOS_TROUBLESHOOTING.md 問題5
  │         ├─ DB connection error → MACOS_TROUBLESHOOTING.md 問題3
  │         └─ その他 → MACOS_TROUBLESHOOTING.md 参照
  │
  └─ NO → Webアクセス失敗？
           ├─ YES → curl http://localhost:8080 で確認
           │         ├─ Connection refused → nginxログ確認
           │         └─ 502 Bad Gateway → dify-webログ確認
           │
           └─ NO → /install ページエラー？
                    ├─ YES → マイグレーション実行済み？
                    │         ├─ NO → docker compose exec dify-api flask db upgrade
                    │         └─ YES → DBログ確認
                    │
                    └─ NO → 正常稼働中！
```

---

## 🎯 完了確認チェックリスト

全て✅になったら構築完了です！

- [ ] 全コンテナが`running (healthy)`状態
- [ ] http://localhost:8080 でDifyにアクセス可能
- [ ] 管理者アカウントでログイン可能
- [ ] ナレッジベース作成・ドキュメントアップロード成功
- [ ] アプリケーション作成可能
- [ ] チャット機能が動作

---

## 📚 関連ドキュメント

- **トラブルシューティング**: `docs/MACOS_TROUBLESHOOTING.md`
- **基本手順**: `README.md`
- **詳細ガイド**: `docs/RECORDING_SCRIPT_01.md`
- **サンプルデータ**: `samples/`

---

## 🆘 サポート

問題が解決しない場合:

1. **ログ収集**
   ```bash
   docker compose logs > dify_logs_$(date +%Y%m%d_%H%M%S).txt
   ```

2. **環境情報収集**
   ```bash
   docker --version > env_info.txt
   docker compose version >> env_info.txt
   uname -a >> env_info.txt
   docker compose ps >> env_info.txt
   ```

3. **GitHubにIssue作成**
   - https://github.com/togashira/dify_vectordb_autoprograming/issues
   - ログファイルと環境情報を添付

---

**最終更新**: 2025年11月2日  
**バージョン**: 1.0  
**テスト環境**: macOS, Ubuntu 22.04, Windows 11 + WSL2
