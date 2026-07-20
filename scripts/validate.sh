#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

printf '[validate] shell syntax\n'
while IFS= read -r script; do
  bash -n "$script"
done < <(find . -type f -name '*.sh' -not -path './.git/*' | sort)

printf '[validate] python syntax\n'
python3 - <<'PY'
from pathlib import Path
import py_compile

for path in sorted(Path('.').rglob('*.py')):
    if '.git' in path.parts:
        continue
    py_compile.compile(str(path), doraise=True)
PY

printf '[validate] done\n'
