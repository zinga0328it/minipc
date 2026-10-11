# Distribuzione statica

La piattaforma separa backend privato, sorgenti statici e document root pubblica.

- `tools/create-project.py <progetto> <sito>` crea due repository locali isolati da template Rust e statico; non sovrascrive e non crea remoti pubblici.
- Backend: `~/apps/<progetto>/api` (Rust), `modules`, `database`, `secrets`, `config`. Segreti 0700/0600 e Gitignored.
- Frontend: solo HTML/CSS/JS e asset in `~/web/<sito>`.
- `deploy.py` è un publisher a allowlist positiva; i percorsi operativi non sono stati toccati.

- Sorgente: `~/web/<sito>`; destinazione consentita dal modello: `/var/www/<sito>/public`.
- Allowlist positiva: HTML/CSS/JS e asset immagini/font enumerati in `deploy.py`. File/directory nascosti, symlink, AGENTS.md, percorsi privati/dati, database, credenziali, backend e script server esclusi.
- `tools/servicess-deploy.sh plan <sito>` calcola file, dimensioni, esclusioni, SHA-256 e hash approvabile. Un hash non approvato è rifiutato.
- Il dispatcher `/usr/local/sbin/servicess-deploy` (sorgente `admin/`) esegue publish/rollback statico, e installa/gestisce solo unit `servicess-<slug>.service` validate con systemd. Sudoers autorizza solo questo dispatcher; nessuna shell/interprete.
- Publish rilegge/hash-verifica i file, fa backup dell'attuale `public` e sostituisce con rename atomico; rollback ripristina anche una prima pubblicazione.
- Test sandbox: `python3 -m unittest discover -s tests/deployment`; non necessita root e non scrive in `/var`.
- Apache template: `deployment/apache2/static-site-vhost.conf.template`; DocumentRoot solo `public`, `Options -Indexes -ExecCGI -Includes`, `AllowOverride None`.
- API via `deployment/apache2/api-proxy-location.conf.template` verso localhost e unit protetta `deployment/systemd/rust-api.service.template`; nessuna API reale configurata ora.
- Backup progetto/PG cifrati con `tools/backup-private.sh` e age; restore va provato per ciascun cliente.
- Questa fase non installa vhost, non crea `/var/www`, non copia siti e non modifica `/etc`.

## Avvio VS Code
`tools/servicess-bootstrap.sh check|open` controlla il profilo Agent Host, sincronizza agenti/istruzioni con backup, genera un workspace multi-root HOME/ETC/VAR e apre VS Code.
La CLI non seleziona e non invia un custom agent automaticamente: il bootstrap non finge di farlo. Dopo l'apertura, selezionare `servicess-orchestrator`; il suo primo turno chiede esclusivamente l'applicazione e i nomi progetto/sito.

## Installazione privilegiata
`admin/install-servicess.sh` richiede un'autorizzazione amministrativa una tantum, crea backup e installa il dispatcher e sudoers ristretto. Rifiuta esplicitamente `NOPASSWD: ALL` preesistente, a meno che l'amministratore non richieda `--revoke-broad-sudo`; in caso di revoca archivia e disabilita i due grant noti con rollback.
L'installer non è stato eseguito. Nessuna configurazione `/etc` operativa o destinazione `/var/www` è stata cambiata da questa fase.
