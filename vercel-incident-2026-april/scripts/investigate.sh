#!/usr/bin/env bash
# Vercel April 2026 Security Incident — read-only investigation
# Usage: bash investigate.sh [project_dir]
#
# Reads .vercel/project.json for orgId/projectId and runs audit queries.
# Output is structured for easy parsing by the orchestrating skill.

set -u

PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR" || { echo "ERROR: cannot cd to $PROJECT_DIR"; exit 1; }

if [[ ! -f .vercel/project.json ]]; then
  echo "ERROR: .vercel/project.json not found. Run 'vercel link' first."
  exit 1
fi

ORG_ID=$(jq -r '.orgId' .vercel/project.json)
PROJECT_ID=$(jq -r '.projectId' .vercel/project.json)
PROJECT_NAME=$(jq -r '.projectName' .vercel/project.json)

echo "=================================================="
echo "Vercel Incident Investigation: $PROJECT_NAME"
echo "orgId: $ORG_ID"
echo "projectId: $PROJECT_ID"
echo "=================================================="

cli_version=$(vercel --version 2>/dev/null | tail -1)
echo ""
echo "### CLI Version"
echo "$cli_version"
major=$(echo "$cli_version" | cut -d. -f1)
if [[ "$major" -lt 51 ]]; then
  echo "WARN: CLI < 51. Upgrade required for activity/webhooks commands."
  echo "Run: npm i -g vercel@latest"
  exit 2
fi

echo ""
echo "### Logged-in user"
vercel whoami 2>&1 | tail -1

echo ""
echo "### Activity: all types (last 30d)"
echo "--- Scan for unfamiliar actors ---"
vercel activity ls --since 30d 2>&1 | grep -E "^\s+Actor\s+" | sort -u

echo ""
echo "### Activity: env-variable-read (last 60d)"
vercel activity ls --type env-variable-read --since 60d 2>&1 | tail -20

echo ""
echo "### Activity: env-variable mutations (last 60d)"
vercel activity ls --type env-variable --since 60d 2>&1 | tail -20

echo ""
echo "### Activity: member changes (last 90d)"
vercel activity ls --type member --since 90d 2>&1 | tail -20

echo ""
echo "### Activity: integration changes (last 90d)"
vercel activity ls --type integration --since 90d 2>&1 | tail -20

echo ""
echo "### Webhooks"
vercel webhooks list 2>&1

echo ""
echo "### Marketplace Integrations"
vercel integration list 2>&1 | tail -10

echo ""
echo "### Env vars (key/target only — run type check manually, see below)"
vercel env ls 2>&1 | tail -30

echo ""
echo "### Recent deployments (last 10)"
vercel ls 2>&1 | head -15

echo ""
echo "### Build log secret-leak check (most recent prod deployment)"
latest=$(vercel ls 2>&1 | grep -E "Production" | head -1 | awk '{for(i=1;i<=NF;i++) if($i ~ /^https:/) print $i}')
if [[ -n "$latest" ]]; then
  echo "Checking: $latest"
  vercel inspect "$latest" --logs 2>&1 \
    | grep -iE "(api[_-]?key|secret|token|password|bearer)=\S{10,}" \
    | head -5 \
    || echo "No obvious plaintext secrets found in build log."
else
  echo "No recent production deployment found."
fi

echo ""
echo "=================================================="
echo "Investigation complete."
echo ""
echo "### Next: run env type check manually (pulls encrypted values into session)"
echo ""
echo "vercel api \"/v9/projects/$PROJECT_ID/env?teamId=$ORG_ID\" \\"
echo "  | jq -r '.envs[]? | \"\\(.type)\\t\\(.key)\\t\\(.target | join(\",\"))\"' \\"
echo "  | sort"
echo ""
echo "Then generate rotation plan per references/rotation-checklist.md"
echo "=================================================="
