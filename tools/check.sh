#!/usr/bin/env bash
# Controlli standard per tutti gli script: bash -n, ShellCheck, shfmt, Bats.
# Uso: tools/check.sh [--fix]   (--fix applica shfmt)
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
PATH=$PATH:${CHECK_EXTRA_PATH:-}
fail=0
ok() { echo "OK   $*"; }
bad() {
  echo "FAIL $*"
  fail=1
}

for t in shellcheck shfmt bats; do command -v "$t" >/dev/null || {
  bad "manca $t (vedi admin/bootstrap.sh per i pacchetti Debian)"
  exit 1
}; done

mapfile -t files < <(find . -type f \( -name '*.sh' -o -path './admin/etc-deploy' -o -path './admin/servicess-deploy' \) -not -path './.git/*' | sort)
for f in "${files[@]}"; do bash -n "$f" && ok "bash -n $f" || bad "bash -n $f"; done
shellcheck "${files[@]}" && ok "shellcheck (${#files[@]} file)" || bad "shellcheck"
if [[ ${1:-} == --fix ]]; then shfmt -w "${files[@]}" && ok "shfmt applicato"; else
  shfmt -d "${files[@]}" >/dev/null && ok "shfmt" || {
    bad "shfmt (usa --fix)"
    shfmt -d "${files[@]}" | head -20
  }
fi
bats tests/bash && ok "bats" || bad "bats"
if [[ -d tests/deployment ]]; then
  python3 -m unittest discover -s tests/deployment && ok "deployment unit tests" || bad "deployment unit tests"
else
  echo "INFO nessun test deployment in questo ramo"
fi
exit "$fail"
