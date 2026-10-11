# Honeypot modulare (Apache2 + Cloudflare Tunnel + Fail2ban)

Stato: attivato sul server (modalita' solo-log). Rollback: `scripts/honeypotctl.sh rollback`.

## Moduli
| File | Ruolo |
|---|---|
| `apache2/honeypot-vhost.inc` | Canale Cloudflare Tunnel: IP reale da `CF-Connecting-IP` (solo da localhost), log `honeypot.log` per i percorsi esca |
| `apache2/honeypot-onion.inc` | Canale Tor, indipendente: nessun IP e nessun ban, log `honeypot-onion.log` senza IP/UA, limiti su body e header |
| `fail2ban/filter.d/honeypot.conf` | legge `honeypot.log` |
| `fail2ban/action.d/honeypot-log.conf` | nessun ban: scrive i candidati in `/var/log/honeypot/candidates.log` |
| `fail2ban/jail.d/honeypot.local` | 3 hit in 10 minuti, solo canale tunnel, azione solo-log |
| `scripts/cf-block.sh` | blocco/sblocco IP su Cloudflare, dry-run di default, rifiuta IP non pubblici o in allowlist |
| `scripts/honeypotctl.sh` | `plan` / `apply` / `rollback` con backup in `/var/backups/honeypot` |
| `tests/run-checks.sh` | verifiche senza root |

## Scelte
- Nessuna porta pubblica aperta, nessuna modifica a `nftables/core.conf`.
- Un ban nftables locale non avrebbe effetto sul traffico del tunnel (arriva da 127.0.0.1): il blocco passa da Cloudflare, dopo approvazione.
- Il vhost onion usa un modulo separato: nessun IP reale da registrare, quindi nessun ban.

## Non attivo
- Blocco WAF Cloudflare: servono token e zone ID in `/etc/honeypot/cloudflare.env` e un tunnel configurato (oggi assente). `cf-block.sh` e' stato provato solo in dry-run.
- Raggiungibilita' reale dell'onion da Tor: non verificata (timeout).
- Il jail registra i candidati in `/var/log/honeypot/candidates.log`, non banna.

## Credenziali
`/etc/honeypot/cloudflare.env` (`CF_API_TOKEN`, `CF_ZONE_ID`, permessi 0600) e `/etc/honeypot/allowlist.txt` restano fuori dal repository. Token con solo permesso Zone > Firewall Services > Edit.
