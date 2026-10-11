# Istruzioni Copilot per minipc

Rispondi in italiano, in modo breve. Leggi `AGENTS.md` nella radice prima di intervenire.

- Infrastruttura Ubuntu/systemd: nftables, Apache2, Fail2ban, Tor, Yggdrasil, Cloudflare Tunnel, honeypot.
- Scritture in `/etc` solo con `sudo -n /usr/local/sbin/etc-deploy` (install, reload, rollback, verify, list). Mai `sudo bash`, mai `chmod`/`chown` estesi, mai `NOPASSWD: ALL`.
- Script Bash: `set -euo pipefail`, variabili quotate, test Bats in `tests/bash/`, controllo con `tools/check.sh` prima del commit.
- Mai segreti nel repository o nei log. Non aprire porte pubbliche. SSH (22) non va mai interrotto.
- Prima di ogni modifica: backup, validazione, rollback. Dopo: verifica del servizio e di SSH.
- Commit solo sul ramo `honeypot`; `main` non si modifica.
- Riporta come "non verificato" tutto cio' che non e' stato provato davvero.
