# Da includere DENTRO il VirtualHost onion (mai in quello del tunnel). Modulo indipendente.
# Da Tor ogni richiesta arriva da 127.0.0.1: nessun IP reale, nessun ban per IP, nessun mod_remoteip.

# Protezioni applicative: limiti su dimensione di richiesta e header.
LimitRequestBody 10240
LimitRequestLine 2048
LimitRequestFields 40

# Nessun IP e nessuno User-Agent: si registra solo cosa e' stato richiesto.
LogFormat "%t \"%r\" %>s" honeypot_onion

SetEnvIfNoCase Request_URI "^/(\.env|\.git(/|$)|wp-login\.php|wp-admin|xmlrpc\.php|phpmyadmin|pma(/|$)|cgi-bin/|boaform|actuator|vendor/phpunit)" honeypot_onion_hit

CustomLog ${APACHE_LOG_DIR}/honeypot-onion.log honeypot_onion env=honeypot_onion_hit
