# DevServer MCP v3.0

開発サーバー（Next.js、Convex等）をClaude Codeから管理するためのMCPサーバーです。

## 🚀 主な機能

### 基本機能
- **設定ファイルベース管理**: `.devserver.json`で一括管理
- **ワンコマンド起動/停止**: `up`/`down`で全サービスを制御
- **自動ポート割り当て**: ポート競合時に自動で別ポートを使用
- **自動再起動**: プロセスが異常終了した場合に自動再起動
- **ログフィルタリング**: 正規表現でログを絞り込み
- **カレントディレクトリ自動検出**: `cwd`省略時は現在のディレクトリを使用

### v3.0 新機能
- **グループ操作**: プロジェクト単位での一括起動/停止 (`groupStart`/`groupStop`)
- **エイリアス**: 短い名前でサービスにアクセス
- **ヘルスチェック**: サービスの健全性を定期的に監視
- **セキュリティ**: コマンドホワイトリスト、認証機能
- **ログ永続化**: JSON Lines形式でログを保存
- **Convex対応**: cloudPort/sitePortの自動割り当て
- **ANSIカラー対応**: ログのカラー表示サポート

## 📦 インストール

### ワンライナーインストール（推奨）

```bash
# GitHubから直接インストール（実装予定）
curl -sSL https://raw.githubusercontent.com/yourusername/devserver-mcp/main/install.sh | bash

# または、ローカルからインストール
bash /Users/soichiro/Work/devserver-mcp/install.sh
```

ワンライナーインストールでは以下が自動的に行われます：
- DevServer MCPのグローバルインストール（`~/.devserver-mcp/`）
- 依存関係のインストール
- Claude MCPへの登録（オプション）
- **Claude Commandsのインストール**（オプション）
- systemd/LaunchAgentの設定（オプション）
- サンプル設定ファイルの作成

### 手動インストール

```bash
# 1. クローン
git clone https://github.com/yourusername/devserver-mcp.git
cd devserver-mcp

# 2. 依存関係インストール
npm install

# 3. Claude MCPに登録
claude mcp add devserver "node $(pwd)/server.mjs" -s user
```

## クイックスタート

### 1. 設定ファイルを作成

プロジェクトのルートに `.devserver.json` を作成：

```json
{
  "services": [
    {
      "label": "next",
      "command": "pnpm dev",
      "port": 3000
    },
    {
      "label": "convex",
      "command": "npx convex dev",
      "cloudPort": 3210,
      "sitePort": 6810
    },
    {
      "label": "api",
      "command": "npm run dev",
      "port": 8080,
      "healthEndpoint": "/health"
    }
  ],
  "aliases": {
    "web": "next",
    "backend": "convex",
    "server": "api"
  }
}
```

### 2. 一括起動・停止

```json
# すべてのサービスを起動
/mcp__devserver__up {}

# すべてのサービスを停止
/mcp__devserver__down {}

# 特定のディレクトリで起動
/mcp__devserver__up {"cwd":"/Users/soichiro/Work/ai-zaiko"}
```

### 3. ログ確認

```json
# 基本的なログ表示
/mcp__devserver__logs {"label":"next"}
# 注意: エイリアスは現在サポートされていません

# エラーのみ表示（正規表現フィルタ）
/mcp__devserver__logs {"label":"next","grep":"ERROR|WARN"}

# 最新100行を表示
/mcp__devserver__logs {"label":"convex","lines":100}

# ANSIカラーを保持して表示
/mcp__devserver__logs {"label":"next","color":true}
```

## 詳細な使い方

### 個別のサーバー管理

```json
# 起動（cwdは省略可能、現在のディレクトリを使用）
/mcp__devserver__start {"label":"next"}
/mcp__devserver__start {"command":"npm run dev","label":"backend"}

# 停止
/mcp__devserver__stop {"label":"next"}
# 注意: エイリアスは現在サポートされていません

# 再起動（設定を保持）
/mcp__devserver__restart {"label":"next"}

# 状態確認
/mcp__devserver__status {}
/mcp__devserver__status {"project":"ai-zaiko"}  # プロジェクトでフィルタ
```

### グループ操作（v3.0新機能）

```json
# プロジェクト単位で一括起動
/mcp__devserver__groupStart {"project":"ai-zaiko"}

# プロジェクト単位で一括停止
/mcp__devserver__groupStop {"project":"ai-zaiko"}
```

## パラメータ

