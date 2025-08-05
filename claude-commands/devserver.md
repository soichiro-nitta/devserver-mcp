# DevServer MCP を使用

DevServer MCPを使って開発サーバーを管理します。

## Instructions

1. **接続状態を確認**
   - `claude mcp list` でdevserverが接続されているか確認
   - `✗ Failed to connect` の場合は、トラブルシューティングを実行

2. **プロジェクトの.devserver.jsonを確認**
   - プロジェクトルートに `.devserver.json` があるか確認
   - なければサンプルを作成

3. **開発サーバーを起動**
   - グループ操作で一括起動: `/mcp__devserver__groupStart {"project":"$PROJECT_NAME"}`
   - または設定ファイルベースで起動: `/mcp__devserver__up {}`

4. **状態確認とログ表示**
   - 起動状態を確認: `/mcp__devserver__status {}`
   - ログを表示（エイリアス使用可）

5. **必要に応じて停止**
   - グループ操作で一括停止: `/mcp__devserver__groupStop {"project":"$PROJECT_NAME"}`
   - または: `/mcp__devserver__down {}`

## 使用例

### ai-zaikoプロジェクトの場合
```
# 起動
/mcp__devserver__groupStart {"project":"ai-zaiko"}

# ログ確認
/mcp__devserver__logs {"label":"web"}      # Next.js
/mcp__devserver__logs {"label":"backend"}   # Convex

# 停止
/mcp__devserver__groupStop {"project":"ai-zaiko"}
```

## トラブルシューティング

MCPが接続されていない場合：
1. `claude mcp remove devserver`
2. `claude mcp add devserver "node /Users/soichiro/Work/devserver-mcp/server.mjs" -s user`
3. 新しいClaude Codeセッションを開始（exit → claude）