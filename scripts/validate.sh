#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

tracked_files() {
  git ls-files "$@"
}

printf '[validate] shell syntax\n'
while IFS= read -r script; do
  [ -n "$script" ] || continue
  bash -n "$script"
done < <(tracked_files '*.sh' | sort)

printf '[validate] python syntax\n'
python3 - <<'PY'
import py_compile
import subprocess

files = subprocess.check_output(
    ["git", "ls-files", "*.py"],
    text=True,
).splitlines()
for path in sorted(files):
    py_compile.compile(path, doraise=True)
PY

printf '[validate] done\n'