### start / restart
- `cwd` (オプション): 作業ディレクトリのパス（省略時は現在のディレクトリ）
- `command` (オプション): 実行コマンド（デフォルト: "pnpm dev"）
- `label` (必須): プロセスの識別ラベル
- `auth` (オプション): 認証トークン（AUTH有効時）

### stop
- `label` (必須): 停止するプロセスのラベルまたはエイリアス
- `auth` (オプション): 認証トークン（AUTH有効時）

### logs
- `label` (必須): ログを取得するプロセスのラベルまたはエイリアス
- `lines` (オプション): 取得する行数（デフォルト: 200）
- `grep` (オプション): フィルタパターン（正規表現）
- `color` (オプション): ANSIカラーを保持（デフォルト: false）
- `stream` (オプション): ストリーミングモード（未実装）

### status
- `project` (オプション): プロジェクト名でフィルタ

### up / down
- `cwd` (オプション): 作業ディレクトリのパス（省略時は現在のディレクトリ）
- `auth` (オプション): 認証トークン（AUTH有効時）

### groupStart / groupStop
- `project` (必須): プロジェクト名
- `auth` (オプション): 認証トークン

## 高度な機能

### 自動ポート割り当て

`.devserver.json`で`port`を指定すると、使用中の場合は自動的に別のポートを割り当てます：

```json
{
  "services": [
    {
      "label": "next",
      "command": "pnpm dev",
      "port": 3000  // 3000が使用中なら3001, 3002...を試行
    },
    {
      "label": "convex",
      "command": "npx convex dev",
      "cloudPort": 3210,  // Convex Cloud APIポート
      "sitePort": 6810    // Convex Site ポート
    }
  ]
}
```

Convexの場合、`cloudPort`と`sitePort`を指定すると、自動的にコマンドラインオプションが追加されます。

### 自動再起動

プロセスが異常終了した場合、3秒後に自動的に再起動します。手動停止やSIGTERM/SIGKILLによる終了時は再起動しません。

### ログフィルタリング

正規表現を使ってログを絞り込めます：

```json
# エラーと警告のみ
/mcp__devserver__logs {"label":"next","grep":"ERROR|WARN"}

# 特定のモジュール名を含むログ
/mcp__devserver__logs {"label":"convex","grep":"convex-server"}

# 大文字小文字を無視してマッチ
/mcp__devserver__logs {"label":"next","grep":"error"}
```

### エイリアス（v3.0新機能）

**重要な注意**: エイリアス機能は現在、DevServer MCP内部でのみ使用されており、MCPツール自体では認識されません。将来的な機能として`.devserver.json`に定義は可能ですが、実際の操作では必ずサービスの実際のラベル名（"next"、"convex"など）を使用してください。

```json
{
  "services": [...],
  "aliases": {
    "web": "next",      // 将来的な機能：現在は使用不可
    "backend": "convex", // 将来的な機能：現在は使用不可
    "api": "server"     // 将来的な機能：現在は使用不可
  }
}
```

**現在の正しい使い方**:
```json
// ✅ 正しい（実際のラベル名を使用）
/mcp__devserver__stop {"label":"next"}
/mcp__devserver__logs {"label":"convex"}

// ❌ 間違い（エイリアスは認識されない）
/mcp__devserver__stop {"label":"web"}
/mcp__devserver__logs {"label":"backend"}
```

### ヘルスチェック（v3.0新機能）

サービスの健全性を定期的（5秒間隔）に監視します：

```json
{
  "services": [
    {
      "label": "api",
      "command": "npm run dev",
      "port": 8080,
      "healthEndpoint": "/health"  // このエンドポイントをチェック
    }
  ]
}
```

### セキュリティ（v3.0新機能）

#### コマンドホワイトリスト
以下のパターンに一致するコマンドのみ実行可能：
- `pnpm dev|start|serve`
- `npm run <script>`
- `npx convex dev`
- `yarn dev|start|serve`
- `node <file>`
- `deno <file>`
- `bun <file>`

#### 認証機能
環境変数で認証を有効化できます：

```bash
export DEVSERVER_AUTH=true
export DEVSERVER_TOKEN=your-secret-token
```

認証が有効な場合、すべてのコマンドに`auth`パラメータが必要：

```json
/mcp__devserver__start {"label":"next","auth":"your-secret-token"}
```

## .devserver.json の詳細

