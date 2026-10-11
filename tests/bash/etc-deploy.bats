#!/usr/bin/env bats
# Test di etc-deploy in una sandbox: PREFIX, PATH e uid sostituiti da una copia di test; comandi di sistema simulati.

setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  SB=$(mktemp -d)
  mkdir -p "$SB"/bin "$SB"/etc/nftables/services "$SB"/etc/apache2/{sites-available,conf-available,honeypot} \
    "$SB"/etc/fail2ban/{jail.d,filter.d} "$SB"/etc/tor "$SB"/etc/.github/agents "$SB"/var/log
  chmod -R 755 "$SB"

  local c
  for c in nft apache2ctl fail2ban-client sshd tor systemctl; do
    cat >"$SB/bin/$c" <<'EOF'
#!/usr/bin/env bash
n=$(basename "$0")
echo "$n $*" >>"$SB/calls"
[[ -e $SB/fail.$n ]] && exit 1
[[ $n == nft && $1 == list ]] && echo 'tcp dport 22 accept'
exit 0
EOF
    chmod +x "$SB/bin/$c"
  done
  cat >"$SB/bin/ss" <<'EOF'
#!/usr/bin/env bash
[[ -e $SB/fail.ss ]] && exit 0
echo 'LISTEN 0 128 0.0.0.0:22 0.0.0.0:*'
EOF
  chmod +x "$SB/bin/ss"
  export SB

  sed -e "s|^readonly PREFIX=\"\".*|readonly PREFIX=\"$SB\"|" \
    -e "s|^readonly ROOT_UID=0.*|readonly ROOT_UID=$(id -u)|" \
    -e "s|^export PATH=.*|export PATH=$SB/bin:/usr/bin:/bin|" \
    -e 's|^  \[\[ \$EUID -eq 0 \]\].*|  true|' \
    -e 's|^  install -m "\$3" -o .*|  install -m "$3" "$1" "$2"|' \
    "$ROOT/admin/etc-deploy" >"$SB/etc-deploy"
  chmod +x "$SB/etc-deploy"
  D="$SB/etc-deploy"
}

teardown() { rm -rf "$SB"; }

deploy() { # percorso contenuto
  run bash -c "printf '%s\n' \"\$2\" | '$D' install \"\$1\"" _ "$1" "$2"
}

@test "installa un file autorizzato e crea il backup" {
  deploy /etc/nftables/services/web.conf 'tcp dport 8443 accept'
  [ "$status" -eq 0 ]
  grep -q 8443 "$SB/etc/nftables/services/web.conf"
  [ "$(ls "$SB/var/backups/etc-deploy" | wc -l)" -eq 1 ]
}

@test "rifiuta percorsi non autorizzati" {
  local p
  for p in /etc/passwd /etc/sudoers.d/x /etc/ssh/sshd_config /etc/yggdrasil/yggdrasil.conf \
    /etc/nftables/../passwd relative.conf /etc/nftables/services/.hidden.conf /usr/local/sbin/etc-deploy; do
    deploy "$p" 'x'
    [ "$status" -ne 0 ] || {
      echo "accettato: $p"
      false
    }
  done
}

@test "rifiuta un bersaglio che e' un symlink" {
  ln -s /etc/passwd "$SB/etc/nftables/services/link.conf"
  deploy /etc/nftables/services/link.conf 'x'
  [ "$status" -ne 0 ]
}

@test "rifiuta una directory symlink" {
  mv "$SB/etc/tor" "$SB/tor-real"
  ln -s "$SB/tor-real" "$SB/etc/tor"
  deploy /etc/tor/torrc 'SocksPort 9050'
  [ "$status" -ne 0 ]
}

@test "rifiuta directory scrivibili da altri" {
  chmod 775 "$SB/etc/nftables/services"
  deploy /etc/nftables/services/web.conf 'x'
  [ "$status" -ne 0 ]
}

