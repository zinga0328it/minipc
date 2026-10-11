# tor

File: `/etc/tor/torrc`. Servizio: `tor@default`. Dati in `/var/lib/tor` (proprietario `debian-tor`, modo 0700).

## Stato
- `SocksPort 9050` (locale), `HiddenServiceDir /var/lib/tor/hidden_service/`, `HiddenServicePort 80 127.0.0.1:8081` (vhost onion di Apache).
- Tor gira come utente `debian-tor`, avviato da systemd (mai da terminale con `pkill`/avvio manuale).

## Regole
- Non leggere, stampare o committare i file di chiave in `/var/lib/tor/hidden_service/` (solo `hostname` e' pubblico).
- Non cambiare proprietario o permessi di `/var/lib/tor`: un problema "permessi" va diagnosticato dai log (`journalctl -u tor@default`) prima di toccarli.
- `HiddenServicePort` deve puntare a una porta diversa da quella dei siti normali (8081, non 8080).
- Prima di ogni modifica: backup di `torrc` e `tor --verify-config`; riavvio con `systemctl restart tor@default` (autorizzazione richiesta).
- Test reale: `curl --socks5-hostname 127.0.0.1:9050 http://<hostname>/`. Se va in timeout, segnalarlo senza dichiararlo superato (il guard puo' essere sovraccarico).
- nftables deve lasciare aperta la 9050 in locale.
