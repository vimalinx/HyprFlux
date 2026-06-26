#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "Checking shell syntax..."
while IFS= read -r file; do
  echo "  bash -n $file"
  bash -n "$file"
done < <(find modules scripts -type f \( -name '*.sh' -o -name 'safe-mic-set-default' \) | sort)

echo "Checking required module docs..."
while IFS= read -r module_dir; do
  if [ ! -f "$module_dir/README.md" ]; then
    echo "Missing README.md in $module_dir" >&2
    exit 1
  fi
done < <(find modules -mindepth 1 -maxdepth 1 -type d | sort)

echo "Scanning for credential-shaped patterns..."
pattern='(OPENAI_API_KEY|ZAI_API_KEY|BRAVE_SEARCH_API_KEY|FEISHU_APP_SECRET|AWS_SECRET_ACCESS_KEY|ghp_[A-Za-z0-9_]+|gho_[A-Za-z0-9_]+|glpat-[A-Za-z0-9_-]+|sk-[A-Za-z0-9]{20,})'
if rg -n --hidden --glob '!.git/**' --glob '!scripts/check.sh' --pcre2 "$pattern" .; then
  echo "Credential-shaped pattern found; inspect before publishing." >&2
  exit 1
fi

echo "OK"
