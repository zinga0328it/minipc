#!/usr/bin/env bash
# One-time reviewed installation. It never runs workspace code as root; sudo only executes fixed install/validation commands.
set -euo pipefail
umask 077
ROOT=$(cd "$(dirname "$0")/.." && pwd)
USER_NAME=$(id -un)
REVOKE_BROAD=0
[[ ${1:-} == --revoke-broad-sudo ]] && REVOKE_BROAD=1
[[ $# -le 1 ]] || {
  echo "uso: $0 [--revoke-broad-sudo]" >&2
  exit 2
}
[[ $USER_NAME =~ ^[a-z_][a-z0-9_-]*$ ]] || {
  echo "nome utente non supportato" >&2
  exit 1
}

for cmd in python3 git sudo visudo; do command -v "$cmd" >/dev/null || {
  echo "manca $cmd" >&2
  exit 1
}; done
python3 -m py_compile "$ROOT/deployment/static-site/deploy.py" "$ROOT/admin/servicess-admin.py"
python3 -m unittest discover -s "$ROOT/tests/deployment" -v
sudo -v
SUDO_LIST=$(sudo -n -l -U "$USER_NAME")
if grep -Eq 'NOPASSWD:[[:space:]]+ALL([[:space:]]|$)' <<<"$SUDO_LIST" && ((REVOKE_BROAD == 0)); then
  echo "rilevato NOPASSWD: ALL gia' attivo; per applicare il profilo ristretto serve --revoke-broad-sudo" >&2
  exit 1
fi

STAGED=$(mktemp)
trap 'rm -f "$STAGED"' EXIT
sed "s/{{SERVICE_USER}}/$USER_NAME/" "$ROOT/admin/sudoers/90-servicess-deploy" >"$STAGED"
sudo visudo -cf "$STAGED"
BACKUP=$(sudo mktemp -d /var/backups/servicess-installer.XXXXXX)
TARGETS=(
  /usr/local/sbin/servicess-deploy
  /usr/local/lib/servicess/admin.py
  /usr/local/lib/servicess/static-site/deploy.py
  /usr/local/lib/servicess/templates/rust-api.service.template
  /etc/sudoers.d/90-servicess-deploy
)
REVOKED=()

rollback() {
  local dest rel
  echo "installazione fallita: ripristino da $BACKUP" >&2
  for dest in "${TARGETS[@]}"; do
    rel=$BACKUP/files$dest
    if sudo test -f "$rel"; then sudo cp -a "$rel" "$dest"; else sudo rm -f "$dest"; fi
  done
  local f
  for f in "${REVOKED[@]}"; do
    if sudo test -e "$f.disabled" && ! sudo test -e "$f"; then sudo mv "$f.disabled" "$f"; fi
  done
  sudo visudo -c
}

for dest in "${TARGETS[@]}"; do
  if sudo test -f "$dest"; then sudo install -D -m 0600 "$dest" "$BACKUP/files$dest"; fi
done
for f in /etc/sudoers.d/ragno /etc/sudoers.d/90-ragno; do
  if ((REVOKE_BROAD)) && sudo test -f "$f"; then
    sudo install -D -m 0600 "$f" "$BACKUP/files$f"
    REVOKED+=("$f")
  fi
done

trap rollback ERR
sudo install -d -o root -g root -m 0755 /usr/local/lib/servicess/static-site /usr/local/lib/servicess/templates /usr/local/sbin
sudo install -o root -g root -m 0755 "$ROOT/admin/servicess-deploy" /usr/local/sbin/servicess-deploy
sudo install -o root -g root -m 0644 "$ROOT/admin/servicess-admin.py" /usr/local/lib/servicess/admin.py
sudo install -o root -g root -m 0644 "$ROOT/deployment/static-site/deploy.py" /usr/local/lib/servicess/static-site/deploy.py
sudo install -o root -g root -m 0644 "$ROOT/deployment/systemd/rust-api.service.template" /usr/local/lib/servicess/templates/rust-api.service.template
sudo install -o root -g root -m 0440 "$STAGED" /etc/sudoers.d/.90-servicess-deploy.tmp
sudo visudo -cf /etc/sudoers.d/.90-servicess-deploy.tmp
sudo mv -f /etc/sudoers.d/.90-servicess-deploy.tmp /etc/sudoers.d/90-servicess-deploy
for f in "${REVOKED[@]}"; do sudo mv "$f" "$f.disabled"; done
sudo visudo -c
sudo -n -l -U "$USER_NAME" | grep -F '/usr/local/sbin/servicess-deploy'
if grep -Eq 'NOPASSWD:[[:space:]]+ALL([[:space:]]|$)' < <(sudo -n -l -U "$USER_NAME"); then
  echo "NOPASSWD: ALL ancora attivo: controllo autorizzazioni fallito" >&2
  false
fi
trap - ERR
echo "OK installato; backup: $BACKUP"
echo "Nessun servizio e' stato avviato e nessun sito pubblicato."
