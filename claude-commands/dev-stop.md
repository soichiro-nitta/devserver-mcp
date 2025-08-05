# 開発サーバーを停止

DevServer MCPを使って現在のプロジェクトの開発サーバーを停止します。

## Instructions

1. **現在の状態を確認**
   - `/mcp__devserver__status {}` で起動中のプロセスを表示
   - プロジェクト名とサービス一覧を確認

2. **開発サーバーを停止**
   - 設定ファイルベース: `/mcp__devserver__down {}`
   - グループ操作: `/mcp__devserver__groupStop {"project":"$PROJECT_NAME"}`
   - 個別停止が必要な場合: `/mcp__devserver__stop {"label":"$LABEL"}`

3. **停止確認**
   - `/mcp__devserver__status {}` で停止を確認
   - 「現在起動中のプロセスはありません」と表示されることを確認

## 注意事項

- グループ操作の場合、プロジェクトに関連するすべてのサービスが停止されます
- 個別のサービスのみ停止したい場合は、`stop` コマンドを使用してください