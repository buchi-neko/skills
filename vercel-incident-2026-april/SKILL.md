---
name: vercel-incident-2026-april
description: "Investigates and remediates exposure from the Vercel April 2026 security incident on any Vercel-linked project. Runs activity/webhook/env/integration audits, detects unauthorized actors, flags env vars that lack the 'sensitive' type, and produces a prioritized rotation plan. Use when the user mentions Vercel security incident, April 2026 incident, OAuth compromise, secret rotation on Vercel, or asks to audit a Vercel project for exposure. Also use when switching to a different project and needing to re-run the same incident response checks."
license: MIT
compatibility: "Designed for Claude Code. Requires Vercel CLI >= 51.0.0 and jq."
allowed-tools: Bash Read Write Edit Grep Glob
metadata:
  author: buchi-neko
  version: "1.0.0"
  user-invocable: "true"
  argument-hint: "[optional: project subdirectory]"
---

# Vercel April 2026 Security Incident Response

## インシデント概要（参照: references/incident-info.md）

2026年4月にVercelで発生した不正アクセス事案。**原因は侵害されたサードパーティAIツールのGoogle Workspace OAuthアプリ**。`type: "sensitive"` でない環境変数が流出の可能性。全Vercelユーザーが対象ではなく「limited subset」だが、Sensitive未設定の環境変数を持つプロジェクトは全てローテ前提で対応する。

## 実行フロー

### Phase 1: 前提チェック

以下を順に確認し、不足があれば対処してから続行する。

1. **Vercel CLIバージョン**: `vercel --version`
   - **51.0.0未満**は `activity` / `webhooks` コマンドが無いため、先に `npm i -g vercel@latest` でアップグレード必須。ユーザー確認不要（read-only調査に必要なため）。
2. **ログイン状態**: `vercel whoami`（未ログインなら `vercel login` を案内）
3. **プロジェクトリンク**: `.vercel/project.json` の存在確認。無ければ `vercel link` を案内。
4. **チームスコープ取得**: `.vercel/project.json` から `orgId` と `projectId` を読み取る。以降 `--scope <team>` や `teamId` クエリで使用。
5. **gotchas.md の存在確認**: `references/gotchas.md` を事前に参照。ローテ実施時に必ず踏む罠（Sensitive+dev不可、rm一回で全消え、OAuth App構造）を先に把握する。

### Phase 2: 監査実行（read-only）

`scripts/investigate.sh` を実行して並列に調査結果を収集する。スクリプトは以下をカバーする:

- 30日分の全Activity Log（不審なactorの有無）
- Type別Activity: `env-variable-read`, `env-variable`, `member`, `integration`（60〜90日）
- Webhook一覧
- Team members
- Marketplace Integration
- デプロイ履歴
- 最新ビルドログでのシークレット平文混入検査

実行: `bash ~/.claude/skills/vercel-incident-2026-april/scripts/investigate.sh`

### Phase 3: 環境変数のSensitive判定（opt-in）

CLI `env ls` は `Encrypted` 表記しか出ないため、Sensitive判定にはAPI直叩きが必要。ただしAPIレスポンスには暗号化された `value` フィールドが含まれるため、**実行前にユーザーに確認**する。

```bash
# PROJECT_ID と ORG_ID は .vercel/project.json から取得
vercel api "/v9/projects/$PROJECT_ID/env?teamId=$ORG_ID" \
  | jq -r '.envs[]? | "\(.type)\t\(.key)\t\(.target | join(","))"' \
  | sort
```

jqで `type`/`key`/`target` のみ抽出するが、生のAPIレスポンスは一時的にパイプを通過する。ユーザーが「本番環境変数を取得してもよい」と許可した場合のみ実行する。

判定基準:
- `type: "sensitive"` → **影響なし**（ローテ不要、ただし念のため検討）
- `type: "encrypted"` → **要ローテ** （publicなキーを除く）
- `type: "plain"` → **最優先ローテ**（平文保存）

判定不可でも、「全env varをローテして `--sensitive` で再登録する」方針なら実害はない。判定スキップも選択肢。

### Phase 4: 不審なactor検出

Activity LogのActorを集計し、以下に該当するものを列挙する:

- プロジェクトの正規メンバー（あなた自身・チームメンバー）/ `github-actions[bot]` / `actions-user` 以外のactor
- ユーザーに「知っているアクターか」確認（クライアントアカウント等の誤検知を避けるため）

### Phase 5: 所見レポート生成

**重要な前処理**: ローテ対象候補ごとに「実利用されているか」を確認する。未使用なら新キー発行せず**削除のみで対応完了**とする（攻撃面積削減）。

