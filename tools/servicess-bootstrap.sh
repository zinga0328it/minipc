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

check_agent() {
  local name=$1
  if [[ -f $ROOT/.github/agents/$name.agent.md ]]; then
    echo "OK workspace agent $name"
  elif [[ -f $HOME/.copilot/agents/$name.agent.md ]]; then
    echo "OK user agent $name"
  else
    echo "MISSING agent $name (workspace or ~/.copilot/agents)"
    fail=1
  fi
}

ensure_codex_security() {
  command -v codex-security >/dev/null && return 0
  command -v npm >/dev/null && command -v node >/dev/null || {
    echo "MISSING npm/node: necessari per installare @openai/codex-security" >&2
    return 1
  }
  local version major minor
  version=$(node -p 'process.versions.node')
  IFS=. read -r major minor _ <<<"$version"
  case $major in
    22) ((minor >= 13)) || {
      echo "Node $version troppo vecchio; serve >=22.13" >&2
      return 1
    } ;;
    24 | 26) ;;
    *)
      echo "Node $version non supportato; usare Node 22.13+, 24.x o 26.x" >&2
      return 1
      ;;
  esac
  npm install --global --prefix "$HOME/.local" @openai/codex-security@0.2.0
  hash -r
  command -v codex-security >/dev/null || {
    echo "installazione codex-security non trovata in PATH" >&2
    return 1
  }
}

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
  if command -v codex >/dev/null; then
    codex_status=$(codex login status 2>&1 || true)
    if [[ $codex_status == "Logged in"* ]]; then echo "OK OpenAI Codex autenticato"; else echo "WARN Codex presente ma login ChatGPT non verificato; il cliente puo' autenticarsi con codex login"; fi
  else
    echo "MISSING OpenAI Codex CLI (codex)"
    fail=1
  fi
  if command -v codex-security >/dev/null; then
    security_status=$(codex-security login status 2>&1 || true)
    if [[ $security_status == "Logged in"* ]]; then echo "OK OpenAI Codex Security autenticato"; else echo "WARN Codex Security presente ma login ChatGPT non verificato; il cliente puo' autenticarsi con codex-security login"; fi
  else
    echo "MISSING OpenAI Codex Security CLI (codex-security)"
    fail=1
  fi
  if command -v copilot >/dev/null; then
    echo "OK GitHub Copilot CLI presente (login via copilot login se richiesto al primo uso)"
  else
    echo "MISSING GitHub Copilot CLI (copilot)"
    fail=1
  fi
  for name in servicess-orchestrator orchestratore-home orchestratore-etc orchestratore-var backend-project html-frontend static-deploy bash; do
    check_agent "$name"
  done
  for name in apache2 nftables fail2ban tor yggdrasil; do check_agent "$name"; done
  if command -v cargo >/dev/null; then echo "OK Rust $(rustc --version)"; else echo "INFO Rust toolchain missing; scaffold is ready, build unavailable"; fi
  if code --list-extensions 2>/dev/null | grep -qi '^github\.copilot'; then echo "OK Copilot extension found"; else echo "WARN Copilot extension not listed by CLI; verify Chat Agent Host in UI"; fi
  return "$fail"
}

open_workspace() {
  "$ROOT/tools/install-user-profile.sh"
  mkdir -p "$HOME/apps" "$HOME/web"
  ensure_codex_security
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
