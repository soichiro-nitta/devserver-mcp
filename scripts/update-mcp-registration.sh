#!/bin/bash
set -euo pipefail

# DevServer MCP登録更新スクリプト
# Node.jsパス変更時に簡単に登録を更新するためのスクリプト

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 DevServer MCP登録更新${NC}"
echo "=========================="

# Claude CLIの確認
if ! command -v claude &> /dev/null; then
    echo -e "${RED}❌ Claude CLIがインストールされていません${NC}"
    exit 1
fi

# Node.jsパスの確認
NODE_PATH=$(which node)
NODE_VERSION=$(node -v)
echo "現在のNode.js:"
echo "  - バージョン: $NODE_VERSION"
echo "  - パス: $NODE_PATH"

# DevServer MCPインストールディレクトリの確認
INSTALL_DIR="$HOME/.devserver-mcp"
if [ ! -d "$INSTALL_DIR" ] || [ ! -f "$INSTALL_DIR/server.mjs" ]; then
    echo -e "${RED}❌ DevServer MCPがインストールされていません${NC}"
    echo "先にインストールしてください: bash install.sh"
    exit 1
fi

echo -e "\nDevServer MCP:"
echo "  - インストール先: $INSTALL_DIR"
echo "  - サーバーファイル: ✅ 存在"

# 現在の登録状況を確認
echo -e "\n📋 現在の登録状況:"
MCP_LIST=$(claude mcp list 2>/dev/null || echo "")

if echo "$MCP_LIST" | grep -q "devserver"; then
    CURRENT_REGISTRATION=$(echo "$MCP_LIST" | grep "devserver")
    echo "$CURRENT_REGISTRATION"
    
    # パスが一致しているかチェック
    if echo "$CURRENT_REGISTRATION" | grep -q "$NODE_PATH"; then
        echo -e "${GREEN}✅ Node.jsパスは既に最新です${NC}"
        
        # 接続状態も確認
        if echo "$CURRENT_REGISTRATION" | grep -q "✓ Connected"; then
            echo -e "${GREEN}✅ 接続も正常です${NC}"
            echo "更新の必要はありません。"
            exit 0
        else
            echo -e "${YELLOW}⚠️  パスは正しいですが接続に失敗しています${NC}"
            echo "登録を更新して接続を修復します..."
        fi
    else
        echo -e "${YELLOW}⚠️  Node.jsパスが古いバージョンを指しています${NC}"
        REGISTERED_PATH=$(echo "$CURRENT_REGISTRATION" | grep -o '/[^ ]*node[^ ]*' || echo "不明")
        echo "  登録されたパス: $REGISTERED_PATH"
        echo "  現在のパス: $NODE_PATH"
        echo "登録を更新します..."
    fi
else
    echo "devserver: 未登録"
    echo -e "${YELLOW}⚠️  DevServer MCPが登録されていません${NC}"
    echo "新規登録します..."
fi

# 登録の更新
echo -e "\n🔄 登録を更新中..."

# 既存の登録を削除（エラーは無視）
echo "既存の登録を削除..."
claude mcp remove devserver 2>/dev/null || echo "  (既存の登録はありませんでした)"

# 新しいパスで登録
echo "新しいパスで登録..."
NEW_COMMAND="$NODE_PATH $INSTALL_DIR/server.mjs"

if claude mcp add devserver "$NEW_COMMAND" -s user; then
    echo -e "${GREEN}✅ 登録が完了しました${NC}"
else
    echo -e "${RED}❌ 登録に失敗しました${NC}"
    exit 1
fi

# 登録結果の確認
echo -e "\n📋 更新後の状況:"
sleep 1  # 少し待ってから確認
UPDATED_LIST=$(claude mcp list 2>/dev/null || echo "")

if echo "$UPDATED_LIST" | grep -q "devserver"; then
    UPDATED_REGISTRATION=$(echo "$UPDATED_LIST" | grep "devserver")
    echo "$UPDATED_REGISTRATION"
    
    if echo "$UPDATED_REGISTRATION" | grep -q "✓ Connected"; then
        echo -e "${GREEN}✅ 更新成功！接続も正常です${NC}"
    else
        echo -e "${YELLOW}⚠️  登録は完了しましたが、接続に問題があります${NC}"
        echo -e "\n🔍 トラブルシューティング:"
        echo "1. MCPサーバーを直接実行してテスト:"
        echo "   cd $INSTALL_DIR && node server.mjs"
        echo ""
        echo "2. 依存関係を再インストール:"
        echo "   cd $INSTALL_DIR && npm install"
        echo ""
        echo "3. 完全再インストール:"
        echo "   rm -rf $INSTALL_DIR && bash install.sh"
    fi
else
    echo -e "${RED}❌ 登録の確認に失敗しました${NC}"
    exit 1
fi

echo -e "\n${BLUE}✨ 完了${NC}"