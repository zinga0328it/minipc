# Ramo etc

- nftables/core.conf: policy drop, include modulari da nftables/services/*.conf
- fail2ban/: jail sshd, apache-auth, yggdrasil (azione nftables multiport, ignoreip locale)
- apache2/: siti normali su 127.0.0.1:8080 (tunnel Cloudflare), onion su 127.0.0.1:8081
- tor/torrc: HiddenServicePort 80 -> 127.0.0.1:8081 (vhost onion separato, docroot /var/www/onion)
- cloudflared/config.yml.example: template tunnel verso 127.0.0.1:8080