```bash
grep -r "KEY_NAME" src/ app/ pages/ api/ lib/ 2>/dev/null
```

grep 0件 + 発行元サービスで直近利用形跡なし → 「削除のみ」カテゴリに分類。

以下のフォーマットで出力:

```
## 調査結果サマリー

### ✅ クリーン項目
| 項目 | 結果 |
|------|------|
| Activity Log | {不審actor数}件 |
| Webhook | {件数} |
| Member変更 | {あり/なし} |
| Integration変更 | {あり/なし} |
| ビルドログ平文混入 | {検出/未検出} |

### 🗑 削除推奨（未使用env vars）
| 変数名 | 判定根拠 |
|-------|---------|
| ... | grep 0件 + 発行元でも未使用 |

### ⚠️ ローテ対象env vars
| 優先度 | 変数名 | type | target | 取り消し場所 |
|-------|-------|------|--------|------------|
| ...

### 🔴 要アクション
- [ ] {削除対象} を `vercel env rm` で削除
- [ ] {サービス側の取消} × N件
- [ ] Vercelで `--sensitive` 付きで再登録（Production+Previewのみ、devは別運用）
- [ ] `vercel redeploy <本番URL>` で再ビルド
- [ ] Google Workspace OAuthアプリ `110671459871-30f1spbu0hptbs60cb4vsmv79i7bbvqj` の除去確認
```

詳細なローテ手順は `references/rotation-checklist.md` を参照。罠回避は `references/gotchas.md` 参照。

### Phase 6: ローテ実行（ユーザー承認後）

**Phase 6はユーザーが明示的に指示した場合のみ実行する**。環境変数削除は破壊的操作のため、各環境変数ごとに承認を得る。

**実施前に必ず `references/gotchas.md` 参照**。特に以下3点は知らないと必ず詰まる:
- Sensitive変数は `development` ターゲットに設定不可
- 1エントリ兼任なら `vercel env rm` は**1回だけ**（3回叩くと "not found" エラー）
- OAuth AppはSecretのみ再生成。App自体を削除・再作成するとClient IDが変わって認証が壊れる

```bash
# 1. 旧値削除（1エントリ兼任なら1回で全消える）
vercel env rm <KEY> --yes

# 2. 新値を Sensitive type で登録（Production + Preview のみ選択）
vercel env add <KEY> --sensitive
# または値をパイプで渡す場合:
echo -n "<NEW_VALUE>" | vercel env add <KEY> production --sensitive
echo -n "<NEW_VALUE>" | vercel env add <KEY> preview --sensitive

# 3. 再デプロイ必須（env更新だけではビルド済み値が使われる）
vercel redeploy https://<production-domain>
```

原則:
- 新規登録時は **必ず `--sensitive` フラグ**（ただしDevelopmentターゲットは除外）
- ユーザーからの値受け渡しはインタラクティブプロンプトが最も安全
- **各ローテ後に必ず動作確認**してから旧キーを削除する（ロールバック可能な状態を維持）
- `vercel --prod` だけではカスタムドメインaliasが更新されないケースがある → `vercel redeploy <本番URL>` か `vercel promote` を使う

## プロジェクト別の注意点

引数で指定されたサブディレクトリ、または現在のcwdで実行する。プロジェクトごとに以下を確認:

- `.vercel/project.json` の `projectName` / `orgId`
- CMS連携（Sveltia/Decap等）があれば GitHub OAuth Client Secret のローテ優先度↑
- データベース（Supabase/Neon等）があれば該当APIキーをリストに追加

## なぜこの手順か

- **Phase 1を先にやる理由**: 古いCLIだと `activity` が無く、見落としが発生する
- **Phase 3でAPI直叩きする理由**: CLI `env ls` は `type` を表示しない。`sensitive`判定がインシデント対応の最重要項目のため
- **Phase 4で誤検知を防ぐ理由**: クライアント運用アカウント等の正規actorを「不審」と報告すると信頼を失う
- **Phase 6をopt-inにする理由**: `vercel env rm` は取り消し不可の破壊的操作

## references

- `references/incident-info.md` — インシデントの事実関係と公式リンク
- `references/rotation-checklist.md` — サービス別ローテ手順（GitHub OAuth, Resend, Google Cloud, reCAPTCHA, Supabase等）
- `references/gotchas.md` — 実戦で踏んだ罠のまとめ（Sensitive制約、rm挙動、OAuth App構造、再デプロイ必要性等）**ローテ前に必読**
