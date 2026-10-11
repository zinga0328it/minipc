#!/usr/bin/env bash
# Controlla il profilo e apre il workspace Servicess.net supportato da VS Code.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ACTION=${1:-check}
WORKSPACE=${SERVICESS_WORKSPACE:-$HOME/servicess.code-workspace}

fail=0
check_file() { [[ -f $1 ]] && echo "OK $1" || {
  echo "MISSING $1"
  fail=1
}; }

check() {
  for tool in bash python3 git code; do
    command -v "$tool" >/dev/null && echo "OK tool $tool" || {
      echo "MISSING tool $tool"
      fail=1
    }
  done
  [[ -d $HOME/apps && ! -L $HOME/apps ]] && echo "OK $HOME/apps" || {
    echo "MISSING/unsafe $HOME/apps"
    fail=1
  }
  [[ -d $HOME/web && ! -L $HOME/web ]] && echo "OK $HOME/web" || {
    echo "MISSING/unsafe $HOME/web"
    fail=1
  }
  check_file "$HOME/.copilot/copilot-instructions.md"
  check_file "$HOME/.copilot/agents/servicess-orchestrator.agent.md"
  for name in servicess-orchestrator orchestratore-home orchestratore-etc orchestratore-var backend-project html-frontend static-deploy bash; do
    check_file "$ROOT/.github/agents/$name.agent.md"
    check_file "$HOME/.copilot/agents/$name.agent.md"
  done
  for name in apache2 nftables fail2ban tor yggdrasil; do check_file "$ROOT/.github/agents/$name.agent.md"; done
  if command -v cargo >/dev/null; then echo "OK Rust $(rustc --version)"; else echo "INFO Rust toolchain missing; scaffold is ready, build unavailable"; fi
  if code --list-extensions 2>/dev/null | grep -qi '^github\.copilot'; then echo "OK Copilot extension found"; else echo "WARN Copilot extension not listed by CLI; verify Chat Agent Host in UI"; fi
  return "$fail"
}

open_workspace() {
  "$ROOT/tools/install-user-profile.sh"
  mkdir -p "$HOME/apps" "$HOME/web"
  python3 - "$ROOT" "$WORKSPACE" "$HOME" <<'PY'
import json, os, pathlib, sys, tempfile
root, output, home = map(pathlib.Path, sys.argv[1:])
folders = [
    ("Servicess.net", root),
    ("Gestionali privati", home / "apps"),
    ("Siti sorgente", home / "web"),
    ("ETC", pathlib.Path("/etc")),
    ("VAR - pubblicazione", pathlib.Path("/var/www")),
]
data = {"folders": [{"name": name, "path": str(path)} for name, path in folders if path.exists()]}
output.parent.mkdir(parents=True, exist_ok=True)
fd, temp = tempfile.mkstemp(prefix=".servicess-", suffix=".code-workspace", dir=output.parent)
with os.fdopen(fd, "w", encoding="utf-8") as stream:
    json.dump(data, stream, indent=2)
    stream.write("\n")
os.replace(temp, output)
PY
  check
  "$ROOT/tools/yggdrasil-onboarding.sh" || true
  code --reuse-window "$WORKSPACE"
  echo "Workspace aperto: $WORKSPACE"
  echo "Per iniziare: seleziona l'agente servicess-orchestrator nel picker Agent. Il CLI apre il workspace, ma non può selezionare né inviare una chat."
}

case $ACTION in
  check) check ;;
  open) open_workspace ;;
  *)
    echo "Uso: $0 {check|open}" >&2
    exit 2
    ;;
esac
