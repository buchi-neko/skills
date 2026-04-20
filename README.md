# skills

Claude Code 用の Skill 集。

## 収録 Skill

### [vercel-incident-2026-april](./vercel-incident-2026-april)

2026年4月の [Vercel セキュリティインシデント](https://vercel.com/kb/bulletin/vercel-april-2026-security-incident)に対応するための調査・ローテーション支援 Skill。

- Activity Log / Webhook / 環境変数 / Integration の監査
- 不審な actor の検出
- 環境変数の `sensitive` 判定（API 直叩き）
- サービス別のローテ手順（GitHub OAuth, Resend, Google Cloud, reCAPTCHA, Supabase, Stripe 等）
- 実戦で踏んだ罠のまとめ（`references/gotchas.md`）

本リポジトリの Skill は [Agent Skills 仕様](https://agentskills.io/specification) に準拠しています。

## インストール

### `gh skill` 経由（推奨）

[GitHub CLI `gh skill` コマンド](https://github.blog/changelog/2026-04-16-manage-agent-skills-with-github-cli/)を使うと、バージョン固定・供給チェーン整合性チェック付きでインストールできます。

```bash
gh skill install buchi-neko/skills vercel-incident-2026-april
```

### 手動（Claude Code）

```bash
# ~/.claude/skills/ 配下にコピー
git clone https://github.com/buchi-neko/skills.git /tmp/skills
cp -R /tmp/skills/vercel-incident-2026-april ~/.claude/skills/
```

## 使い方

Claude Code で対象プロジェクトのディレクトリに移動してから、Skill を呼び出す:

```
/vercel-incident-2026-april
```

または自然言語でトリガー（`description` に基づいて自動選択される）:

> Vercel の 2026年4月インシデントの影響をこのプロジェクトで調査して

## 動作要件

- Claude Code
- Vercel CLI `>= 51.0.0`（`activity` / `webhooks` コマンド必須）
- `jq`（JSON パース用）

## ライセンス

[MIT](./LICENSE)

## 免責

このSkillは一般的なインシデント対応手順を提供するものであり、個別プロジェクトのセキュリティを保証するものではありません。自組織のセキュリティポリシーに従って利用してください。
