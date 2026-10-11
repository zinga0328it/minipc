#!/usr/bin/env bats

setup() {
  ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd)
  SB=$(mktemp -d)
  mkdir -p "$SB/bin"
  export YGG_FIXTURE="$SB/getself"
  export YGG_STATE=active
  cat >"$SB/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
[[ $YGG_STATE == active ]]
EOF
  cat >"$SB/bin/sudo" <<'EOF'
#!/usr/bin/env bash
[[ $1 == -n && $2 == yggdrasilctl && $3 == getSelf ]] || exit 2
[[ ${YGG_COMMAND_FAIL:-0} != 1 ]] || exit 1
cat "$YGG_FIXTURE"
EOF
  chmod +x "$SB/bin/systemctl" "$SB/bin/sudo"
  export PATH="$SB/bin:$PATH"
  cat >"$YGG_FIXTURE" <<'EOF'
Build version: 0.5.12
IPv6 address: 202:f4:dc04:1ed3:2c02:2f5:53e6:3b23
Public key: 3fe1647f7c259a7fbfa15583389b98ba1321cecaf6af7939dcc417a96bde381f
Private key: MUST_NEVER_BE_PRINTED
EOF
}

teardown() { rm -rf "$SB"; }

@test "mostra la chiave pubblica, IPv6 e richiesta email" {
  run "$ROOT/tools/yggdrasil-onboarding.sh"
  [ "$status" -eq 0 ]
  [[ $output == *'3fe1647f7c259a7fbfa15583389b98ba1321cecaf6af7939dcc417a96bde381f'* ]]
  [[ $output == *'202:f4:dc04:1ed3:2c02:2f5:53e6:3b23'* ]]
  [[ $output == *'mailto:pepealessandro@proton.me'* ]]
  [[ $output != *'MUST_NEVER_BE_PRINTED'* ]]
}

@test "non dichiara pronto il sistema se Yggdrasil non e' attivo" {
  YGG_STATE=inactive run "$ROOT/tools/yggdrasil-onboarding.sh"
  [ "$status" -ne 0 ]
  [[ $output == *'servizio non attivo'* ]]
  [[ $output != *'Il tuo mini-server è pronto'* ]]
}

@test "fallisce senza esporre dati se getSelf non e' autorizzato" {
  YGG_COMMAND_FAIL=1 run "$ROOT/tools/yggdrasil-onboarding.sh"
  [ "$status" -ne 0 ]
  [[ $output == *'getSelf non accessibile'* ]]
  [[ $output != *'MUST_NEVER_BE_PRINTED'* ]]
}

@test "rifiuta valori pubblici malformati" {
  printf 'IPv6 address: not-ip\nPublic key: short\n' >"$YGG_FIXTURE"
  run "$ROOT/tools/yggdrasil-onboarding.sh"
  [ "$status" -ne 0 ]
  [[ $output == *'chiave pubblica assente o malformata'* ]]
}
