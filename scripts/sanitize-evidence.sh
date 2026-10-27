#!/usr/bin/env bash
# Usage: <command> | scripts/sanitize-evidence.sh > evidence/NN-name.txt
# Replaces machine-specific details (home directory, account name) with neutral
# placeholders before output is saved as evidence. Does not change anything else.
set -euo pipefail
owner=$(gh api user --jq .login 2>/dev/null || echo "__none__")
owner_lc=$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')
sed -E \
  -e "s#$HOME#~#g" \
  -e "s#/Users/[A-Za-z0-9._-]+#~#g" \
  -e "s#$owner#<repo-owner>#g" \
  -e "s#$owner_lc#<repo-owner>#g" \
  -e "s#$(id -un)#<user>#g"
