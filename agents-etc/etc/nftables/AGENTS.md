# nftables

File: `/etc/nftables.conf` (flush + include di `core.conf`), `/etc/nftables/core.conf` (tabella `inet filter`, `policy drop`, `jump banned`), `/etc/nftables/services/{ssh,yggdrasil,tor,apache2,banned}.conf`. La directory appartiene a `ragno`.

## Stato
Porte accettate in input: TCP 22 (SSH), UDP 9001 (Yggdrasil), TCP 9050 (Tor SOCKS). Loopback, established e ICMP accettati. Apache ascolta solo su 127.0.0.1:8080/8081 (loopback), quindi `services/apache2.conf` e' vuoto di proposito: non riaprire 80/443 senza un servizio pubblico reale.

## Regole
- Un servizio = un file in `services/`, incluso da `core.conf`.
- Prima di ogni modifica: copia di backup e `nft -c -f /etc/nftables.conf`.
- Applicare con `systemctl reload nftables` (autorizzazione richiesta) seguito da `fail2ban-client reload`: `flush ruleset` cancella le tabelle di fail2ban.
- Confrontare l'hash di `nft list ruleset` prima/dopo.
- fail2ban gestisce le proprie tabelle: non cancellarle con `flush ruleset` fuori dal servizio.
- Nessuna regola che possa bloccare SSH, loopback o Yggdrasil.
