# Servicess.net - istruzioni globali

Rispondi in italiano. Orchestratore generale: `servicess-orchestrator` in `~/.copilot/agents/`; è il coordinatore principale, non subordinato a ETC.

- Primo contatto progetto: chiedi solo "Che applicazione vuoi realizzare? Hai già un nome per il progetto e per il sito?" Se i nomi mancano, genera slug provvisori e prosegui.
- Gerarchia: generale → orchestratori HOME/ETC/VAR → specialisti.
- Backend Rust/API e config private in `~/apps/<progetto>`; frontend statico in `~/web/<sito>`; pubblicazione allowlisted in `/var/www/<sito>/public`.
- Mai backend, database, credenziali o configurazioni riservate in `~/web` o `/var/www`. Mai pubblicare l'intero progetto.
- Apache fa reverse proxy solo per endpoint esplicitamente definiti; API restano in servizi dedicati sotto `~/apps`.
- PostgreSQL resta gestito dal servizio; non spostare cluster. Backup dati/credenziali cifrati e distinti dal Git.
- GitHub dei clienti è privato. Nessun segreto in repository pubblici.
- All'avvio verifica Yggdrasil con `systemctl` e `sudo -n yggdrasilctl getSelf`; mostra IPv6 e sola chiave pubblica usando `tools/yggdrasil-onboarding.sh`. Non leggere mai la configurazione o la chiave privata. Chiedi di inviare i dati a pepealessandro@proton.me; non inviare email e attendi i parametri di peering autorizzati.
- Prima di usare CLI AI verifica i CLI `codex`, `codex-security` e `copilot`. Controlla `codex login status` e `codex-security login status`; se Codex Security non è autenticato, il cliente completa `codex-security login`. Copilot CLI 1.0.x non offre status: se il primo uso richiede accesso, guida il cliente in `copilot login`. Attendi i login ChatGPT/Codex Security e GitHub Copilot prima dell'uso; non chiedere token/password e non alterare sessioni già autenticate.
- Deploy: plan, manifest SHA-256 approvato, backup, publish atomico, curl percorsi sensibili e rollback. Nessun live deploy senza approvazione.
- Non modificare configurazioni ETC funzionanti senza autorizzazione. Non aprire porte o cambiare modem.
- Sicurezza minima di ogni nuovo progetto (da verificare prima del deploy, non assumere): servizio systemd con utente dedicato e hardening (`NoNewPrivileges`, `ProtectSystem=strict`, `PrivateTmp`, bind su localhost); HTTPS obbligatorio sul sito pubblico; header di sicurezza nel vhost (CSP, HSTS, `X-Content-Type-Options`) solo se `mod_headers` e' attivo; utenti del gestionale con password Argon2, sessioni sicure e MFA per gli amministratori; `cargo audit` e scansione segreti prima di ogni commit/push; nessun deploy con `NOPASSWD: ALL` ancora attivo. Cio' che non e' stato verificato va riportato come "non verificato".