```json
{
  "services": [
    {
      "label": "next",              // 必須: サービスの識別名
      "command": "pnpm dev",        // 必須: 実行コマンド
      "port": 3000                  // オプション: 自動ポート割り当て用
    },
    {
      "label": "convex",
      "command": "npx convex dev",
      "cloudPort": 3210,            // Convex Cloud APIポート
      "sitePort": 6810              // Convex Site ポート
    },
    {
      "label": "api",
      "command": "npm run dev",
      "port": 8080,
      "healthEndpoint": "/health"   // ヘルスチェックエンドポイント
    }
  ],
  "aliases": {                      // v3.0: エイリアス定義
    "web": "next",
    "backend": "convex",
    "server": "api"
  }
}
```

### ログの永続化（v3.0新機能）

すべてのログは自動的に以下の場所に保存されます：
- 保存先: `~/.devserver-mcp/logs/`
- 形式: JSON Lines (`.jsonl`)
- ファイル名: `{label}-{日付}.jsonl`

## 動作環境

### Node.jsバージョン要件
- **最小要件**: Node.js v18以上
- **推奨**: Node.js v20 LTS または v22 LTS
- **注意**: Node.js v24以降では互換性の問題が発生する可能性があります

### バージョン管理ツール対応
- n
- nvm
- volta
- fnm

Node.jsバージョンを切り替えた場合は、必ず`update-mcp-registration.sh`を実行してClaude MCP登録を更新してください。

## 注意事項

- コマンドホワイトリストにより、許可されたパターンのコマンドのみ実行可能です
- 長時間実行されるプロセスのログは最大10,000行までバッファされます
- 自動再起動は異常終了時のみ動作し、手動停止時は再起動しません
- ポート自動割り当ては、指定ポートから+10までの範囲で空きポートを探します
- グループ操作では、プロセスは`{プロジェクト名}:{ラベル}`の形式で管理されます
- ログはJSON Lines形式で永続化され、後から検索・分析可能です

## ai-zaiko プロジェクトでの使用例

### 設定ファイルベースの使用（推奨）

```json
# .devserver.json が設定済みの場合
/mcp__devserver__up {"cwd":"/Users/soichiro/Work/ai-zaiko"}    # 全サービス起動
/mcp__devserver__down {"cwd":"/Users/soichiro/Work/ai-zaiko"}  # 全サービス停止

# グループ操作
/mcp__devserver__groupStart {"project":"ai-zaiko"}  # どこからでも起動可能
/mcp__devserver__groupStop {"project":"ai-zaiko"}   # どこからでも停止可能
```

### 個別操作の例

```json
# 実際のラベル名を使った操作
/mcp__devserver__logs {"label":"next"}      # next のログを表示
/mcp__devserver__stop {"label":"convex"}    # convex を停止
/mcp__devserver__restart {"label":"next"}   # next を再起動

# カラー付きログ表示
/mcp__devserver__logs {"label":"next","color":true}

# エラーのみフィルタ
/mcp__devserver__logs {"label":"convex","grep":"ERROR|error"}

# ai-zaikoプロジェクトの状態確認
/mcp__devserver__status {"project":"ai-zaiko"}
```

### 手動起動の例（.devserver.jsonなしの場合）

```json
# Next.jsサーバーを起動
/mcp__devserver__start {"cwd":"/Users/soichiro/Work/ai-zaiko","label":"next"}

# Convexサーバーを起動（ポート自動割り当て）
/mcp__devserver__start {"cwd":"/Users/soichiro/Work/ai-zaiko","command":"npx convex dev","label":"convex"}

# 認証付きで起動（AUTH有効時）
/mcp__devserver__start {"label":"next","auth":"your-secret-token"}
```

## 重複起動防止の設定

### 問題
package.jsonで`npm-run-all`を使って複数サービスを一括起動する設定がある場合、DevServer MCPでサービスが重複起動される可能性があります。

例:
```json
// package.json
{
  "scripts": {
    "dev": "npm-run-all --parallel dev:backend dev:frontend",
    "dev:backend": "convex dev",
    "dev:frontend": "next dev -p 3000"
  }
}
```

### 解決策
個別起動用のスクリプトを追加して、DevServer MCPではそれらを使用します:

```json
// package.json
{
  "scripts": {
    "dev": "npm-run-all --parallel dev:backend dev:frontend",  // 従来の一括起動
    "dev:backend": "convex dev",
    "dev:frontend": "next dev -p 3000",
    "dev:next": "next dev -p 3000",      // DevServer MCP用（個別起動）
    "dev:convex": "convex dev"           // DevServer MCP用（個別起動）
  }
}
```

```json
// .devserver.json
{
  "services": [
    {
      "label": "next",
      "command": "pnpm dev:next",    // 個別起動コマンドを使用
      "port": 3000
    },
    {
      "label": "convex",
      "command": "pnpm dev:convex",  // 個別起動コマンドを使用
      "port": 3210
    }
  ],
  "aliases": {
    "web": "next",
    "backend": "convex"
  }
}
```

