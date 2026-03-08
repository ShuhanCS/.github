#!/usr/bin/env bash
# Deploy the claude-simplify caller workflow to all active ShuhanCS repos.
# Usage: bash scripts/deploy-simplify-to-repos.sh [repo1 repo2 ...]
# No args = deploy to all repos updated since 2026-02-01.
set -euo pipefail

CALLER='.github/workflows/claude-simplify.yml'
read -r -d '' CALLER_CONTENT << 'YML' || true
name: Claude Code Simplifier

on:
  pull_request:
    types: [opened, synchronize]

permissions:
  contents: read
  pull-requests: write

jobs:
  simplify:
    uses: ShuhanCS/.github/.github/workflows/claude-simplify.yml@main
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
YML

if [ $# -gt 0 ]; then
  REPOS=("$@")
else
  mapfile -t REPOS < <(gh repo list ShuhanCS --limit 100 --json name,updatedAt \
    --jq '.[] | select(.updatedAt > "2026-02-01") | .name')
fi

for repo in "${REPOS[@]}"; do
  [ "$repo" = ".github" ] && continue
  echo "--- $repo ---"

  if gh api "repos/ShuhanCS/$repo/contents/$CALLER" --jq '.name' 2>/dev/null; then
    echo "  Already has claude-simplify.yml, skipping"
    continue
  fi

  ENCODED=$(printf '%s' "$CALLER_CONTENT" | base64 -w 0)
  gh api --method PUT "repos/ShuhanCS/$repo/contents/$CALLER" \
    -f message="ci: add Claude Code Simplifier workflow" \
    -f content="$ENCODED" \
    --silent 2>/dev/null && echo "  Deployed" || echo "  Failed (may need write access)"
done

echo ""
echo "Done. Make sure ANTHROPIC_API_KEY is set as an org secret:"
echo "  gh secret set ANTHROPIC_API_KEY --org ShuhanCS --visibility all"
