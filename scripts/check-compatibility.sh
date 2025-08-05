#!/bin/bash
set -euo pipefail

# DevServer MCP 互換性チェックスクリプト
# Node.jsバージョンとClaude MCP登録状況をチェック

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 DevServer MCP 互換性チェック${NC}"
echo "=================================="

# 1. Node.jsバージョンチェック
echo -e "\n📋 Node.js環境:"
NODE_VERSION=$(node -v 2>/dev/null || echo "")
if [ -z "$NODE_VERSION" ]; then
    echo -e "${RED}❌ Node.jsがインストールされていません${NC}"
    exit 1
fi

NODE_MAJOR_VERSION=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
NODE_PATH=$(which node)

echo "  - バージョン: $NODE_VERSION"
echo "  - パス: $NODE_PATH"

if [ "$NODE_MAJOR_VERSION" -lt 18 ]; then
    echo -e "${RED}❌ Node.js v18以上が必要です${NC}"
    echo "  現在: $NODE_VERSION"
    echo "  対処法: Node.jsをアップグレードしてください"
    exit 1
elif [ "$NODE_MAJOR_VERSION" -ge 18 ] && [ "$NODE_MAJOR_VERSION" -lt 20 ]; then
    echo -e "${YELLOW}⚠️  サポートされていますが、v20以上を推奨します${NC}"
else
    echo -e "${GREEN}✅ サポートされているバージョンです${NC}"
fi

# 2. Node.jsバージョン管理ツールの検出
echo -e "\n🔧 Node.js管理ツール:"
NODE_MANAGER=""
if [ -n "${N_PREFIX:-}" ]; then
    NODE_MANAGER="n"
    echo "  - 検出: n (Node.js Version Manager)"
    echo "  - PREFIX: $N_PREFIX"
elif [ -n "${NVM_DIR:-}" ]; then
    NODE_MANAGER="nvm"
    echo "  - 検出: nvm (Node Version Manager)"
    echo "  - NVM_DIR: $NVM_DIR"
elif command -v volta &> /dev/null; then
    NODE_MANAGER="volta"
    echo "  - 検出: volta (JavaScript Tool Manager)"
    echo "  - パス: $(which volta)"
else
    echo "  - システム標準のNode.js"
fi

if [ -n "$NODE_MANAGER" ]; then
    echo -e "${YELLOW}⚠️  バージョン管理ツールが検出されました${NC}"
    echo "     バージョン切り替え時はClaude MCP登録の更新が必要です"
fi

# 3. Claude CLIの確認
echo -e "\n🎯 Claude CLI:"
if command -v claude &> /dev/null; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "不明")
    echo "  - インストール済み: $CLAUDE_VERSION"
    echo -e "${GREEN}✅ Claude CLI が利用可能です${NC}"
    
    # 4. MCP登録状況の確認
    echo -e "\n🔗 Claude MCP登録状況:"
    MCP_LIST=$(claude mcp list 2>/dev/null || echo "")
    
    if echo "$MCP_LIST" | grep -q "devserver"; then
        # devserver登録の詳細を取得
        DEVSERVER_LINE=$(echo "$MCP_LIST" | grep "devserver")
        echo "  - 登録: あり"
        echo "  - 詳細: $DEVSERVER_LINE"
        
        # パスの一致確認
        if echo "$DEVSERVER_LINE" | grep -q "$NODE_PATH"; then
            echo -e "${GREEN}✅ Node.jsパスが一致しています${NC}"
        else
            echo -e "${RED}❌ Node.jsパスが一致しません${NC}"
            echo "  現在のNode.js: $NODE_PATH"
            echo "  登録されたパス: $(echo "$DEVSERVER_LINE" | grep -o '/[^ ]*node[^ ]*')"
            echo ""
            echo -e "${YELLOW}📝 修正方法:${NC}"
            echo "  claude mcp remove devserver"
            echo "  claude mcp add devserver \"$NODE_PATH ~/.devserver-mcp/server.mjs\" -s user"
        fi
        
        # 接続状態の確認
        if echo "$DEVSERVER_LINE" | grep -q "✓ Connected"; then
            echo -e "${GREEN}✅ 接続成功${NC}"
        else
            echo -e "${RED}❌ 接続失敗${NC}"
            echo -e "${YELLOW}📝 対処法:${NC}"
            echo "  1. パスの確認と更新"
            echo "  2. MCPサーバーの直接実行テスト:"
            echo "     cd ~/.devserver-mcp && node server.mjs"
        fi
    else
        echo "  - 登録: なし"
        echo -e "${YELLOW}⚠️  DevServer MCPが登録されていません${NC}"
        echo -e "${YELLOW}📝 登録方法:${NC}"
        echo "  claude mcp add devserver \"$NODE_PATH ~/.devserver-mcp/server.mjs\" -s user"
    fi
