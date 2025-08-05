#!/bin/bash

# DevServer MCP 互換性チェックスクリプト

echo "🔍 DevServer MCP 互換性チェック"
echo "================================"

# 色の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Node.jsバージョンチェック
echo -e "\n📊 Node.js環境:"
NODE_VERSION=$(node -v 2>/dev/null || echo "")
if [ -z "$NODE_VERSION" ]; then
    echo -e "${RED}❌ Node.jsがインストールされていません${NC}"
    exit 1
fi

NODE_PATH=$(which node)
NODE_REAL_PATH=$(readlink -f "$NODE_PATH" 2>/dev/null || realpath "$NODE_PATH" 2>/dev/null || echo "$NODE_PATH")
NODE_MAJOR_VERSION=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')

echo "  - バージョン: $NODE_VERSION"
echo "  - パス: $NODE_PATH"
if [ "$NODE_PATH" != "$NODE_REAL_PATH" ]; then
    echo "  - 実際のパス: $NODE_REAL_PATH"
fi

if [ "$NODE_MAJOR_VERSION" -lt 18 ]; then
    echo -e "${RED}  ⚠️  Node.js v18以上が必要です${NC}"
else
    echo -e "${GREEN}  ✅ バージョン互換性OK${NC}"
fi

# Node.jsバージョン管理ツールの検出
echo -e "\n🔧 Node.js管理ツール:"
NODE_MANAGER="none"
if [ -n "${N_PREFIX:-}" ] || command -v n &> /dev/null; then
    NODE_MANAGER="n"
    echo "  - 検出: n"
    if command -v n &> /dev/null; then
        echo "  - インストール済みバージョン:"
        n list 2>/dev/null | head -5 | sed 's/^/    /'
    fi
elif [ -n "${NVM_DIR:-}" ] || command -v nvm &> /dev/null; then
    NODE_MANAGER="nvm"
    echo "  - 検出: nvm"
elif command -v volta &> /dev/null; then
    NODE_MANAGER="volta"
    echo "  - 検出: volta"
    volta list node 2>/dev/null | head -5 | sed 's/^/    /'
else
    echo "  - 検出されませんでした"
fi

# Claude MCP設定チェック
echo -e "\n🔌 Claude MCP設定:"
if command -v claude &> /dev/null; then
    # MCP登録状態をチェック
    MCP_STATUS=$(claude mcp get devserver 2>&1 || echo "not registered")
    
    if [[ "$MCP_STATUS" == *"not registered"* ]] || [[ "$MCP_STATUS" == *"not found"* ]]; then
        echo -e "${RED}  ❌ DevServer MCPが登録されていません${NC}"
    else
        echo -e "${GREEN}  ✅ DevServer MCPが登録されています${NC}"
        
        # 登録されているパスを確認
        if [[ "$MCP_STATUS" == *"Command:"* ]]; then
            REGISTERED_CMD=$(echo "$MCP_STATUS" | grep "Command:" | sed 's/.*Command: //')
            echo "  - 登録コマンド: $REGISTERED_CMD"
            
            # 現在のNode.jsパスと一致するか確認
            if [[ "$REGISTERED_CMD" != *"$NODE_REAL_PATH"* ]]; then
                echo -e "${YELLOW}  ⚠️  登録されているNode.jsパスが現在のパスと異なります${NC}"
                echo "     再登録が必要です"
            fi
        fi
        
        # 接続状態を確認
        if [[ "$MCP_STATUS" == *"Failed to connect"* ]]; then
            echo -e "${RED}  ❌ 接続に失敗しています${NC}"
        elif [[ "$MCP_STATUS" == *"Connected"* ]]; then
            echo -e "${GREEN}  ✅ 接続成功${NC}"
        fi
    fi
else
    echo -e "${YELLOW}  ⚠️  Claude CLIがインストールされていません${NC}"
fi

# DevServer MCPインストール状態
echo -e "\n📦 DevServer MCPインストール:"
INSTALL_DIR="${HOME}/.devserver-mcp"
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${GREEN}  ✅ インストール済み${NC}"
    echo "  - パス: $INSTALL_DIR"
    
    # server.mjsの存在確認
    if [ -f "$INSTALL_DIR/server.mjs" ]; then
        echo -e "${GREEN}  ✅ server.mjsが存在します${NC}"
    else
        echo -e "${RED}  ❌ server.mjsが見つかりません${NC}"
    fi
    
    # 依存関係の確認
    if [ -d "$INSTALL_DIR/node_modules" ]; then
        echo -e "${GREEN}  ✅ 依存関係インストール済み${NC}"
    else
        echo -e "${RED}  ❌ 依存関係がインストールされていません${NC}"
        echo "     cd $INSTALL_DIR && npm install を実行してください"
    fi
else
    echo -e "${RED}  ❌ インストールされていません${NC}"
fi

# 推奨事項
echo -e "\n💡 推奨事項:"
if [ "$NODE_MANAGER" != "none" ]; then
    echo "  - Node.jsバージョンを切り替えた場合は、必ずClaude MCP登録を更新してください"
    echo "    実行: ./update-mcp-registration.sh"
fi

if [ "$NODE_MAJOR_VERSION" -ge 24 ]; then
    echo -e "${YELLOW}  - Node.js v24以降を使用中です。互換性問題が発生する可能性があります${NC}"
    echo "    推奨: Node.js v20 LTS または v22 LTS"
fi

echo -e "\n✨ チェック完了"