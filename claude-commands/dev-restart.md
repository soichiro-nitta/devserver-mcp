# 開発サーバーを再起動

DevServer MCPを使って開発サーバーを再起動します。

## Instructions

1. **再起動対象を確認**
   - `/mcp__devserver__status {}` で起動中のサービスを確認
   - 再起動するサービスを選択（全体 or 個別）

2. **再起動を実行**
   - 個別サービス: `/mcp__devserver__restart {"label":"$LABEL"}`
   - 全サービス（一括停止→起動）:
     1. `/mcp__devserver__down {}`
     2. 1秒待機
     3. `/mcp__devserver__up {}`

3. **再起動確認**
   - `/mcp__devserver__status {}` で新しいPIDと稼働時間を確認
   - ポート情報が正しく設定されているか確認

4. **ログ確認**
   - 再起動後のログを表示して正常動作を確認
   - エラーが出ていないか確認

## 使用例

```
# Next.jsのみ再起動
/mcp__devserver__restart {"label":"next"}

# エイリアスを使って再起動
/mcp__devserver__restart {"label":"web"}

# 全サービスを再起動（ai-zaiko）
/mcp__devserver__down {}
# 1秒待機
/mcp__devserver__up {}
```