これにより:
- DevServer MCPで起動時は各サービスが独立して起動
- 従来の`pnpm dev`での一括起動も維持
- 重複起動やポート競合を防止

## トラブルシューティング

### Claude Code で "Status: ✗ failed" エラーが出る場合

#### 1. 互換性チェックの実行
```bash
./check-compatibility.sh
```

このスクリプトで以下を確認できます：
- Node.jsバージョンと互換性
- Claude MCP登録状態
- DevServer MCPインストール状態
- Node.jsバージョン管理ツールの検出

#### 2. よくある原因と解決方法

**Node.jsパスの問題**
- 複数のNode.jsバージョンがインストールされている場合、Claude Codeから見えるパスが異なることがあります
- 解決: `./update-mcp-registration.sh`を実行してパスを更新

**Node.jsバージョンの問題**
- Node.js v24以降では互換性問題が発生する可能性があります
- 解決: Node.js v20 LTSまたはv22 LTSに切り替え

**MCP登録の問題**
- 古いパスで登録されている可能性があります
- 解決: 
  ```bash
  claude mcp remove devserver
  ./update-mcp-registration.sh
  ```

#### 3. 手動でのテスト
```bash
# DevServer MCPが単体で動作するか確認
node ~/.devserver-mcp/server.mjs --stdio

# 初期化メッセージを送信してテスト
echo '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"1.0.0","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}},"id":1}' | node ~/.devserver-mcp/server.mjs --stdio
```

#### 4. ログの確認
```bash
# Claude MCPの詳細ログ
claude mcp list --verbose

# DevServer MCPのログ
tail -f ~/.devserver-mcp/logs/stderr.log
```

### FAQ

**Q: Node.jsバージョンを切り替えたらDevServer MCPが動かなくなった**
A: `./update-mcp-registration.sh`を実行して、新しいNode.jsパスでMCP登録を更新してください。

**Q: 「新しいClaude Codeセッションを開始してください」と表示される**
A: MCPの設定変更は現在のセッションには反映されません。`exit`でセッションを終了し、`claude`で新しいセッションを開始してください。

**Q: ポート6300が使用中と表示される**
A: `lsof -i :6300`で使用中のプロセスを確認し、必要に応じて停止してください。

## 確認手順

1. 新しいターミナルを開いて確認：
   ```bash
   claude mcp list
   # devserver: ✓ Connected と表示されることを確認
   ```

2. Claude Codeで動作確認：
   ```json
   /mcp__devserver__status {}
   # 空の配列または「現在起動中のプロセスはありません」が返れば正常
   ```

3. 実際にサーバーを起動してテスト：
   ```json
   /mcp__devserver__start {"cwd":"/Users/soichiro/Work/ai-zaiko","label":"test"}
   # ✅ test を起動しました と表示されれば成功
   ```

## トラブルシューティング

### Node.js互換性問題

#### 症状：「❌ Connection failed」エラー
```bash
claude mcp list
# devserver: /path/to/old/node /Users/username/.devserver-mcp/server.mjs - ❌ Connection failed
```

#### 原因
Node.jsバージョン管理ツール（n、nvm、volta等）でバージョンを切り替えた後、古いパスで登録されている

#### 解決策
```bash
# 1. 現在のNode.jsパスを確認
which node

# 2. Claude MCP登録を更新
claude mcp remove devserver
claude mcp add devserver "$(which node) ~/.devserver-mcp/server.mjs" -s user

# 3. 接続確認
claude mcp list
```

### Node.jsバージョン要件

#### サポートされるバージョン
- **最小要件**: Node.js v18.0.0以上
- **推奨**: Node.js v20.0.0以上
- **最新対応**: Node.js v24.x

#### バージョン確認
```bash
node -v  # v18.0.0以上であることを確認
```

#### アップグレード方法

**n（Node.js）使用時：**
```bash
sudo n latest
# または特定バージョン
sudo n 20
```

**nvm使用時：**
```bash
nvm install 20
nvm use 20
nvm alias default 20
```

**volta使用時：**
```bash
volta install node@20
```

### インストール失敗時の対処

#### 権限エラー
```bash
# macOSでLaunchAgent作成失敗時
chmod 755 ~/Library/LaunchAgents/
sudo chown $(whoami) ~/Library/LaunchAgents/

# Linuxでsystemd作成失敗時
mkdir -p ~/.config/systemd/user
systemctl --user daemon-reload
```

