#!/usr/bin/env bash
# Installazione una tantum del sistema di deployment privilegiato.
# Uso: sudo bash admin/bootstrap.sh [--revoke-nopasswd-all]
# Con backup e rollback automatico se un passo fallisce.
set -euo pipefail

[[ $EUID -eq 0 ]] || {
  echo "serve root: sudo bash $0" >&2
  exit 1
}
SRC=$(cd "$(dirname "$0")" && pwd)
OWNER=${SUDO_USER:?eseguire con sudo}
BK=/var/backups/etc-deploy-bootstrap/$(date +%Y%m%d-%H%M%S)
BIN=/usr/local/sbin/etc-deploy
SUDOERS=/etc/sudoers.d/90-etc-deploy
revoke=0
[[ ${1:-} == --revoke-nopasswd-all ]] && revoke=1

install -d -m 0700 "$BK"
log() { printf '[bootstrap] %s\n' "$*"; }

rollback() {
  log "ERRORE: ripristino"
  for f in "$BIN" "$SUDOERS"; do
    if [[ -f $BK/$(basename "$f") ]]; then install -m "$(stat -c %a "$BK/$(basename "$f")")" "$BK/$(basename "$f")" "$f"; else rm -f "$f"; fi
  done
  if [[ -f $BK/nftables.owner ]]; then
    chown -R "$(cat "$BK/nftables.owner")" /etc/nftables
    while read -r mode path; do chmod "$mode" "$path"; done <"$BK/nftables.modes"
  fi
  if [[ -f $BK/disabled.list ]]; then
    while read -r f; do mv "$f.disabled" "$f"; done <"$BK/disabled.list"
  fi
  visudo -c >/dev/null || log "ATTENZIONE: controllare sudoers manualmente"
  exit 1
}
trap rollback ERR

log "1/6 strumenti Bash (shellcheck, shfmt, bats)"
DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y shellcheck shfmt bats </dev/null >/dev/null

log "2/6 backup in $BK"
for f in "$BIN" "$SUDOERS"; do [[ -f $f ]] && cp -p "$f" "$BK/" || true; done
stat -c %U:%G /etc/nftables >"$BK/nftables.owner"
find /etc/nftables -exec stat -c '%a %n' {} + >"$BK/nftables.modes"

log "3/6 validazione sudoers"
visudo -cf "$SRC/sudoers/90-etc-deploy" >/dev/null

log "4/6 installazione script e sudoers (root:root)"
install -m 0755 -o root -g root "$SRC/etc-deploy" "$BIN"
install -m 0440 -o root -g root "$SRC/sudoers/90-etc-deploy" "$SUDOERS"
visudo -c >/dev/null

log "5/6 /etc/nftables torna a root (scrittura solo via etc-deploy)"
chown -R root:root /etc/nftables
find /etc/nftables -type d -exec chmod 0755 {} +
find /etc/nftables -type f -exec chmod 0644 {} +

if ((revoke)); then
  log "revoca NOPASSWD: ALL (file rinominati *.disabled, reversibile)"
  for f in /etc/sudoers.d/ragno /etc/sudoers.d/90-ragno; do
    [[ -f $f ]] && mv "$f" "$f.disabled" && echo "$f" >>"$BK/disabled.list"
  done
  visudo -c >/dev/null
fi

log "6/6 prova: sudo -n come $OWNER"
sudo -u "$OWNER" sudo -n "$BIN" list >/dev/null
trap - ERR
log "OK. Backup: $BK"