else
    echo -e "${RED}❌ Claude CLIがインストールされていません${NC}"
    echo "  インストール方法: https://claude.ai/cli"
fi

# 5. DevServer MCPインストール状況
echo -e "\n📦 DevServer MCPインストール:"
INSTALL_DIR="$HOME/.devserver-mcp"
if [ -d "$INSTALL_DIR" ]; then
    echo "  - インストール: あり"
    echo "  - パス: $INSTALL_DIR"
    
    if [ -f "$INSTALL_DIR/server.mjs" ]; then
        echo -e "${GREEN}✅ server.mjsが存在します${NC}"
        
        # 実行権限の確認
        if [ -x "$INSTALL_DIR/server.mjs" ]; then
            echo -e "${GREEN}✅ 実行権限があります${NC}"
        else
            echo -e "${YELLOW}⚠️  実行権限がありません${NC}"
            echo "  修正: chmod +x $INSTALL_DIR/server.mjs"
        fi
    else
        echo -e "${RED}❌ server.mjsが見つかりません${NC}"
    fi
    
    if [ -f "$INSTALL_DIR/package.json" ]; then
        echo -e "${GREEN}✅ package.jsonが存在します${NC}"
        
        # 依存関係の確認
        if [ -d "$INSTALL_DIR/node_modules" ]; then
            echo -e "${GREEN}✅ 依存関係がインストール済みです${NC}"
        else
            echo -e "${YELLOW}⚠️  依存関係がインストールされていません${NC}"
            echo "  修正: cd $INSTALL_DIR && npm install"
        fi
    else
        echo -e "${RED}❌ package.jsonが見つかりません${NC}"
    fi
else
    echo -e "${RED}❌ DevServer MCPがインストールされていません${NC}"
    echo "  インストール: bash /path/to/install.sh"
fi

# 6. 推奨アクション
echo -e "\n🎯 推奨アクション:"

# Node.jsバージョンが古い場合
if [ "$NODE_MAJOR_VERSION" -lt 20 ]; then
    echo -e "${YELLOW}1. Node.jsをv20以上にアップグレード${NC}"
    if [ "$NODE_MANAGER" = "n" ]; then
        echo "   sudo n 20"
    elif [ "$NODE_MANAGER" = "nvm" ]; then
        echo "   nvm install 20 && nvm use 20"
    elif [ "$NODE_MANAGER" = "volta" ]; then
        echo "   volta install node@20"
    fi
fi

# MCP登録が問題ある場合
if echo "$MCP_LIST" | grep "devserver" | grep -q "❌"; then
    echo -e "${YELLOW}2. Claude MCP登録を更新${NC}"
    echo "   claude mcp remove devserver"
    echo "   claude mcp add devserver \"$NODE_PATH ~/.devserver-mcp/server.mjs\" -s user"
fi

# インストールが不完全な場合
if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/server.mjs" ]; then
    echo -e "${YELLOW}3. DevServer MCPを再インストール${NC}"
    echo "   bash /path/to/install.sh"
fi

echo -e "\n${BLUE}チェック完了${NC}"