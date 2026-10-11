# Sito statico

Questa cartella contiene esclusivamente sorgenti statici HTML/CSS/JavaScript e media. Nessun backend, `.env`, chiave, database, script server o configurazione privata.

La pubblicazione usa `tools/servicess-deploy.sh` e `deployment/static-site/deploy.py`, con allowlist positiva, manifest/hash approvato, backup atomico e rollback in `/var/www/{{SITE_SLUG}}/public`. Non copiare l'intera cartella e non modificare `/var/www` direttamente.
