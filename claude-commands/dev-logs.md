# 開発サーバーのログを表示

DevServer MCPを使って開発サーバーのログを確認します。

## Instructions

1. **起動中のサービスを確認**
   - `/mcp__devserver__status {}` でサービス一覧とエイリアスを確認

2. **ログ表示オプションを選択**
   - 表示するサービスを選択（複数可）
   - フィルタリングオプションを確認
   - カラー表示の有無を確認

3. **ログを表示**
   - 基本: `/mcp__devserver__logs {"label":"$LABEL"}`
   - エイリアス使用: `/mcp__devserver__logs {"label":"$ALIAS"}`
   - フィルタ付き: `/mcp__devserver__logs {"label":"$LABEL","grep":"$PATTERN"}`
   - カラー付き: `/mcp__devserver__logs {"label":"$LABEL","color":true}`
   - 行数指定: `/mcp__devserver__logs {"label":"$LABEL","lines":100}`

4. **よく使うフィルタパターン**
   - エラーのみ: `"grep":"ERROR|error"`
   - 警告とエラー: `"grep":"ERROR|WARN|error|warning"`
   - 特定のモジュール: `"grep":"module-name"`

## 使用例

```
# Next.jsのログ（エイリアス使用）
/mcp__devserver__logs {"label":"web"}

# Convexのエラーのみ
/mcp__devserver__logs {"label":"backend","grep":"ERROR"}

# 最新100行をカラー付きで表示
/mcp__devserver__logs {"label":"next","lines":100,"color":true}
```