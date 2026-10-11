# shellcheck shell=bash
# Libreria comune per gli script amministrativi: log, errori, backup e rollback.
# Uso: source "$(dirname "$0")/../lib/common.sh"; BACKUP_DIR=...; backup_file /percorso

BACKUP_DIR=${BACKUP_DIR:-$(mktemp -d)}
declare -a _BACKED_UP=()

log() { printf '%s %s\n' "$(date -Is)" "$*" >&2; }
die() {
  log "ERRORE: $*"
  exit 1
}
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "comando mancante: $1"; }

backup_file() {
  local f=$1
  [[ -f $f ]] || return 0
  mkdir -p "$BACKUP_DIR$(dirname "$f")"
  cp -p -- "$f" "$BACKUP_DIR$f"
  _BACKED_UP+=("$f")
}

rollback_all() {
  local f
  for f in "${_BACKED_UP[@]}"; do
    cp -p -- "$BACKUP_DIR$f" "$f" && log "ripristinato $f"
  done
}

# Dopo backup_file: in caso di errore ripristina e termina.
enable_rollback_on_error() { trap 'rollback_all; die "interrotto, backup ripristinato"' ERR; }
