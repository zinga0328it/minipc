# Honeypot modulare (Apache2 + Cloudflare Tunnel + Fail2ban)

Stato: progettato e validato in sandbox, NON installato sul server.

## Moduli
| File | Ruolo |
|---|---|
| `apache2/honeypot-vhost.inc` | IP reale da `CF-Connecting-IP` (solo da localhost), log dedicato `honeypot.log` per i percorsi esca |
| `fail2ban/filter.d/honeypot.conf` | legge `honeypot.log` |
| `fail2ban/action.d/honeypot-log.conf` | nessun ban: scrive i candidati in `/var/log/honeypot/candidates.log` |
| `fail2ban/jail.d/honeypot.local` | 3 hit in 10 minuti, `enabled = false` |
| `scripts/cf-block.sh` | blocco/sblocco IP su Cloudflare, dry-run di default, rifiuta IP non pubblici o in allowlist |
| `scripts/honeypotctl.sh` | `plan` / `apply` / `rollback` con backup in `/var/backups/honeypot` |
| `tests/run-checks.sh` | verifiche senza root |

## Scelte
- Nessuna porta pubblica aperta, nessuna modifica a `nftables/core.conf`.
- Un ban nftables locale non avrebbe effetto sul traffico del tunnel (arriva da 127.0.0.1): il blocco passa da Cloudflare, dopo approvazione.
- Il vhost onion non include il modulo (nessun IP reale da registrare).

## Credenziali
`/etc/honeypot/cloudflare.env` (`CF_API_TOKEN`, `CF_ZONE_ID`, permessi 0600) e `/etc/honeypot/allowlist.txt` restano fuori dal repository. Token con solo permesso Zone > Firewall Services > Edit.
