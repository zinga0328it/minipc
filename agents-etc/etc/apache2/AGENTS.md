# apache2

File: `/etc/apache2/ports.conf`, vhost in `sites-available/` (abilitati: `test-tunnel.conf`, `onion.conf`), moduli honeypot in `/etc/apache2/honeypot/*.inc`. Log in `/var/log/apache2/`.

## Stato
- `test-tunnel.conf`: `127.0.0.1:8080`, docroot `/var/www/html`, origine del Cloudflare Tunnel; include `honeypot-vhost.inc` (IP reale da `CF-Connecting-IP`, solo da localhost).
- `onion.conf`: `127.0.0.1:8081`, docroot `/var/www/onion`, origine dell'hidden service Tor; include `honeypot-onion.inc` (nessun IP, nessun ban).
- Log honeypot separati: `honeypot.log` (tunnel) e `honeypot-onion.log` (onion).

## Regole
- Non mettere mai il modulo tunnel nel vhost onion e viceversa; non usare `mod_remoteip` sul vhost onion.
- Le porte 8080/8081 restano su localhost: mai su `0.0.0.0`.
- Prima di ogni modifica: backup e `apache2ctl configtest`; poi `systemctl reload apache2` (autorizzazione richiesta).
- Modifiche ai moduli honeypot passano da `~/minipc/honeypot/` e da `scripts/honeypotctl.sh`.
- Verifica: `curl -i http://127.0.0.1:8080/` e `:8081/` (200), `/.env` (404 e riga nel log dedicato).
