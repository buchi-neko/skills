# つまづきポイント集（実戦で踏んだ罠）

ローテ作業前に必読。これを知らないと必ずどこかで詰まる。

## 🔴 Sensitive変数は Development ターゲット不可

**エラー**: `Error: You cannot set a Sensitive Environment Variable's target to development.`

**理由**: Sensitive型は値が一切取得不可な設計のため、ローカル開発（`vercel env pull`等）で使えない。

**対処**: Sensitive登録時は **Production + Preview のみ** 選択。Developmentは以下で対応:

| 方法 | 内容 | 推奨度 |
|------|------|-------|
| A. ローカル `.env` のみ記載 | `.env`に直接、gitignore済み | ⭕ |
| B. 開発用に別キー発行 | 本番と別値。漏洩しても本番無影響 | ⭐ 最推奨 |
| C. ローカルで使わない | Production/Previewでしか触らない | △ |

`vercel env add NAME --sensitive` はインタラクティブでターゲット選択するので、Developmentのチェックを外す。

## 🔴 Claude Code `!` プレフィックスは non-interactive モード強制

**症状**: Claude Code セッション内で `! vercel env add KEY --sensitive` を実行しても、インタラクティブプロンプトが立たず以下のエラーで落ちる:

```json
{
  "status": "action_required",
  "reason": "missing_requirements",
  "missing": ["missing_value", "missing_environment"],
  "message": "Provide all required inputs for non-interactive mode: --value or stdin; environment..."
}
```

**原因**: `vercel@claude-plugins-official` プラグインが Claude Code 経由の呼び出しを検出し、non-interactive モードを強制する。stderr の先頭に `<claude-code-hint v="1" type="plugin" value="vercel@claude-plugins-official" />` が付くのが目印。

**対処法（2択）**:

### A. 別ターミナル（Terminal.app / iTerm 等）で直接実行 — 推奨
Claude Code セッションとは別のターミナルを開いてそこで実行すると通常のインタラクティブモードで動く:
```bash
vercel env add KEY --sensitive
# → 値プロンプト → 環境選択プロンプト（スペースで複数選択可）
```
Claude Code 側には「登録した」と報告するだけ。値がチャット履歴に残らないため**最も安全**。

### B. non-interactive で完結させる
値を stdin から渡し、環境を明示指定。**1コマンドで複数環境は指定不可**なので、環境ごとに繰り返す:
```bash
printf "%s" "VALUE" | vercel env add KEY production --sensitive --yes
printf "%s" "VALUE" | vercel env add KEY preview --sensitive --yes
```

注意:
- `echo -n` ではなく `printf "%s"` 推奨（bash と zsh で `echo -n` の挙動が違い、末尾改行混入事故の原因になる）
- この方式だと同じキー名で**複数エントリ**が作られる（1エントリ兼任ではない）。後で `rm` する時は環境ごとに3回叩く必要がある。

## 🔴 1エントリで複数環境兼任の場合、`rm`は1回で全消える

**構造**: `vercel env ls` で同じキー名が複数行ある場合と、1行で `target: [development, preview, production]` になっている場合がある。後者は**1エントリ**。

**エラー**: `rm`を3回叩くと2回目以降 `Error: Environment Variable was not found.`

**正解**: `vercel env rm NAME --yes` を **1回だけ**。消えたら終わり。

**判定方法**: API経由で確認
```bash
vercel api "/v9/projects/$PROJECT_ID/env?teamId=$ORG_ID" \
  | jq -r '.envs[] | "\(.key)\t\(.target | join(","))"'
```
targetが `development,preview,production` と1行なら兼任エントリ。

## 🔴 OAuth AppはSecretのみ再生成（Client IDを変えるな）

**間違った手順**: OAuth App削除 → 新規作成
- Client IDも変わる → Vercelの `OAUTH_GITHUB_CLIENT_ID` が古いIDを参照したまま壊れる
- 認証画面で 404 (`This is not the web page you are looking for`)
- Callback URL設定も全部やり直し

**正しい手順**: 既存OAuth App内の「**Generate a new client secret**」ボタンだけ押す。App自体は触らない。

**もし作り直してしまったら**:
1. Client ID も `vercel env rm/add` で更新
2. `vercel redeploy <production-url>`
3. 旧App削除

## 🟡 `vercel env add`直後は必ず再デプロイ（ビルド時に値が焼かれる）

**症状**: 新しい値を登録しても本番で古い値が使われる

**原因**:
- Astro/Next.jsの`import.meta.env`や`process.env`はビルド時に解決される
- `astro-decap-cms-oauth`等のパッケージも同様
- env更新後、再ビルドしない限り古い値のまま

**正解**: 
```bash
# 現在のproduction aliasに対して再ビルド（約35秒）
vercel redeploy https://<production-domain>
```

`--prebuilt` キャッシュを無視して新env値で再ビルド。

## 🟡 `vercel --prod` が本番aliasを更新しないケース

**症状**: `vercel --prod` で「Production」とは出るが、カスタムドメイン（例: `app.example.com`）は古いdeploymentのまま。

**原因**: カスタムドメインのaliasは通常 `github-actions[bot]` が **main push時のみ** 更新する設計。CLI直デプロイはaliasに紐付かない。

**対処**:
- A. `vercel promote <deployment-url>` で手動promote
- B. `vercel redeploy https://<production-domain>` （既存alias対象に再ビルド）
- C. develop → main マージしてCIに任せる（推奨）

## 🟢 未使用envは発行せず削除する判定

新キー発行の前に「このキー本当に使われてる？」を確認:

```bash
# コード参照チェック
grep -r "VAR_NAME" src/ app/ pages/ 2>/dev/null

# 発行元サービスで実利用確認
# 例: GCPならAPI有効化状態、Cloud Logsで直近リクエスト有無
```

全て「使われていない」と判定できれば、**`vercel env rm` だけで対応完了**。新キー発行・登録は不要。

**副次効果**:
- 攻撃面積縮小
- env数制限の節約
- 将来「これ何だっけ？」がなくなる

## 🟢 `vercel logs`は履歴ではなくstreamingのみ

**症状**: `vercel logs <url>` を実行しても過去のエラーログが表示されない。

**制約**: streaming専用。エラー再現中に並行してログコマンドを回す必要。

**代替**:
- `vercel inspect <url> --logs` でビルドログは取得可能（ただしランタイムログではない）
- ランタイムログは Dashboard → Deployments → Functions タブで履歴閲覧

## 💡 Sveltia/Decap CMS特有: OAuth callback `postMessage of null`

**症状**: `Uncaught TypeError: Cannot read properties of null (reading 'postMessage')`

**原因**: 認証成功（codeパラメータ取得済）だが、ポップアップ→親ウィンドウ通知に失敗。

**対処**:
1. ブラウザstorage clear
2. `/admin` を**新規タブで開く**
3. ページ内の「Sign in with GitHub」**ボタン経由**でクリック（URLバー直叩きNG）

## 最速テンプレート

つまづきを避けた最短フロー:

```bash
# 0. 事前確認: キー実利用？
grep -r "KEY_NAME" src/ app/ || echo "未使用 → 削除のみで済む"

# 1. サービス側で「Secret Regenerate」のみ（App/Project/Site本体は触らない）

# 2. Vercel一発更新
vercel env rm KEY_NAME --yes
vercel env add KEY_NAME --sensitive
# → 値ペースト → Production + Preview のみチェック（Dev除外）

# 3. 再デプロイ（必須）
vercel redeploy https://<production-domain>

# 4. 本番動作確認（該当機能を実際に使う）

# 5. サービス側で旧Secret削除
```
