# サービス別ローテ手順

流出可能性のあるキーごとに「①発行元で新値生成 → ②Vercelに `--sensitive` で登録 → ③再デプロイ → ④動作確認 → ⑤旧値を無効化」の順で実施する。

**作業前に必ず `references/gotchas.md` を読むこと**。知らないと必ず踏む罠がまとまっている。

## 共通Vercel側手順（インタラクティブ版・推奨）

1エントリで複数環境兼任の場合に対応した安全版。

```bash
# 旧値削除（1エントリで複数環境を兼任している場合、1回で全消える）
vercel env rm <KEY> --yes

# 新値を sensitive で登録（インタラクティブで環境選択）
vercel env add <KEY> --sensitive
# → 値プロンプトで新値をペースト
# → Production / Preview のみスペースで選択（Development は Sensitive 不可）
# → Enter で確定

# 再デプロイ必須（env更新だけではビルド済み値が使われる）
vercel redeploy https://<production-domain>
```

**Development環境が必要な場合**: Sensitiveはdevにつけられないため、`.env`ローカル or 別キー発行で対応。詳細は gotchas.md 参照。

## 共通Vercel側手順（環境別個別指定版）

同名キーが環境ごとに別エントリの場合（`vercel env ls` で複数行）:

```bash
vercel env rm <KEY> production --yes
vercel env rm <KEY> preview --yes
# development分は Sensitive にできないので別途運用

echo -n "<NEW_VALUE>" | vercel env add <KEY> production --sensitive
echo -n "<NEW_VALUE>" | vercel env add <KEY> preview --sensitive

vercel redeploy https://<production-domain>
```

**判定**: `vercel env ls` で同キーが複数行あれば環境別、1行で target 欄に複数環境が並んでいれば兼任エントリ。

## GitHub OAuth Client Secret (Sveltia/Decap CMS)

**変数名例**: `OAUTH_GITHUB_CLIENT_SECRET`, `OAUTH_GITHUB_CLIENT_ID`（Client IDは公開情報なので原則触らない）

⚠️ **絶対にOAuth App自体を削除・再作成しない**。Client IDが変わるとVercel側`OAUTH_GITHUB_CLIENT_ID`の更新、Callback URL再設定、認証壊れが連鎖する。

1. GitHub → Settings → Developer settings → OAuth Apps → 対象アプリ（**既存のものをクリック**）
2. 「Client secrets」セクション → 「**Generate a new client secret**」ボタンのみ押す
3. 新Secretをコピー（一度だけ表示）
4. Vercelに新値を登録（共通手順参照）
5. 再デプロイ
6. `https://<本番ドメイン>/admin` でCMSログイン動作確認
7. 動作確認OK後、GitHub管理画面で古いSecretの「Delete」を実行

**動作確認失敗の定番原因**:
- Callback URLが本番ドメインと一致していない（`https://<ドメイン>/api/auth`等）
- ブラウザに古いセッションが残っている → storage clearして新規タブで`/admin`開く
- `postMessage of null` エラー → 新規タブ＋ボタンクリック経由必須（URL直叩きNG）

**dev用に別OAuth Appを使っている場合**: 同じ手順で別Appもローテする。

## Resend API Key

**変数名例**: `RESEND_API_KEY`

1. Resend Dashboard → API Keys
2. 「Create API Key」で新キーを発行（権限は旧キーと同じ）
3. Vercelに新値を登録
4. 旧キーを削除
5. フォーム送信テストで疎通確認

## Google Cloud API Key

**変数名例**: `GOOGLE_CLOUD_API_KEY`

1. GCP Console → APIs & Services → Credentials
2. 新しいAPI Keyを作成（Application restrictions/API restrictionsを旧キーと同じに設定）
3. Vercelに新値を登録
4. 旧キーを削除
5. 対象API呼び出しで動作確認

**注意**: キーに紐付くAPIが複数ある場合（Maps, Places, Translation等）、制限設定を漏れなく複製する。

