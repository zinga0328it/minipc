# Ramo etc

- nftables/core.conf: policy drop, include modulari da nftables/services/*.conf
- fail2ban/: jail sshd, apache-auth, yggdrasil (azione nftables multiport, ignoreip locale)
- apache2/: siti normali su 127.0.0.1:8080 (tunnel Cloudflare), onion su 127.0.0.1:8081
- tor/torrc: HiddenServicePort 80 -> 127.0.0.1:8081 (vhost onion separato, docroot /var/www/onion)
- cloudflared/config.yml.example: template tunnel verso 127.0.0.1:8080

## Sciame ETC
Specchio in `agents-etc/etc/` (installazione: copiare sotto `/etc` con root, dopo approvazione).
- `AGENTS.md` in `/etc`, `/etc/{nftables,apache2,fail2ban,tor,yggdrasil}`
- Agenti eseguibili in `/etc/.github/agents/`: `nftables`, `apache2`, `fail2ban`, `tor`, `yggdrasil`, `orchestratore-etc`
- `orchestratore-etc` coordina i cinque e sara' subordinato all'orchestratore generale nella HOME (non ancora creato)
- Interventi privilegiati sempre con autorizzazione dell'utente
