#!/usr/bin/env bash
# Verifiche senza root e senza toccare /etc. Uso: tests/run-checks.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
fail=0
ok()  { echo "OK   $*"; }
bad() { echo "FAIL $*"; fail=1; }

for s in "$ROOT"/scripts/*.sh "$0"; do bash -n "$s" && ok "sintassi $(basename "$s")" || bad "sintassi $s"; done

out=$(fail2ban-regex "$ROOT/tests/sample-honeypot.log" "$ROOT/fail2ban/filter.d/honeypot.conf" 2>&1)
echo "$out" | grep -q 'Lines: 5 lines, 0 ignored, 4 matched, 1 missed' \
  && ok "filtro fail2ban: 4 match (IPv4+IPv6), log combined ignorato" || { bad "filtro fail2ban"; echo "$out" | tail -8; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
M=/usr/lib/apache2/modules
cat > "$tmp/apache.conf" <<EOF
ServerRoot "$tmp"
PidFile "$tmp/pid"
ErrorLog "$tmp/error.log"
Define APACHE_LOG_DIR $tmp
ServerName localhost
Listen 127.0.0.1:18080
LoadModule mpm_event_module $M/mod_mpm_event.so
LoadModule authz_core_module $M/mod_authz_core.so
LoadModule setenvif_module $M/mod_setenvif.so
LoadModule remoteip_module $M/mod_remoteip.so
<VirtualHost 127.0.0.1:18080>
    DocumentRoot "$tmp"
    Include $ROOT/apache2/honeypot-vhost.inc
</VirtualHost>
EOF
apache2 -t -f "$tmp/apache.conf" 2>&1 | grep -q 'Syntax OK' && ok "apache2 configtest (sandbox)" || { bad "apache2 configtest"; apache2 -t -f "$tmp/apache.conf" 2>&1 | tail -5; }

"$ROOT/scripts/cf-block.sh" block 9.9.9.9 | grep -q dry-run && ok "cf-block dry-run" || bad "cf-block dry-run"
[[ $("$ROOT/scripts/cf-block.sh" block 192.168.1.5 2>&1) == *rifiutato* ]] && ok "cf-block rifiuta IP privati" || bad "cf-block IP privati"
"$ROOT/scripts/honeypotctl.sh" plan | grep -q 'Nessuna modifica a nftables' && ok "honeypotctl plan" || bad "honeypotctl plan"

grep -rEIl --exclude=run-checks.sh '(CF_API_TOKEN=[A-Za-z0-9_-]{20,}|BEGIN (RSA |EC )?PRIVATE KEY|"AccountTag")' "$ROOT" >/dev/null && bad "possibili segreti nel repository" || ok "nessun segreto nel repository"

exit $fail
