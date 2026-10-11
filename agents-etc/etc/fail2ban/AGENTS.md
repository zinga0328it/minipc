# fail2ban

File: jail in `/etc/fail2ban/jail.d/` (`sshd.local`, `apache-auth.local`, `yggdrasil.local`, `honeypot.local`), filtri in `filter.d/` (`yggdrasil.conf`, `honeypot.conf`), azioni in `action.d/` (`honeypot-log.conf`).

## Stato
- `sshd`, `apache-auth` (porte http/https), `yggdrasil` (UDP 9001): ban a 3 tentativi, `bantime` 6h, `ignoreip` locale, azione nftables.
- `honeypot`: 3 hit in 10 minuti su `/var/log/apache2/honeypot.log`, azione `honeypot-log` (solo registrazione in `/var/log/honeypot/candidates.log`, nessun ban).

## Regole
- Mai `allports` su jail che non lo richiedono e mai bannare loopback, LAN o l'IP dell'utente: mantenere `ignoreip`.
- Dal tunnel Apache vede 127.0.0.1: un ban nftables locale non colpisce i visitatori reali; il blocco passa da Cloudflare (`cf-block.sh`, dry-run di default, solo con approvazione).
- Per Tor non esistono IP reali: nessun jail su `honeypot-onion.log`.
- Prima di ogni modifica: backup, `fail2ban-client -t`, test filtri con `fail2ban-regex`. Reload con `fail2ban-client reload` (autorizzazione richiesta).
- Dopo ogni modifica: `fail2ban-client status` e verifica che SSH resti raggiungibile.
