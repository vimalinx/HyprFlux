#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "Checking shell syntax..."
while IFS= read -r file; do
  echo "  bash -n $file"
  bash -n "$file"
done < <(
  {
    find modules scripts session -type f
    printf '%s\n' install.sh
  } | sort -u | while IFS= read -r candidate; do
    [[ -f "$candidate" ]] || continue
    if head -n 1 "$candidate" | grep -Eq '^#!.*\b(bash|sh)\b'; then
      printf '%s\n' "$candidate"
    fi
  done
)

echo "Checking required module docs..."
while IFS= read -r module_dir; do
  if [ ! -f "$module_dir/README.md" ]; then
    echo "Missing README.md in $module_dir" >&2
    exit 1
  fi
done < <(find modules -mindepth 1 -maxdepth 1 -type d | sort)

echo "Checking profiles..."
for f in profiles/common.modules profiles/asus.modules profiles/generic.modules; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done

echo "Scanning for credential-shaped patterns..."
pattern='(OPENAI_API_KEY|ZAI_API_KEY|BRAVE_SEARCH_API_KEY|FEISHU_APP_SECRET|AWS_SECRET_ACCESS_KEY|ghp_[A-Za-z0-9_]+|gho_[A-Za-z0-9_]+|glpat-[A-Za-z0-9_-]+|sk-[A-Za-z0-9]{20,})'
if rg -n --hidden --glob '!.git/**' --glob '!.ai/**' --glob '!scripts/check.sh' --pcre2 "$pattern" .; then
  echo "Credential-shaped pattern found; inspect before publishing." >&2
  exit 1
fi

echo "Scanning for absolute /home/<user> paths..."
if rg -n --glob '!.git/**' --glob '!.ai/**' --glob '!docs/**' --glob '!README.md' \
  --pcre2 '/home/(?!YOU\b|USER\b|username\b|\$)[A-Za-z0-9._-]+' \
  modules scripts session install.sh profiles; then
  echo "Absolute /home path found; sanitize before publishing." >&2
  exit 1
fi

echo "OK"
