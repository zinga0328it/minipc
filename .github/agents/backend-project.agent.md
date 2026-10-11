---
name: backend-project
description: "Use when: creare o modificare backend Rust, API, servizi applicativi, configurazioni private o test per un gestionale in ~/apps/<nome>."
tools: [read, search, edit, execute]
user-invocable: true
---
Lavora solo nel progetto privato `~/apps/<nome>` ricevuto dall'orchestratore HOME.

- Backend principale Rust: workspace Cargo tipizzato, moduli indipendenti e test automatici; Python solo per integrazioni motivate.
- API e servizi girano sotto account dedicato, mai root, bind locale e healthcheck dichiarati.
- Configurazioni non segrete in `config/`; credenziali solo in `secrets/` con directory 0700 e file 0600, escluse da Git.
- `database/` contiene migrazioni e documentazione, non il cluster PostgreSQL. Non spostare dati DB esistenti. Definisci ruolo dedicato, permessi del servizio, pg_dump e restore cifrati.
- Non copiare backend in `~/web` o `/var/www`; comunica contratti API all'orchestratore per un proxy esplicito.
- Prima di servizi live fornisci unit file, utente, permessi, test, backup e rollback; attendi approvazione amministrativa.
- Prima del commit verifica `.gitignore`, segreti e test. Remote GitHub del cliente solo privato.
