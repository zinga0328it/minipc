# Gestionale privato

## Layout
- `api/`: servizi Rust, senza privilegi, bind solo localhost.
- `modules/`: crates Rust indipendenti e testati.
- `config/`: configurazioni non segrete; segreti caricati da file in `secrets/`.
- `database/`: documentazione e migrazioni, non copie raw di PostgreSQL.
- `secrets/`: credenziali runtime escluse da Git, directory 0700 e file 0600.

## Regole
- Non copiare nessun backend, database o segreto in `~/web` o `/var/www`.
- API esposte solo via proxy esplicitamente configurato; servizi backend continuano a girare da questa directory.
- Ogni modulo dichiara API e dipendenze; test automatici obbligatori.
- Backup di sorgenti/config/dati applicativi cifrati; PostgreSQL con `pg_dump` tramite ruolo dedicato e restore provato.
- Git remoto del cliente privato; verifica `.gitignore` e scansione segreti prima del push.