## reCAPTCHA Secret Key

**変数名例**: `RECAPTCHA_SECRET_KEY`

1. https://www.google.com/recaptcha/admin にアクセス
2. 対象サイト設定 → 「シークレットキーをリセット」
3. Vercelに新値を登録
4. フォーム送信でCAPTCHA検証確認

**注意**: Site Keyは変更不要（公開情報）。Secret Keyのみローテ。

## Stripe API Key（該当プロジェクトの場合）

**変数名例**: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`

1. Stripe Dashboard → Developers → API keys
2. 旧キーを「Roll key」（猶予期間で並行稼働可能）
3. 新値をVercelに登録 → デプロイ
4. Webhook signingも再生成（Webhook endpoints → Signing secret）
5. 旧キーを完全revoke

## Supabase Service Role Key（該当プロジェクトの場合）

**変数名例**: `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`

1. Supabase Dashboard → Project Settings → API
2. 「Roll」でJWT Secretをローテ（**全キーが無効化されるため計画的に**）
3. 新しいservice_role / anon_key をVercelに登録
4. デプロイ
5. アプリ動作確認

**注意**: JWT Secretローテは全セッションを無効化する。リリースタイミングに注意。

## Database Connection String（DATABASE_URL等）

1. DB管理画面でパスワードリセット
2. 新しい接続文字列を構築
3. Vercelに登録
4. 接続テスト

## Vercel Access Token

CLIコマンドでは取得できない。Dashboard操作:

1. https://vercel.com/account/tokens
2. 既存トークンのRevoke
3. 新しいトークンを作成
4. CI/CD等で使用している場合はGitHub Actions/Vercel接続情報を更新

## その他よくあるキー

| 変数名パターン | 発行元 |
|-------------|-------|
| `*_API_KEY` | 各サービスのAPIキー発行画面 |
| `*_CLIENT_SECRET` | OAuth Apps設定 |
| `*_WEBHOOK_SECRET` | 各サービスWebhook設定 |
| `*_PRIVATE_KEY` | 証明書/鍵生成手順 |
| `JWT_SECRET` | ランダム生成: `openssl rand -base64 64` |

## ローテ不要な変数

- `PUBLIC_*` プレフィックス（クライアント公開前提）
- `NODE_ENV`, `*_URL`, `*_STATUS` 等の設定値（機密でないもの）
- Site Key系（reCAPTCHA Site Keyなど）

ただし不要判定は個別精査推奨。

## 未使用envの削除判定（攻撃面積削減）

新キー発行前に「本当に使われてる？」を確認し、未使用なら**削除のみで完了**:

```bash
# コード参照チェック（各プロジェクト構造に合わせてディレクトリ調整）
grep -r "KEY_NAME" src/ app/ pages/ api/ lib/ 2>/dev/null
```

- コード参照0件
- 発行元サービスで実利用形跡なし（Cloud Logsで直近リクエスト無、API未有効化など）
- 現運用で代替手段がある

これら全てtrueなら `vercel env rm KEY_NAME --yes` のみで対応完了。新キー発行スキップ可。

**判定例（実績）**: `GOOGLE_CLOUD_API_KEY` → grep 0件 + Cloud Translation API未有効化 + 現運用で手動処理 → 削除のみで対応完了。

## reCAPTCHA ローテの二択

1. **Reset Secret Key**（既存サイト内でSecretのみ再発行）
   - 即座に旧Secret無効化 → ダウンタイム発生リスク
   - Site Keyは変更なし

2. **新規サイト作成**（推奨）
   - Site Key + Secret Key両方が新しくなる
   - 旧サイトは動作確認後に削除 → 影響を制御しやすい
   - Vercel側は `RECAPTCHA_SECRET_KEY` と `PUBLIC_RECAPTCHA_SITE_KEY` 両方を更新
   - Site Keyは公開なのでSensitive不要（`vercel env add PUBLIC_RECAPTCHA_SITE_KEY`のみ、`--sensitive`なし）