@test "blocca direttive che eseguono codice o scrivono altrove" {
  deploy /etc/apache2/conf-available/a.conf 'LoadModule evil /tmp/evil.so'
  [ "$status" -ne 0 ]
  deploy /etc/apache2/conf-available/b.conf 'CustomLog /etc/sudoers.d/x combined'
  [ "$status" -ne 0 ]
  deploy /etc/apache2/conf-available/c.conf 'ErrorLog "|/bin/sh -c id"'
  [ "$status" -ne 0 ]
  deploy /etc/apache2/conf-available/d.conf 'Include /etc/shadow'
  [ "$status" -ne 0 ]
  deploy /etc/fail2ban/jail.d/x.local 'ignorecommand = /bin/sh -c id'
  [ "$status" -ne 0 ]
  deploy /etc/tor/torrc 'Log notice file /etc/sudoers.d/x'
  [ "$status" -ne 0 ]
  deploy /etc/nftables/services/y.conf 'include "/etc/shadow"'
  [ "$status" -ne 0 ]
}

@test "accetta i log Apache consentiti" {
  deploy /etc/apache2/conf-available/ok.conf 'CustomLog ${APACHE_LOG_DIR}/honeypot.log honeypot env=honeypot_hit'
  [ "$status" -eq 0 ]
}

@test "rifiuta contenuto vuoto, binario o troppo grande" {
  run bash -c "'$D' install /etc/nftables/services/e.conf </dev/null"
  [ "$status" -ne 0 ]
  run bash -c "printf 'a\0b' | '$D' install /etc/nftables/services/e.conf"
  [ "$status" -ne 0 ]
  run bash -c "head -c 300000 /dev/zero | tr '\0' a | '$D' install /etc/nftables/services/e.conf"
  [ "$status" -ne 0 ]
}

@test "se la validazione fallisce ripristina il contenuto precedente" {
  echo original >"$SB/etc/nftables/services/keep.conf"
  touch "$SB/fail.nft"
  deploy /etc/nftables/services/keep.conf 'nuovo'
  [ "$status" -ne 0 ]
  [ "$(cat "$SB/etc/nftables/services/keep.conf")" = original ]
}

@test "se la validazione fallisce rimuove un file appena creato" {
  touch "$SB/fail.nft"
  deploy /etc/nftables/services/new.conf 'nuovo'
  [ "$status" -ne 0 ]
  [ ! -e "$SB/etc/nftables/services/new.conf" ]
}

@test "rollback esplicito ripristina l'ultima versione" {
  echo v1 >"$SB/etc/nftables/services/r.conf"
  deploy /etc/nftables/services/r.conf v2
  [ "$status" -eq 0 ]
  run "$D" rollback
  [ "$status" -eq 0 ]
  [ "$(cat "$SB/etc/nftables/services/r.conf")" = v1 ]
}

@test "reload nftables: valida, ricarica e riavvia i jail di fail2ban" {
  run "$D" reload nftables
  [ "$status" -eq 0 ]
  grep -q 'systemctl reload nftables' "$SB/calls"
  grep -q 'fail2ban-client reload' "$SB/calls"
}

@test "reload nftables: se SSH non e' piu' raggiungibile ripristina" {
  echo v1 >"$SB/etc/nftables/services/s.conf"
  deploy /etc/nftables/services/s.conf v2
  touch "$SB/fail.ss"
  run "$D" reload nftables
  [ "$status" -ne 0 ]
  [ "$(cat "$SB/etc/nftables/services/s.conf")" = v1 ]
}

@test "servizi e operazioni non autorizzati sono rifiutati" {
  run "$D" reload ssh
  [ "$status" -ne 0 ]
  run "$D" reload yggdrasil
  [ "$status" -ne 0 ]
  run "$D" check bash
  [ "$status" -ne 0 ]
  run "$D" exec id
  [ "$status" -ne 0 ]
}

@test "verifica tor con il file di default del servizio" {
  run "$D" check tor
  [ "$status" -eq 0 ]
  grep -q 'defaults-torrc .*tor-service-defaults-torrc' "$SB/calls"
}

@test "verify riporta OK con servizi simulati funzionanti" {
  run "$D" verify
  echo "$output"
  [ "$status" -eq 0 ]
}
