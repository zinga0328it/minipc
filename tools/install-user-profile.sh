#!/usr/bin/env bash
# Installa istruzioni e agenti Servicess.net nel profilo Agent Host, con backup delle versioni precedenti.
set -euo pipefail
umask 077
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST=${COPILOT_HOME:-$HOME/.copilot}
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP=$DEST/backups/servicess-$STAMP
AGENTS=(servicess-orchestrator orchestratore-home orchestratore-etc orchestratore-var backend-project html-frontend static-deploy bash)

[[ -d $DEST || ! -e $DEST ]] || {
  echo "profilo non e' una directory: $DEST" >&2
  exit 1
}
install -d -m 0700 "$DEST/agents"
changed=0
backup_existing() {
  local source=$1 target=$2
  if [[ -e $target ]] && ! cmp -s "$source" "$target"; then
    install -D -m 0600 "$target" "$BACKUP${target#"$DEST"}"
    changed=1
  fi
}

for name in "${AGENTS[@]}"; do
  src=$ROOT/.github/agents/$name.agent.md
  [[ -f $src ]] || {
    echo "agente sorgente mancante: $src" >&2
    exit 1
  }
  target=$DEST/agents/$name.agent.md
  backup_existing "$src" "$target"
  install -m 0600 "$src" "$target"
done

src=$ROOT/templates/copilot/copilot-instructions.md
target=$DEST/copilot-instructions.md
backup_existing "$src" "$target"
install -m 0600 "$src" "$target"

src=$ROOT/templates/home/AGENTS.md
target=$HOME/AGENTS.md
if [[ -e $target ]] && ! cmp -s "$src" "$target"; then
  install -D -m 0600 "$target" "$BACKUP/home/AGENTS.md"
  changed=1
fi
install -m 0644 "$src" "$target"

if ((changed)); then echo "Backup delle versioni sostituite: $BACKUP"; fi
echo "OK istruzioni e ${#AGENTS[@]} agenti installati in $DEST"
