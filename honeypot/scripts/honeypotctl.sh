#!/usr/bin/env bash
# Installazione del modulo honeypot con backup e rollback.
# Uso: honeypotctl.sh plan | apply | rollback     (plan e' il default, non modifica nulla)
set -euo pipefail

SRC=$(cd "$(dirname "$0")/.." && pwd)
BACKUPS=/var/backups/honeypot
VHOST=/etc/apache2/sites-available/test-tunnel.conf
INC=/etc/apache2/honeypot/honeypot-vhost.inc
INCLINE="    Include $INC"

# sorgente -> destinazione
FILES=(
  "$SRC/apache2/honeypot-vhost.inc|$INC"
  "$SRC/fail2ban/filter.d/honeypot.conf|/etc/fail2ban/filter.d/honeypot.conf"
  "$SRC/fail2ban/action.d/honeypot-log.conf|/etc/fail2ban/action.d/honeypot-log.conf"
  "$SRC/fail2ban/jail.d/honeypot.local|/etc/fail2ban/jail.d/honeypot.local"
)

plan() {
  echo "Il comando apply eseguirebbe:"
  echo "  - backup in $BACKUPS/<data> (file toccati + manifest)"
  for f in "${FILES[@]}"; do echo "  - installa ${f#*|}"; done
  echo "  - a2enmod remoteip (se non attivo)"
  echo "  - aggiunge in $VHOST, prima di </VirtualHost>: $INCLINE"
  echo "  - apache2ctl configtest e fail2ban-client -t; in caso di errore rollback automatico"
  echo "  - reload apache2 e fail2ban (il jail resta enabled = false)"
  echo "Nessuna modifica a nftables/core.conf."
}

latest() { ls -1d "$BACKUPS"/*/ 2>/dev/null | tail -1; }

rollback() {
  local dir=${1:-$(latest)}
  [[ -n $dir && -f $dir/manifest ]] || { echo "nessun backup" >&2; exit 1; }
  while read -r kind path; do
    case $kind in
      backup)  cp -a "$dir/files/$path" "$path" ;;
      created) rm -f "$path" ;;
      module)  a2dismod -q "$path" ;;
    esac
  done < "$dir/manifest"
  systemctl reload apache2 || true
  fail2ban-client reload || true
  echo "ripristinato da $dir"
}

apply() {
  [[ $EUID -eq 0 ]] || { echo "serve root" >&2; exit 1; }
  local dir="$BACKUPS/$(date +%Y%m%d-%H%M%S)"
  install -d -m 0700 "$dir/files"; : > "$dir/manifest"

  save() { # registra lo stato precedente di un file
    if [[ -e $1 ]]; then
      install -D -m 0600 "$1" "$dir/files$1"; echo "backup $1" >> "$dir/manifest"
    else
      echo "created $1" >> "$dir/manifest"
    fi
  }

  for f in "${FILES[@]}"; do
    save "${f#*|}"; install -D -m 0644 "${f%%|*}" "${f#*|}"
  done
  save "$VHOST"
  grep -qF "$INC" "$VHOST" || sed -i "s|^</VirtualHost>|$INCLINE\n</VirtualHost>|" "$VHOST"
  if ! apache2ctl -M 2>/dev/null | grep -q remoteip_module; then
    a2enmod -q remoteip; echo "module remoteip" >> "$dir/manifest"
  fi

  if apache2ctl configtest && fail2ban-client -t; then
    systemctl reload apache2 && fail2ban-client reload
    echo "applicato. Backup: $dir (rollback: $0 rollback)"
  else
    echo "validazione fallita: rollback" >&2
    rollback "$dir"; exit 1
  fi
}

case ${1:-plan} in
  plan) plan ;;
  apply) apply ;;
  rollback) rollback ;;
  *) sed -n '2,3p' "$0"; exit 2 ;;
esac
