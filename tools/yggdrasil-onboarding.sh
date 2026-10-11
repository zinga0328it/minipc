#!/usr/bin/env bash
# Mostra solo identita' pubblica del nodo; non legge la configurazione Yggdrasil.
set -euo pipefail

fail() {
  echo "Yggdrasil non verificabile: $*" >&2
  exit 1
}

systemctl is-active --quiet yggdrasil || fail "servizio non attivo"
identity=$(sudo -n yggdrasilctl getSelf 2>/dev/null) || fail "getSelf non accessibile senza prompt"

field() {
  local label=$1
  awk -v label="$label" '
    index($0, label) {
      value = substr($0, index($0, label) + length(label))
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (value == "") {
        if (getline value <= 0) exit
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      }
      print value
      exit
    }
  ' <<<"$identity"
}

public_key=$(field 'Public key:')
ipv6=$(field 'IPv6 address:')
[[ $public_key =~ ^[[:xdigit:]]{64}$ ]] || fail "chiave pubblica assente o malformata"
[[ $ipv6 =~ ^[[:xdigit:]:]+$ && $ipv6 == *:* ]] || fail "IPv6 assente o malformato"

cat <<EOF
Il tuo mini-server è pronto! 🕷️

**Chiave pubblica Yggdrasil:** $public_key

**Indirizzo IPv6:** $ipv6

Invia questi dati a [**pepealessandro@proton.me**](mailto:pepealessandro@proton.me) per richiedere il collegamento alla rete Servicess.net.

Riceverai le istruzioni di connessione.
EOF
