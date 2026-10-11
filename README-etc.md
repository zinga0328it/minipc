# Ramo etc

- nftables/core.conf: policy drop, include modulari da nftables/services/*.conf
- fail2ban/: jail sshd, apache-auth, yggdrasil (azione nftables multiport, ignoreip locale)
- apache2/: siti normali su 127.0.0.1:8080 (tunnel Cloudflare), onion su 127.0.0.1:8081
- tor/torrc: HiddenServicePort 80 -> 127.0.0.1:8081 (vhost onion separato, docroot /var/www/onion)
- onion-www/: pagina di test statica del servizio onion
- cloudflared/config.yml.example: template tunnel verso 127.0.0.1:8080

## Sciame ETC
Agenti in `.github/agents/`: `orchestratore-etc`, `nftables`, `apache2`, `fail2ban`, `tor`, `yggdrasil`, `bash`. L'orchestratore generale Servicess.net esiste in HOME e non e' subordinato a ETC; delega generale verso `static-deploy` verificata.

## Deployment privilegiato
`admin/etc-deploy` (installato in `/usr/local/sbin`, root:root) + `/etc/sudoers.d/90-etc-deploy` (solo quel comando in `NOPASSWD`). Installazione/aggiornamento: `sudo bash admin/bootstrap.sh`. Limiti: whitelist di percorsi, no symlink, directory solo di root, filtri su direttive che eseguono codice, rollback automatico. Nota: `ragno` ha anche `NOPASSWD: ALL` in `/etc/sudoers.d/{ragno,90-ragno}`; finche' esiste, il deploy non e' un limite. Revoca reversibile: `sudo bash admin/bootstrap.sh --revoke-nopasswd-all`.

## Bash
`tools/check.sh` (bash -n, ShellCheck, shfmt, Bats), `lib/common.sh`, test in `tests/bash/`.

## Sciame ETC (specchio documentazione)
Specchio in `agents-etc/etc/` (installazione: copiare sotto `/etc` con root, dopo approvazione).
- `AGENTS.md` in `/etc`, `/etc/{nftables,apache2,fail2ban,tor,yggdrasil}`
- Agenti di servizio in `.github/agents/`; copia operativa dei profili ETC in `/etc/.github/agents/`
- `orchestratore-etc` e' subordinato all'orchestratore generale HOME e coordina specialisti ETC
- Ogni operazione privilegiata fuori da `etc-deploy` richiede autorizzazione esplicita
- La delega generale e' stata provata; la selezione dell'orchestratore ETC nel workspace `/etc` non e' verificata in questa sessione

## Stato /etc e blocchi
- nftables: 80/443 rimosse (Apache solo su localhost); ServerName globale in Apache; `X11Forwarding no` in `/etc/ssh/sshd_config.d/60-hardening.conf`
- Cloudflare Tunnel: nessun tunnel permanente (serve account/dominio, token e zone ID in `/etc/honeypot/cloudflare.env`); provato solo un quick tunnel temporaneo
- SSH: `PasswordAuthentication yes` e `PubkeyAuthentication yes` devono restare SEMPRE entrambe attive: senza la password la piattaforma Code Agents non parte. Non disattivare la password; protezione via jail fail2ban `sshd`.
