# Da includere DENTRO il VirtualHost del tunnel Cloudflare (mai nel vhost onion).
# Richiede mod_remoteip, mod_setenvif, mod_log_config.

# cloudflared si connette da localhost: ci si fida dell'header solo da li'.
RemoteIPHeader CF-Connecting-IP
RemoteIPTrustedProxy 127.0.0.1 ::1

# %a = IP reale del visitatore (risolto da mod_remoteip)
LogFormat "%a %t \"%r\" %>s \"%{User-Agent}i\"" honeypot

# Percorsi che un utente legittimo non richiede mai: solo scanner/bot.
SetEnvIfNoCase Request_URI "^/(\.env|\.git(/|$)|wp-login\.php|wp-admin|xmlrpc\.php|phpmyadmin|pma(/|$)|cgi-bin/|boaform|actuator|vendor/phpunit)" honeypot_hit

CustomLog ${APACHE_LOG_DIR}/honeypot.log honeypot env=honeypot_hit
