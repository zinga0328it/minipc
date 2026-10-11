# minipc - istruzioni per gli agenti

Infrastruttura di un mini-PC Ubuntu (systemd): nftables, Apache2, Fail2ban, Tor, Yggdrasil, Cloudflare Tunnel, honeypot. Repository: configurazioni e script; i file attivi stanno in `/etc`.

## Architettura e agenti
Orchestratore generale in `~/.copilot/agents/servicess-orchestrator.agent.md`; istruzioni globali in `~/.copilot/copilot-instructions.md`. Gerarchia: orchestratore generale → orchestratori HOME/ETC/VAR → specialisti.

Gli agenti di questo repository sono in `.github/agents/`: `orchestratore-etc`, `nftables`, `apache2`, `fail2ban`, `tor`, `yggdrasil`, `bash`.

Backend privati: `~/apps/<nome>/`. Sorgenti frontend: `~/web/<sito>/`. Pubblicazione solo statici allowlisted verso `/var/www/<sito>/public`; API restano nei backend e sono esposte solo tramite proxy esplicito. Nessun database o backend va in `~/web` o `/var/www`.

## Struttura
- `nftables/`, `apache2/`, `fail2ban/`, `tor/`, `ssh/`: copie delle configurazioni.
- `honeypot/`: moduli honeypot (tunnel e onion), test in `honeypot/tests/run-checks.sh`.
- `admin/`: `etc-deploy` (deploy privilegiato), `sudoers/`, `bootstrap.sh`.
- `lib/common.sh`, `tools/check.sh`, `tests/bash/`: ambiente Bash standard.
- `deployment/static-site/deploy.py`: utility sorgente per piano, manifest approvato, backup e rollback. Non è installata né applicata al server.
- `templates/`, `tools/create-project.py`: scaffold Rust privato e sito statico separato, senza sovrascritture.
- `tools/backup-private.sh`: archivi app e dump PostgreSQL cifrati con age.
- `admin/servicess-admin.py`: publisher VAR e gestione di soli servizi `servicess-<slug>`.
- `tools/servicess-bootstrap.sh`: check e apertura workspace multi-root; non invia chat automaticamente.

## Regole
- Scritture in `/etc`: solo `sudo -n /usr/local/sbin/etc-deploy install <percorso> < <file>` (percorsi e direttive in whitelist, backup e rollback automatici), poi `etc-deploy reload <servizio>`. Altro `sudo`: chiedere all'utente con comando e motivo.
- Prima di ogni modifica: backup, verifica sintassi, piano di rollback. Dopo: verificare servizio e SSH (porta 22).
- Mai pubblicare o stampare segreti: chiavi Tor e Yggdrasil, token Cloudflare, `/etc/honeypot/cloudflare.env`.
- Non aprire porte pubbliche, non toccare il modem, non modificare `main`.
- SSH: devono restare SEMPRE attive sia la chiave pubblica sia la password (`PubkeyAuthentication yes` e `PasswordAuthentication yes`), non solo la chiave: senza la password la piattaforma Code Agents non parte. Mai disattivare `PasswordAuthentication`; la protezione resta nel jail fail2ban `sshd`.
- Il cliente deve aprire **Code Agents** (host Agents di VS Code), non il VS Code normale: serve per usare il multi-agente (orchestratore e specialisti).
- Non dichiarare funzionante cio' che non e' stato verificato.
- Revisione manifest obbligatoria: l'allowlist esclude tipi/file riservati ma non può dimostrare che contenuto statico arbitrario sia innocuo.
- Installazione admin separata e non eseguita: non usare finché resta attivo `NOPASSWD: ALL`; prima va revocato con approvazione.

## Comandi utili
- Verifica Bash: `tools/check.sh` (bash -n, ShellCheck, shfmt, Bats).
- Verifica infrastruttura: `sudo -n /usr/local/sbin/etc-deploy verify` e `honeypot/tests/run-checks.sh`.
- Rollback: `sudo -n /usr/local/sbin/etc-deploy rollback`.
- Test publisher: `python3 -m unittest discover -s tests/deployment -v`.
- Bootstrap: `tools/servicess-bootstrap.sh check|open`.
