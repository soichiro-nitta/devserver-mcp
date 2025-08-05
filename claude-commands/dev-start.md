# 開発サーバーを起動

DevServer MCPを使って現在のプロジェクトの開発サーバーを起動します。

## Instructions

1. **現在のディレクトリを確認**
   - `pwd` でプロジェクトディレクトリを確認
   - プロジェクト名を取得: `$PROJECT_NAME`

2. **.devserver.jsonの存在確認**
   - ファイルが存在するか確認
   - なければ作成を提案

3. **開発サーバーを起動**
   - 設定ファイルがある場合: `/mcp__devserver__up {}`
   - グループ操作の場合: `/mcp__devserver__groupStart {"project":"$PROJECT_NAME"}`

4. **起動確認**
   - `/mcp__devserver__status {}` で状態を表示
   - 各サービスのポート情報を確認

5. **アクセス情報を表示**
   - Next.js: http://localhost:3000
   - Convex Dashboard: https://dashboard.convex.dev
   - その他設定されたサービスのURL

## エイリアス情報

設定されているエイリアスも表示：
- `web` → `next`
- `backend` → `convex`

ログ確認の例：
```
/mcp__devserver__logs {"label":"web"}
/mcp__devserver__logs {"label":"backend"}
```