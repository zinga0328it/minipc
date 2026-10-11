# minipc - istruzioni per gli agenti

Infrastruttura di un mini-PC Ubuntu (systemd): nftables, Apache2, Fail2ban, Tor, Yggdrasil, Cloudflare Tunnel, honeypot. Repository: configurazioni e script; i file attivi stanno in `/etc`.

## Agenti (`.github/agents/`)
`orchestratore-etc` coordina `nftables`, `apache2`, `fail2ban`, `tor`, `yggdrasil` e `bash`. Documentazione per servizio in `/etc/<servizio>/AGENTS.md` (specchio in `agents-etc/`) e `/etc/AGENTS.md`. L'orchestratore generale nella HOME non esiste ancora.

## Struttura
- `nftables/`, `apache2/`, `fail2ban/`, `tor/`, `ssh/`: copie delle configurazioni.
- `honeypot/`: moduli honeypot (tunnel e onion), test in `honeypot/tests/run-checks.sh`.
- `admin/`: `etc-deploy` (deploy privilegiato), `sudoers/`, `bootstrap.sh`.
- `lib/common.sh`, `tools/check.sh`, `tests/bash/`: ambiente Bash standard.

## Regole
- Scritture in `/etc`: solo `sudo -n /usr/local/sbin/etc-deploy install <percorso> < <file>` (percorsi e direttive in whitelist, backup e rollback automatici), poi `etc-deploy reload <servizio>`. Altro `sudo`: chiedere all'utente con comando e motivo.
- Prima di ogni modifica: backup, verifica sintassi, piano di rollback. Dopo: verificare servizio e SSH (porta 22).
- Mai pubblicare o stampare segreti: chiavi Tor e Yggdrasil, token Cloudflare, `/etc/honeypot/cloudflare.env`.
- Non aprire porte pubbliche, non toccare il modem, non modificare `main`, non cambiare l'autenticazione SSH finche' il login a chiave da un client esterno non e' verificato.
- Non dichiarare funzionante cio' che non e' stato verificato.

## Comandi utili
- Verifica Bash: `tools/check.sh` (bash -n, ShellCheck, shfmt, Bats).
- Verifica infrastruttura: `sudo -n /usr/local/sbin/etc-deploy verify` e `honeypot/tests/run-checks.sh`.
- Rollback: `sudo -n /usr/local/sbin/etc-deploy rollback`.
