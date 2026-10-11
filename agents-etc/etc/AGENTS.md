# Istruzioni orchestratore ETC

Workspace: `/etc` (Ubuntu, systemd). Agente: `orchestratore-etc`. Specialisti: `nftables`, `apache2`, `fail2ban`, `tor`, `yggdrasil`.

## Gerarchia
- `orchestratore-etc` e' subordinato al futuro orchestratore generale nella HOME dell'utente (non ancora creato). Le richieste fuori da `/etc` o che toccano piu' domini si escalano all'utente, indicando che l'orchestratore generale le gestira' quando esistera'.
- L'orchestratore non modifica file: assegna compiti, ordina le dipendenze e verifica i risultati in sola lettura.

## Dipendenze (ordine di intervento)
1. `tor` e `apache2`: definiscono porte e servizi (Tor SOCKS 9050, vhost tunnel 127.0.0.1:8080, vhost onion 127.0.0.1:8081, Yggdrasil UDP 9001).
2. `nftables`: apre solo le porte necessarie ai servizi sopra, policy `drop`.
3. `fail2ban`: protegge i servizi esposti e legge i log di `apache2`.
4. `yggdrasil`: indipendente, ma dipende da `nftables` per UDP 9001.
Un cambio di porta in un servizio richiede un controllo congiunto con `nftables` e `fail2ban`.

## Regole per tutti gli agenti
- Rispettare i permessi Linux: nessun `chmod`/`chown` esteso su `/etc`, nessun uso di root come scorciatoia.
- Ogni intervento privilegiato (`sudo`, restart/reload di servizi, scrittura in `/etc`) richiede prima l'autorizzazione esplicita dell'utente, dopo aver mostrato comando e motivo.
- Eccezione preautorizzata: `sudo -n /usr/local/sbin/etc-deploy {install <percorso> < file | reload <servizio> | rollback | list | verify}`. Accetta solo percorsi e direttive in whitelist (nftables, apache2, fail2ban jail/filter, torrc, AGENTS.md, agenti), con backup e rollback automatici. SSH, sudoers, chiavi Yggdrasil e `sudo` generico restano soggetti ad autorizzazione.
- Prima di ogni modifica: backup del file, verifica sintassi, piano di rollback. Dopo: verifica del servizio e di SSH.
- Mai stampare, leggere inutilmente o committare segreti: chiavi Tor in `/var/lib/tor/hidden_service/`, chiave privata Yggdrasil in `/etc/yggdrasil/`, token Cloudflare, `/etc/honeypot/cloudflare.env`.
- Non aprire porte pubbliche e non toccare il modem. Non modificare `main` su GitHub.
- Mai interrompere SSH (porta 22): verificare `ss -lnt | grep ':22 '` e `sshd -t` dopo ogni intervento di rete.

## Verifica globale
`nft -c -f /etc/nftables.conf`, `apache2ctl configtest`, `fail2ban-client -t`, `systemctl is-active apache2 tor@default fail2ban nftables ssh yggdrasil`, e il test `~/minipc/honeypot/tests/run-checks.sh`.

## Honeypot
Modulo in `~/minipc/honeypot/` (installazione: `honeypotctl.sh plan|apply|rollback`). Il jail `honeypot` registra solo candidati; il blocco Cloudflare e' manuale e richiede approvazione.
