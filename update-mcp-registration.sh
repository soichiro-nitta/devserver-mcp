#!/bin/bash

# DevServer MCP登録更新スクリプト
# Node.jsバージョン切り替え後に実行してください

echo "🔄 DevServer MCP登録更新"
echo "========================"

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Claude CLIの確認
if ! command -v claude &> /dev/null; then
    echo -e "${RED}❌ Claude CLIがインストールされていません${NC}"
    exit 1
fi

# DevServer MCPインストールディレクトリ
INSTALL_DIR="${HOME}/.devserver-mcp"
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}❌ DevServer MCPがインストールされていません${NC}"
    echo "   先にinstall.shを実行してください"
    exit 1
fi

# Node.jsパスの検出
NODE_PATH=$(which node)
if [ -z "$NODE_PATH" ]; then
    echo -e "${RED}❌ Node.jsが見つかりません${NC}"
    exit 1
fi

NODE_REAL_PATH=$(readlink -f "$NODE_PATH" 2>/dev/null || realpath "$NODE_PATH" 2>/dev/null || echo "$NODE_PATH")
NODE_VERSION=$(node -v)

echo "📋 現在の環境:"
echo "  - Node.js: $NODE_VERSION"
echo "  - パス: $NODE_REAL_PATH"

# 既存の登録を削除
echo -e "\n🗑️  既存の登録を削除中..."
claude mcp remove devserver &> /dev/null || true

# 新規登録
echo -e "\n📝 新しい設定で登録中..."
claude mcp add-json devserver "{
  \"type\": \"stdio\",
  \"command\": \"${NODE_REAL_PATH}\",
  \"args\": [\"${INSTALL_DIR}/server.mjs\"],
  \"env\": {
    \"PATH\": \"$(dirname "$NODE_REAL_PATH"):${PATH}\",
    \"NODE_PATH\": \"$(dirname "$NODE_REAL_PATH")/../lib/node_modules\"
  }
}" -s user

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 登録が完了しました${NC}"
else
    echo -e "${RED}❌ 登録に失敗しました${NC}"
    exit 1
fi

# 登録確認
echo -e "\n🔍 登録状態を確認中..."
MCP_STATUS=$(claude mcp get devserver 2>&1)

if [[ "$MCP_STATUS" == *"Command:"* ]]; then
    echo -e "${GREEN}✅ DevServer MCPが正しく登録されています${NC}"
    echo "$MCP_STATUS" | grep -E "(Command:|Status:)" | sed 's/^/  /'
else
    echo -e "${YELLOW}⚠️  登録の確認ができませんでした${NC}"
fi

echo -e "\n${YELLOW}⚠️  重要: 新しいClaude Codeセッションを開始してください${NC}"
echo "   実行: exit → claude"
echo -e "\n✨ 更新完了"