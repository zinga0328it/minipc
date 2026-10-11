# yggdrasil

File: `/etc/yggdrasil/` (proprietario `root`, gruppo `yggdrasil`, modo 0750). Servizio: `yggdrasil`. Interfaccia `tun0`. Controllo: `yggdrasilctl`.

## Stato
- Indirizzo IPv6 `202:f4:dc04:1ed3:2c02:2f5:53e6:3b23`, versione 0.5.12, peer in uscita attivi.
- Porta peer UDP 9001 aperta in `/etc/nftables/services/yggdrasil.conf`; jail fail2ban `yggdrasil`.

## Regole
- La configurazione contiene la chiave privata: non stamparla, non copiarla in repository, non esporla nei log.
- Leggere `/etc/yggdrasil/` richiede privilegi (`sudo`): chiedere l'autorizzazione prima.
- Prima di ogni modifica: backup, validazione della configurazione, poi riavvio di `yggdrasil` (autorizzazione richiesta) e verifica con `yggdrasilctl getSelf` e `getPeers`.
- Non aprire altre porte Yggdrasil senza passare da `nftables`; dopo ogni intervento verificare che SSH resti raggiungibile.
