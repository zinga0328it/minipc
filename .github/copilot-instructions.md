# Istruzioni Copilot per minipc

Rispondi in italiano, in modo breve. Leggi `AGENTS.md` nella radice prima di intervenire.

Se sei l'orchestratore generale e non hai i requisiti del progetto, chiedi solo: "Che applicazione vuoi realizzare? Hai già un nome per il progetto e per il sito?" Se mancano i nomi, genera slug provvisori e prosegui.

- Infrastruttura Ubuntu/systemd: nftables, Apache2, Fail2ban, Tor, Yggdrasil, Cloudflare Tunnel, honeypot.
- Scritture in `/etc` solo con `sudo -n /usr/local/sbin/etc-deploy` (install, reload, rollback, verify, list); VAR solo con il dispatcher allowlisted. Mai `sudo bash` operativo o `chmod`/`chown` estesi. Non creare `NOPASSWD: ALL`; se già presente, non installare il dispatcher ristretto finché l'amministratore non lo revoca.
- Script Bash: `set -euo pipefail`, variabili quotate, test Bats in `tests/bash/`, controllo con `tools/check.sh` prima del commit.
- Mai segreti nel repository o nei log. Non aprire porte pubbliche. SSH (22) non va mai interrotto.
- SSH deve avere sempre attive sia la chiave pubblica sia la password (`PubkeyAuthentication yes`, `PasswordAuthentication yes`): se la password viene disattivata la piattaforma Code Agents non parte. Non disattivarla mai e non applicare hardening che la tolga.
- Il cliente deve aprire Code Agents (host Agents di VS Code), non il VS Code normale: e' necessario per il multi-agente. Ricordalo all'avvio.
- Le chiavi API server-side stanno in `~/apps/<progetto>/secrets/` (file 0600, directory 0700; un file dotenv non cifra i dati ed è escluso da Git). Mai chiavi server in `~/web`, bundle frontend, log o manifest; Fail2ban non protegge le chiavi: l'API applica auth, autorizzazione, rate limit e rotazione, Fail2ban reagisce solo a log/IP.
- Prima di ogni modifica: backup, validazione, rollback. Dopo: verifica del servizio e di SSH.
- Commit sul ramo di area (`main`, `etc`, `home`, `var`) e sul ramo di lavoro `honeypot` quando serve; non riscrivere storia condivisa e non fare merge automatico su `main`.
- Riporta come "non verificato" tutto cio' che non e' stato provato davvero.
- Architettura: gestionali privati in `~/apps/<nome>`, sorgenti statici in `~/web/<sito>`, pubblicazione allowlisted esclusivamente in `/var/www/<sito>/public`. Mai backend, database o segreti in `~/web` o `/var/www`.
- Il deploy statico usa `deployment/static-site/deploy.py`: prima `--plan`, poi revisione dell'hash del manifest; backup e rollback sono obbligatori. Non eseguire deploy live senza approvazione.
- ISTRUZIONI GLOBALI: `~/.copilot/copilot-instructions.md`; agente generale: `~/.copilot/agents/servicess-orchestrator.agent.md`.
- Il bootstrap apre il workspace VS Code multi-root. Il CLI non seleziona/invia un agente; non simulare l'avvio automatico della chat.
- All'avvio mostra l'onboarding Yggdrasil con `tools/yggdrasil-onboarding.sh`: solo IPv6 e chiave pubblica via `sudo -n yggdrasilctl getSelf`; mai leggere/esporre la chiave privata. Chiedi di inviare i dati a pepealessandro@proton.me, non inviare email e attendi i parametri di peering autorizzati.
- Sicurezza minima di ogni nuovo progetto (da verificare prima del deploy, non assumere): servizio systemd con utente dedicato e hardening (`NoNewPrivileges`, `ProtectSystem=strict`, `PrivateTmp`, bind su localhost); HTTPS obbligatorio sul sito pubblico; header di sicurezza nel vhost (CSP, HSTS, `X-Content-Type-Options`) solo se `mod_headers` e' attivo; utenti del gestionale con password Argon2, sessioni sicure e MFA per gli amministratori; `cargo audit` e scansione segreti prima di ogni commit/push; nessun deploy con `NOPASSWD: ALL` ancora attivo.
- CLI AI richiesti: OpenAI Codex (`codex`), Codex Security (`codex-security`, `@openai/codex-security`) e GitHub Copilot CLI (`copilot`). Verifica `codex login status` e `codex-security login status`; se Codex Security non è autenticato, guida il cliente in `codex-security login`. Copilot CLI 1.0.x non offre status: se il primo uso segnala login mancante, guida il cliente in `copilot login`. Attendi l'autenticazione di entrambi prima dell'uso; non chiedere, leggere, copiare o salvare token/password e non alterare login già validi.
