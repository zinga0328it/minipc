# Servicess.net - istruzioni HOME

Questa HOME contiene progetti backend privati (`apps/`) e sorgenti frontend statici (`web/`). L'orchestratore generale e' `~/.copilot/agents/servicess-orchestrator.agent.md`.

- Ogni gestionale ha una directory indipendente in `~/apps/<nome>/`, con Rust API (`api/`), moduli, config, database e secrets.
- `database/` e `secrets/` sono 0700; file riservati 0600. Database reali PostgreSQL restano gestiti dal servizio e si esportano con `pg_dump`; niente copie raw di cluster.
- `~/web/<sito>/` contiene solo HTML/CSS/JS e media statici. Vietati backend, `.env`, database, chiavi e file privati.
- Non copiare mai backend in `/var/www`. Solo il publisher allowlisted distribuisce in `/var/www/<sito>/public`.
- Ogni progetto cliente usa repository GitHub privato. Nessun segreto o dato riservato nel Git; backup separati e cifrati con age.
- Deploy: dry-run, revisione/approvazione SHA-256 del manifest, backup, deploy atomico, curl e rollback.
- Modifiche a `/etc`, servizi o `/var/www` live richiedono comando approvato e backup. Mai cambiare porte o modem senza approvazione.
