#!/bin/bash
set -euo pipefail

# DevServer MCP ワンライナーインストールスクリプト
# 使い方: curl -sSL https://example.com/install.sh | bash

echo "🚀 DevServer MCP セットアップを開始します..."

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# エラーハンドリング
trap 'echo -e "${RED}エラーが発生しました。セットアップを中止します。${NC}"; exit 1' ERR

# OS判定
OS="$(uname -s)"
case "${OS}" in
    Linux*)     OS_TYPE=Linux;;
    Darwin*)    OS_TYPE=Mac;;
    *)          echo -e "${RED}サポートされていないOS: ${OS}${NC}"; exit 1;;
esac

# Node.jsのバージョンと互換性チェック
NODE_VERSION=$(node -v 2>/dev/null || echo "")
if [ -z "$NODE_VERSION" ]; then
    echo -e "${RED}❌ Node.jsがインストールされていません${NC}"
    exit 1
fi

NODE_MAJOR_VERSION=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
if [ "$NODE_MAJOR_VERSION" -lt 18 ]; then
    echo -e "${RED}❌ Node.js v18以上が必要です（現在: $NODE_VERSION）${NC}"
    echo "    推奨: Node.js v20 LTS または v22 LTS"
    exit 1
fi

# Node.jsの実行パスを動的に検出
NODE_PATH=$(which node)
if [ -z "$NODE_PATH" ]; then
    echo -e "${RED}❌ Node.jsの実行パスが見つかりません${NC}"
    exit 1
fi

# Node.jsの実際のパスを解決（シンボリックリンクの場合）
NODE_REAL_PATH=$(readlink -f "$NODE_PATH" 2>/dev/null || realpath "$NODE_PATH" 2>/dev/null || echo "$NODE_PATH")

echo "📋 環境情報:"
echo "  - OS: ${OS_TYPE}"
echo "  - Node.js: $NODE_VERSION (パス: $NODE_PATH)"
echo "  - npm: $(npm -v)"

# Node.jsバージョン管理ツールの検出
NODE_MANAGER=""
if [ -n "${N_PREFIX:-}" ]; then
    NODE_MANAGER="n"
elif [ -n "${NVM_DIR:-}" ]; then
    NODE_MANAGER="nvm"
elif command -v volta &> /dev/null; then
    NODE_MANAGER="volta"
fi

if [ -n "$NODE_MANAGER" ]; then
    echo "  - Node.js管理: $NODE_MANAGER"
    echo -e "${YELLOW}⚠️  Node.jsバージョン管理ツールが検出されました${NC}"
    echo "     バージョン切り替え時はClaude MCP登録の更新が必要です"
fi

# インストール先の決定
INSTALL_DIR="${HOME}/.devserver-mcp"
echo -e "\n📁 インストール先: ${INSTALL_DIR}"

# 既存のインストールチェック
if [ -d "${INSTALL_DIR}" ]; then
    echo -e "${YELLOW}既にインストールされています。上書きしますか？ (y/N)${NC}"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "インストールをキャンセルしました。"
        exit 0
    fi
    rm -rf "${INSTALL_DIR}"
fi

# ディレクトリ作成
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# package.jsonの作成
echo -e "\n📝 package.json を作成中..."
cat > package.json << 'EOF'
{
  "name": "devserver-mcp-global",
  "version": "3.0.0",
  "description": "DevServer MCP Global Installation",
  "type": "module",
  "scripts": {
    "start": "node server.mjs"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "latest",
    "strip-ansi": "^7.1.0"
  }
}
EOF

# server.mjsをダウンロード（実際の環境では適切なURLから取得）
echo -e "\n📥 server.mjs をダウンロード中..."
if [ -f "/Users/soichiro/Work/devserver-mcp/server.mjs" ]; then
    # ローカル開発時はコピー
    cp /Users/soichiro/Work/devserver-mcp/server.mjs .
else
    # 本番環境ではGitHubなどから取得
    curl -sSL https://raw.githubusercontent.com/yourusername/devserver-mcp/main/server.mjs -o server.mjs
fi

# 依存関係のインストール
echo -e "\n📦 依存関係をインストール中..."
npm install --quiet