#### 依存関係インストール失敗
```bash
# npm cacheをクリア
npm cache clean --force

# 手動で依存関係をインストール
cd ~/.devserver-mcp
npm install @modelcontextprotocol/sdk@latest strip-ansi@^7.1.0
```

#### パス関連エラー
```bash
# シェル設定を再読み込み
source ~/.bashrc  # または ~/.zshrc

# PATH環境変数を確認
echo $PATH | grep node
```

### Claude MCPとの接続問題

#### デバッグログの確認
```bash
# MCPサーバーを直接実行してエラーを確認
cd ~/.devserver-mcp
node server.mjs
# Ctrl+Cで終了

# ログファイルを確認
cat ~/.devserver-mcp/logs/stderr.log
```

#### ポート競合の確認
```bash
# ポート使用状況を確認
lsof -i :3000  # 開発サーバーのポート
netstat -an | grep LISTEN
```

#### 手動再インストール
```bash
# 完全に削除してからインストール
rm -rf ~/.devserver-mcp
claude mcp remove devserver

# 再インストール
bash /path/to/install.sh
```

### 設定ファイル関連の問題

#### .devserver.jsonの検証
```bash
# JSONの構文チェック
cat .devserver.json | python -m json.tool
# またはNode.jsで
node -e "console.log(JSON.parse(require('fs').readFileSync('.devserver.json', 'utf8')))"
```

#### サンプル設定のコピー
```bash
# サンプル設定をコピー
cp ~/.devserver.json.example .devserver.json
```

### パフォーマンス問題

#### メモリ使用量の確認
```bash
# プロセス確認
ps aux | grep devserver

# メモリ使用量確認
top -p $(pgrep -f devserver)
```

#### ログサイズの管理
```bash
# ログディレクトリサイズ確認
du -sh ~/.devserver-mcp/logs/

# 古いログを削除
find ~/.devserver-mcp/logs/ -name "*.jsonl" -mtime +7 -delete
```

### よくある質問（FAQ）

#### Q: Node.jsバージョンを切り替えたら接続できなくなった
A: Claude MCP登録のパスが古いNode.jsを指しています。上記の「Node.js互換性問題」を参照して登録を更新してください。

#### Q: エラーメッセージに「permission denied」が表示される
A: インストールディレクトリまたは実行ファイルの権限を確認してください：
```bash
chmod +x ~/.devserver-mcp/server.mjs
chmod 755 ~/.devserver-mcp
```

#### Q: プロセスが自動再起動しない
A: セキュリティ機能により、許可されていないコマンドは実行されません。`package.json`のスクリプトまたは許可されたパターンを使用してください。

#### Q: Windows環境での動作について
A: 現在Windows環境は未サポートです。WSL（Windows Subsystem for Linux）での使用を推奨します。

## プロジェクト命名規則

グループ操作を使用する場合、プロセスは以下の形式で管理されます：

- **形式**: `{プロジェクト名}:{サービスラベル}`
- **例**: `ai-zaiko:next`, `ai-zaiko:convex`

プロジェクト名は作業ディレクトリ名から自動的に取得されます。

## 更新履歴

### v3.0.2 (2025-01)
- 📝 エイリアス機能の制限事項を明記（MCPツールでは使用不可）
- 📝 実際のラベル名を使用するよう例を修正

### v3.0.1 (2024-01)
- 📝 重複起動防止の設定方法をドキュメントに追加
- 📝 package.jsonとの連携に関する注意事項を明記

### v3.0.0 (2024-01)
- ✨ グループ操作機能を追加（`groupStart`/`groupStop`）
- ✨ エイリアス機能を追加（内部使用のみ）
- ✨ ヘルスチェック機能を実装
- ✨ セキュリティ機能を強化（コマンドホワイトリスト、認証）
- ✨ ログの永続化（JSON Lines形式）
- ✨ Convexのポート設定に対応（cloudPort/sitePort）
- ✨ ANSIカラー対応
- ✨ ワンライナーインストールスクリプトを追加
- 🔧 プロセス管理の安定性を向上

### v2.0.0 (2024-01)
- ✨ `.devserver.json`による設定ファイルベース管理
- ✨ `up`/`down`コマンドで一括操作
- ✨ 自動ポート割り当て機能
- ✨ プロセス自動再起動機能
- ✨ ログフィルタリング（正規表現対応）
- ✨ カレントディレクトリ自動検出

### v1.0.0 (2024-01)
- 🎉 初回リリース
- 基本的なプロセス管理機能（start/stop/restart/logs/status）