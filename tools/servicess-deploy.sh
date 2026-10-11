#!/usr/bin/env bash
# Frontend CLI: plan non privilegiato, operazioni live solo tramite sudo dispatcher dedicato.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PY=$ROOT/deployment/static-site/deploy.py
usage() {
  echo "uso: $0 plan <sito> | publish <sito> <manifest-sha256> | rollback <sito> <backup-id> | service <azione> <progetto>" >&2
  exit 2
}
[[ $# -ge 2 ]] || usage
op=$1
shift
case $op in
  plan)
    [[ $# == 1 ]] || usage
    exec python3 "$PY" "$1" --plan
    ;;
  publish)
    [[ $# == 2 ]] || usage
    exec sudo -n /usr/local/sbin/servicess-deploy publish "$1" "$2"
    ;;
  rollback)
    [[ $# == 2 ]] || usage
    exec sudo -n /usr/local/sbin/servicess-deploy rollback-site "$1" "$2"
    ;;
  service)
    [[ $# == 2 ]] || usage
    exec sudo -n /usr/local/sbin/servicess-deploy service manage "$1" "$2"
    ;;
  *) usage ;;
esac