# 実行権限の付与
chmod +x server.mjs

# 便利スクリプトをダウンロード・コピー
echo -e "\n🔧 便利スクリプトをインストール中..."
mkdir -p scripts

if [ -d "/Users/soichiro/Work/devserver-mcp/scripts" ]; then
    # ローカル開発時はコピー
    cp /Users/soichiro/Work/devserver-mcp/scripts/*.sh scripts/
else
    # 本番環境ではGitHubから取得
    curl -sSL https://raw.githubusercontent.com/yourusername/devserver-mcp/main/scripts/check-compatibility.sh -o scripts/check-compatibility.sh
    curl -sSL https://raw.githubusercontent.com/yourusername/devserver-mcp/main/scripts/update-mcp-registration.sh -o scripts/update-mcp-registration.sh
fi

# 実行権限を付与
chmod +x scripts/*.sh

# サービス登録
if [ "${OS_TYPE}" = "Mac" ]; then
    echo -e "\n🔧 LaunchAgent を設定中..."
    
    # LaunchAgent plistの作成
    PLIST_PATH="${HOME}/Library/LaunchAgents/com.devserver.mcp.plist"
    cat > "${PLIST_PATH}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.devserver.mcp</string>
    <key>ProgramArguments</key>
    <array>
        <string>${NODE_PATH}</string>
        <string>${INSTALL_DIR}/server.mjs</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${INSTALL_DIR}</string>
    <key>StandardOutPath</key>
    <string>${INSTALL_DIR}/logs/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${INSTALL_DIR}/logs/stderr.log</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
</dict>
</plist>
EOF
    
    # ログディレクトリの作成
    mkdir -p "${INSTALL_DIR}/logs"
    
    # サービスの読み込み（オプション）
    echo -e "${YELLOW}LaunchAgentを自動起動として登録しますか？ (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        launchctl load "${PLIST_PATH}"
        echo -e "${GREEN}✅ LaunchAgent を登録しました${NC}"
    fi

elif [ "${OS_TYPE}" = "Linux" ]; then
    echo -e "\n🔧 systemd サービスを設定中..."
    
    # systemd service fileの作成
    SERVICE_PATH="${HOME}/.config/systemd/user/devserver-mcp.service"
    mkdir -p "${HOME}/.config/systemd/user"
    
    cat > "${SERVICE_PATH}" << EOF
[Unit]
Description=DevServer MCP
After=network.target

[Service]
Type=simple
ExecStart=${NODE_PATH} ${INSTALL_DIR}/server.mjs
WorkingDirectory=${INSTALL_DIR}
Restart=on-failure
RestartSec=10
StandardOutput=append:${INSTALL_DIR}/logs/stdout.log
StandardError=append:${INSTALL_DIR}/logs/stderr.log

[Install]
WantedBy=default.target
EOF
    
    # ログディレクトリの作成
    mkdir -p "${INSTALL_DIR}/logs"
    
    # サービスの有効化（オプション）
    echo -e "${YELLOW}systemdサービスを有効化しますか？ (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        systemctl --user daemon-reload
        systemctl --user enable devserver-mcp.service
        systemctl --user start devserver-mcp.service
        echo -e "${GREEN}✅ systemd サービスを有効化しました${NC}"
    fi
fi

# Claude MCPへの登録
echo -e "\n🔗 Claude MCP への登録..."
if command -v claude &> /dev/null; then
    # 既存の登録を削除
    claude mcp remove devserver &> /dev/null || true
    
    echo -e "${YELLOW}Claude MCP に登録しますか？ (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # 既存の登録を削除（エラーは無視）
        claude mcp remove devserver 2>/dev/null || true
        
        # フルパスとenv設定で登録
        claude mcp add-json devserver "{
  \"type\": \"stdio\",
  \"command\": \"${NODE_REAL_PATH}\",
  \"args\": [\"${INSTALL_DIR}/server.mjs\"],
  \"env\": {
    \"PATH\": \"$(dirname "$NODE_REAL_PATH"):${PATH}\",
    \"NODE_PATH\": \"$(dirname "$NODE_REAL_PATH")/../lib/node_modules\"
  }
}" -s user
        echo -e "${GREEN}✅ Claude MCP に登録しました${NC}"
        echo "   Node.jsパス: ${NODE_REAL_PATH}"
        echo -e "${YELLOW}⚠️  新しいClaude Codeセッションを開始してください${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Claude CLI がインストールされていません${NC}"
    echo "後で以下のコマンドで登録してください:"
    echo "claude mcp add devserver \"${NODE_PATH} ${INSTALL_DIR}/server.mjs\" -s user"
fi

# Claude Commandsのインストール
echo -e "\n📝 Claude Commands のインストール..."
if command -v claude &> /dev/null; then
    echo -e "${YELLOW}便利なスラッシュコマンドをインストールしますか？ (y/N)${NC}"
    echo "  含まれるコマンド:"
    echo "  - /project:devserver    (総合管理)"
    echo "  - /project:dev-start    (起動)"
    echo "  - /project:dev-stop     (停止)"
    echo "  - /project:dev-logs     (ログ表示)"
    echo "  - /project:dev-restart  (再起動)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # グローバルコマンドディレクトリを作成
        mkdir -p "${HOME}/.claude/commands"
        
        # claude-commandsディレクトリをダウンロード
        COMMANDS_DIR="${INSTALL_DIR}/claude-commands"
        mkdir -p "${COMMANDS_DIR}"
        
        # 各コマンドファイルをダウンロード（ローカル開発時はコピー）
        if [ -d "/Users/soichiro/Work/devserver-mcp/claude-commands" ]; then
            cp -r /Users/soichiro/Work/devserver-mcp/claude-commands/*.md "${COMMANDS_DIR}/"
        else
            # 本番環境では各ファイルをダウンロード
            for cmd in devserver dev-start dev-stop dev-logs dev-restart; do
                curl -sSL "https://raw.githubusercontent.com/yourusername/devserver-mcp/main/claude-commands/${cmd}.md" \
                     -o "${COMMANDS_DIR}/${cmd}.md"
            done
        fi
        
        # グローバルコマンドディレクトリにコピー
        cp -r "${COMMANDS_DIR}"/*.md "${HOME}/.claude/commands/"
        
        echo -e "${GREEN}✅ Claude Commands をインストールしました${NC}"
        echo "   Claude Code で /project:devserver と入力して使い方を確認できます"
    fi
fi

# サンプル設定ファイルの作成
echo -e "\n📄 サンプル設定ファイルを作成中..."
cat > "${HOME}/.devserver.json.example" << 'EOF'
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
EOF

# 環境変数の設定案内
echo -e "\n🔐 セキュリティ設定（オプション）"
echo "認証を有効にする場合は、以下の環境変数を設定してください:"
echo "  export DEVSERVER_AUTH=true"
echo "  export DEVSERVER_TOKEN=your-secret-token"

# 完了メッセージ
echo -e "\n${GREEN}✨ DevServer MCP のインストールが完了しました！${NC}"
echo
echo "📚 使い方:"
echo "  1. プロジェクトのルートに .devserver.json を作成"
echo "  2. Claude Code で以下のコマンドを実行:"
echo "     /mcp__devserver__up {}"
echo "     /mcp__devserver__logs {\"label\":\"next\"}"
echo "     /mcp__devserver__down {}"
echo
echo "🔧 Node.jsバージョン切り替え時の対応:"
echo "  便利スクリプトで簡単に更新できます:"
echo "  ${INSTALL_DIR}/scripts/update-mcp-registration.sh"
echo ""
echo "  または手動で："
echo "  claude mcp remove devserver"
echo "  claude mcp add devserver \"\$(which node) ${INSTALL_DIR}/server.mjs\" -s user"
echo ""
echo "🔍 互換性チェック:"
echo "  ${INSTALL_DIR}/scripts/check-compatibility.sh"
echo
echo "📖 詳細なドキュメント:"
echo "  https://github.com/yourusername/devserver-mcp"
echo
echo "🎉 Happy Coding!"

# クリーンアップ関数
cleanup() {
    cd - > /dev/null
}

# 正常終了
trap cleanup EXIT