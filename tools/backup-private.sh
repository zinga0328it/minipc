#!/usr/bin/env bash
# Crea backup cifrati age di app oppure dump PostgreSQL; non lascia plaintext persistente.
set -euo pipefail
umask 077

ROOT=${HOME:?}/apps
BACKUP_ROOT=${SERVICESS_BACKUP_ROOT:-$ROOT/.backups}
RECIPIENT=${SERVICESS_AGE_RECIPIENT:-}
usage() {
  echo "uso: $0 project <slug> | postgres <database>" >&2
  exit 2
}
[[ $# -eq 2 && ($1 == project || $1 == postgres) ]] || usage
[[ $RECIPIENT =~ ^age1[0-9a-z]{20,}$ ]] || {
  echo "SERVICESS_AGE_RECIPIENT age pubblica mancante/non valida" >&2
  exit 1
}
command -v age >/dev/null || {
  echo "installare age prima del backup" >&2
  exit 1
}
install -d -m 0700 "$BACKUP_ROOT"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
tmp=$(mktemp "$BACKUP_ROOT/.backup.XXXXXX.age")
trap 'rm -f "$tmp"' EXIT

case $1 in
  project)
    slug=$2
    [[ $slug =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || usage
    source=$ROOT/$slug
    [[ -d $source && ! -L $source ]] || {
      echo "progetto assente o symlink" >&2
      exit 1
    }
    tar --create --gzip --file=- --directory="$ROOT" --exclude="$slug/.git" "$slug" | age --encrypt --recipient "$RECIPIENT" --output "$tmp"
    output=$BACKUP_ROOT/$slug-$stamp.tar.gz.age
    ;;
  postgres)
    db=$2
    [[ $db =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]{0,62}$ ]] || usage
    command -v pg_dump >/dev/null || {
      echo "pg_dump mancante" >&2
      exit 1
    }
    [[ -n ${PGPASSFILE:-$HOME/.pgpass} && -r ${PGPASSFILE:-$HOME/.pgpass} ]] || {
      echo "PGPASSFILE/.pgpass leggibile richiesto; permessi 0600" >&2
      exit 1
    }
    pg_dump --format=custom --dbname="$db" | age --encrypt --recipient "$RECIPIENT" --output "$tmp"
    output=$BACKUP_ROOT/postgres-$db-$stamp.dump.age
    ;;
esac
chmod 0600 "$tmp"
mv -n -- "$tmp" "$output"
trap - EXIT
printf 'backup cifrato creato: %s\n' "$output"
