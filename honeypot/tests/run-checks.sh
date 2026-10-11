#!/usr/bin/env bash
# Verifiche non distruttive: Apache viene avviato in una sandbox su porte alte, /etc non viene toccato.
# Uso: tests/run-checks.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
fail=0
ok() { echo "OK   $*"; }
bad() {
  echo "FAIL $*"
  fail=1
}

for s in "$ROOT"/scripts/*.sh "$0"; do bash -n "$s" && ok "sintassi $(basename "$s")" || bad "sintassi $s"; done

out=$(fail2ban-regex "$ROOT/tests/sample-honeypot.log" "$ROOT/fail2ban/filter.d/honeypot.conf" 2>&1)
echo "$out" | grep -q 'Lines: 5 lines, 0 ignored, 4 matched, 1 missed' &&
  ok "filtro fail2ban: 4 match (IPv4+IPv6), log combined ignorato" || {
  bad "filtro fail2ban"
  echo "$out" | tail -8
}

tmp=$(mktemp -d)
cleanup() {
  [[ -f $tmp/pid ]] && kill "$(cat "$tmp/pid")" 2>/dev/null
  rm -rf "$tmp"
}
trap cleanup EXIT
M=/usr/lib/apache2/modules
mkdir -p "$tmp/tunnel" "$tmp/onion"
echo legit-tunnel >"$tmp/tunnel/index.html"
echo legit-onion >"$tmp/onion/index.html"
cat >"$tmp/apache.conf" <<EOF
ServerRoot "$tmp"
PidFile "$tmp/pid"
ErrorLog "$tmp/error.log"
Define APACHE_LOG_DIR $tmp
ServerName localhost
Listen 127.0.0.1:18080
Listen 127.0.0.1:18081
LoadModule mpm_event_module $M/mod_mpm_event.so
LoadModule authz_core_module $M/mod_authz_core.so
LoadModule setenvif_module $M/mod_setenvif.so
LoadModule remoteip_module $M/mod_remoteip.so
LoadModule dir_module $M/mod_dir.so
<VirtualHost 127.0.0.1:18080>
    DocumentRoot "$tmp/tunnel"
    Include $ROOT/apache2/honeypot-vhost.inc
</VirtualHost>
<VirtualHost 127.0.0.1:18081>
    DocumentRoot "$tmp/onion"
    Include $ROOT/apache2/honeypot-onion.inc
</VirtualHost>
EOF
if apache2 -t -f "$tmp/apache.conf" 2>&1 | grep -q 'Syntax OK'; then ok "apache2 configtest (sandbox, due vhost)"; else
  bad "apache2 configtest"
  apache2 -t -f "$tmp/apache.conf" 2>&1 | tail -5
fi

if apache2 -f "$tmp/apache.conf" -k start 2>"$tmp/start.err"; then
  sleep 1
  code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
  [[ $(code http://127.0.0.1:18080/) == 200 && $(code http://127.0.0.1:18081/) == 200 ]] && ok "siti legittimi: 200 su tunnel e onion" || bad "siti legittimi"
  code -H 'CF-Connecting-IP: 203.0.113.7' http://127.0.0.1:18080/.env >/dev/null
  code -H 'CF-Connecting-IP: 203.0.113.7' http://127.0.0.1:18080/wp-login.php >/dev/null
  code -H 'CF-Connecting-IP: 203.0.113.7' http://127.0.0.1:18081/.env >/dev/null
  code -H 'CF-Connecting-IP: 203.0.113.7' http://127.0.0.1:18081/xmlrpc.php >/dev/null
  sleep 1
  [[ $(grep -c '^203.0.113.7 ' "$tmp/honeypot.log") == 2 ]] && ok "tunnel: IP reale da CF-Connecting-IP nel log (2 hit)" || {
    bad "tunnel log"
    cat "$tmp/honeypot.log"
  }
  [[ $(wc -l <"$tmp/honeypot.log") == 2 ]] && ok "tunnel: richieste legittime e onion fuori dal log honeypot" || bad "tunnel: log non separato"
  [[ $(wc -l <"$tmp/honeypot-onion.log") == 2 ]] && ! grep -Eq '127\.0\.0\.1|203\.0\.113\.7' "$tmp/honeypot-onion.log" && ok "onion: 2 hit, nessun IP registrato (header Cloudflare ignorato)" || {
    bad "onion log"
    cat "$tmp/honeypot-onion.log"
  }
  fail2ban-regex "$tmp/honeypot.log" "$ROOT/fail2ban/filter.d/honeypot.conf" 2>&1 | grep -q 'Lines: 2 lines, 0 ignored, 2 matched' && ok "fail2ban riconosce il log reale di Apache" || bad "fail2ban su log reale"
  [[ $(code -X POST --data-binary "$(head -c 20000 /dev/zero | tr '\0' a)" http://127.0.0.1:18081/) == 413 ]] && ok "onion: body oltre il limite respinto (413)" || bad "onion: LimitRequestBody"
else
  bad "avvio apache sandbox"
  cat "$tmp/start.err"
fi

"$ROOT/scripts/cf-block.sh" block 9.9.9.9 | grep -q dry-run && ok "cf-block dry-run" || bad "cf-block dry-run"
[[ $("$ROOT/scripts/cf-block.sh" block 192.168.1.5 2>&1) == *rifiutato* ]] && ok "cf-block rifiuta IP privati" || bad "cf-block IP privati"
"$ROOT/scripts/honeypotctl.sh" plan | grep -q 'Nessuna modifica a nftables' && ok "honeypotctl plan" || bad "honeypotctl plan"

grep -rEIl --exclude=run-checks.sh '(CF_API_TOKEN=[A-Za-z0-9_-]{20,}|BEGIN (RSA |EC )?PRIVATE KEY|"AccountTag")' "$ROOT" >/dev/null && bad "possibili segreti nel repository" || ok "nessun segreto nel repository"

exit $fail
