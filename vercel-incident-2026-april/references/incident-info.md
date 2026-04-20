# Vercel April 2026 Security Incident — 事実関係

## 公式発表

- URL: https://vercel.com/kb/bulletin/vercel-april-2026-security-incident
- 発表日: 2026-04-19

## 経緯

- 2026年4月、Vercel内部システムへの不正アクセスを検知
- 侵入経路: 侵害されたサードパーティAIツールが使用していたGoogle Workspace OAuthアプリ
- 悪性OAuthアプリID: `110671459871-30f1spbu0hptbs60cb4vsmv79i7bbvqj.apps.googleusercontent.com`
- 法執行機関に通報済み、インシデント対応専門家を起用

## 影響範囲

- 「limited subset of customers」が対象（全顧客ではない）
- サービス自体は稼働継続
- **`type: "sensitive"` の環境変数は影響なし**と公式が明言
- それ以外の環境変数（`encrypted` / `plain`）は流出可能性あり → ローテ推奨
- シークレット（APIキー、トークン、DB認証情報、署名鍵）は流出可能性ありとして扱う

## Vercel公式の推奨対応

1. アカウントアクティビティログを確認
2. Sensitive扱いでない環境変数を即座にローテ
3. 今後はSensitive型で保存
4. Google Workspace管理者は悪性OAuthアプリの使用履歴をチェック
5. ローテ支援はvercel.com/helpに連絡

## 追加で実施すべき（公式未記載だが推奨）

- Vercel Access Token（Personal/Team）のローテ
- Webhookシークレットの再発行
- GitHub OAuth許可済みアプリの棚卸し（CMS連携がある場合特に）
- デプロイ履歴から期間中の不正コミット/デプロイ確認
- チームメンバー追加履歴の確認
- 外部サービス（Supabase/Stripe等）の監査ログも確認

## 環境変数の type の違い

| type | 特徴 | 本インシデントでの扱い |
|------|------|------------------|
| `sensitive` | 保存後Dashboard/CLIから値読取不可、ビルドランタイムのみで復号 | 影響なし |
| `encrypted` | 保存時暗号化だが、Dashboard/CLIで再取得可能 | 流出可能性 |
| `plain` | 平文 | 最優先ローテ |

## Sensitive型への移行方法

```bash
# 既存の encrypted を削除し、sensitive で再登録
vercel env rm <KEY> production --yes
echo -n "<VALUE>" | vercel env add <KEY> production --sensitive
```

Sensitive型は一度設定すると値の再取得ができなくなるため、ローテ先の新値を保管した上で移行すること。
