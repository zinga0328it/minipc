# nftables

File: `/etc/nftables.conf` (flush + include di `core.conf`), `/etc/nftables/core.conf` (tabella `inet filter`, `policy drop`, `jump banned`), `/etc/nftables/services/{ssh,yggdrasil,tor,apache2,banned}.conf`. La directory appartiene a `ragno`.

## Stato
Porte accettate in input: TCP 22 (SSH), UDP 9001 (Yggdrasil), TCP 9050 (Tor SOCKS), TCP 80/443 (Apache; oggi Apache ascolta solo su 127.0.0.1:8080/8081, quindi la regola 80/443 e' superflua). Loopback, established e ICMP accettati.

## Regole
- Un servizio = un file in `services/`, incluso da `core.conf`.
- Prima di ogni modifica: copia di backup e `nft -c -f /etc/nftables.conf`.
- Applicare con `systemctl reload nftables` (autorizzazione richiesta), poi verificare SSH.
- Confrontare l'hash di `nft list ruleset` prima/dopo.
- fail2ban gestisce le proprie tabelle: non cancellarle con `flush ruleset` fuori dal servizio.
- Nessuna regola che possa bloccare SSH, loopback o Yggdrasil.
