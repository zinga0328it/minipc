#!/usr/bin/env bash
# Blocco IP su Cloudflare (IP Access Rules). Dry-run di default: serve --apply esplicito.
# Uso: cf-block.sh {block|unblock} <ip> [--apply]
# Credenziali in /etc/honeypot/cloudflare.env (CF_API_TOKEN, CF_ZONE_ID), mai nel repository.
set -euo pipefail

ENV_FILE=${HONEYPOT_CF_ENV:-/etc/honeypot/cloudflare.env}
ALLOWLIST=${HONEYPOT_ALLOWLIST:-/etc/honeypot/allowlist.txt}
API=https://api.cloudflare.com/client/v4

action=${1:-}; ip=${2:-}; apply=${3:-}
[[ $action == block || $action == unblock ]] && [[ -n $ip ]] || { sed -n '2,3p' "$0"; exit 2; }

# Rifiuta IP non validi, privati/loopback o in allowlist (mai bloccare se stessi).
python3 - "$ip" "$ALLOWLIST" <<'PY'
import ipaddress, sys
ip = ipaddress.ip_address(sys.argv[1])
if not ip.is_global:
    sys.exit(f"rifiutato: {ip} non e' un IP pubblico")
try:
    for line in open(sys.argv[2]):
        line = line.split('#')[0].strip()
        if line and ip in ipaddress.ip_network(line, strict=False):
            sys.exit(f"rifiutato: {ip} e' in allowlist")
except FileNotFoundError:
    pass
PY

if [[ $apply != --apply ]]; then
  echo "[dry-run] $action $ip su Cloudflare (aggiungi --apply per eseguire)"
  exit 0
fi

[[ -r $ENV_FILE ]] || { echo "manca $ENV_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"
: "${CF_API_TOKEN:?}" "${CF_ZONE_ID:?}"

# Il token passa da stdin a curl, non compare in ps.
cf() { printf 'header = "Authorization: Bearer %s"\n' "$CF_API_TOKEN" | curl -fsS -K - "$@"; }
rules="$API/zones/$CF_ZONE_ID/firewall/access_rules/rules"

if [[ $action == block ]]; then
  cf -X POST -H 'Content-Type: application/json' "$rules" \
    --data "{\"mode\":\"block\",\"configuration\":{\"target\":\"ip\",\"value\":\"$ip\"},\"notes\":\"honeypot $(date -Is)\"}" \
    | python3 -c 'import json,sys; print("ok" if json.load(sys.stdin)["success"] else "errore")'
else
  id=$(cf -G "$rules" --data-urlencode "configuration.value=$ip" \
    | python3 -c 'import json,sys; r=json.load(sys.stdin)["result"]; print(r[0]["id"] if r else "")')
  [[ -n $id ]] || { echo "nessuna regola per $ip"; exit 0; }
  cf -X DELETE "$rules/$id" >/dev/null && echo "rimosso $ip"
fi
