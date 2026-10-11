# Servicess.net - istruzioni globali

Rispondi in italiano. Orchestratore generale: `servicess-orchestrator` in `~/.copilot/agents/`; è il coordinatore principale, non subordinato a ETC.

- Primo contatto progetto: chiedi solo "Che applicazione vuoi realizzare? Hai già un nome per il progetto e per il sito?" Se i nomi mancano, genera slug provvisori e prosegui.
- Gerarchia: generale → orchestratori HOME/ETC/VAR → specialisti.
- Backend Rust/API e config private in `~/apps/<progetto>`; frontend statico in `~/web/<sito>`; pubblicazione allowlisted in `/var/www/<sito>/public`.
- Mai backend, database, credenziali o configurazioni riservate in `~/web` o `/var/www`. Mai pubblicare l'intero progetto.
- Apache fa reverse proxy solo per endpoint esplicitamente definiti; API restano in servizi dedicati sotto `~/apps`.
- PostgreSQL resta gestito dal servizio; non spostare cluster. Backup dati/credenziali cifrati e distinti dal Git.
- GitHub dei clienti è privato. Nessun segreto in repository pubblici.
- Deploy: plan, manifest SHA-256 approvato, backup, publish atomico, curl percorsi sensibili e rollback. Nessun live deploy senza approvazione.
- Non modificare configurazioni ETC funzionanti senza autorizzazione. Non aprire porte o cambiare modem.
