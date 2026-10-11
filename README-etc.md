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
- Gli agenti sono letti da VS Code all'avvio: dopo l'installazione serve `Developer: Reload Window` (non ancora eseguito: delega non provata)

## Stato /etc e blocchi
- nftables: 80/443 rimosse (Apache solo su localhost); ServerName globale in Apache; `X11Forwarding no` in `/etc/ssh/sshd_config.d/60-hardening.conf`
- Cloudflare Tunnel: nessun tunnel permanente (serve account/dominio, token e zone ID in `/etc/honeypot/cloudflare.env`); provato solo un quick tunnel temporaneo
- SSH: `PasswordAuthentication yes` lasciato attivo, il login a chiave non e' verificato da questa macchina; disattivarlo solo dopo una prova da un client con chiave
