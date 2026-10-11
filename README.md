# minipc
Infrastruttura modulare per mini-server Linux, progettata e automatizzata tramite GitHub Copilot e sciami di agenti AI. Gestione di Apache2, nftables, Fail2ban, Cloudflare Tunnel, Yggdrasil, database, sicurezza e deployment automatizzato.

## Servicess.net
La piattaforma separa i gestionali privati in `~/apps/<progetto>`, i sorgenti statici in `~/web/<sito>` e la pubblicazione allowlisted in `/var/www/<sito>/public`. Il backend standard e' Rust; PostgreSQL resta gestito dal servizio e i dati/segreti hanno backup cifrati separati dal Git.

- Agente generale e agenti HOME/ETC/VAR in `.github/agents/` (workspace) e `~/.copilot/agents/` (Agent Host).
- `tools/create-project.py` genera workspace Cargo e sito statico indipendenti.
- `tools/servicess-bootstrap.sh open` installa user-local Codex Security (`@openai/codex-security@0.2.0`) se manca, controlla gli accessi e apre il workspace VS Code multi-root. Il cliente autentica Codex Security con `codex-security login` e GitHub Copilot con `copilot login` solo quando il login manca; non vengono richiesti o salvati token dall'orchestratore.
- `tools/servicess-deploy.sh plan <sito>` produce il manifest; publish richiede hash e dispatcher sudo allowlisted.
- `deployment/README.md` descrive publisher, provisioning, proxy API e backup cifrati.

## Requisiti di avvio
- **Code Agents, non VS Code normale**: il cliente deve aprire Code Agents (host Agents di VS Code); serve per usare il multi-agente.
- **SSH con chiave e password attive**: `PubkeyAuthentication yes` e `PasswordAuthentication yes`. Se la password viene disattivata la piattaforma Code Agents non parte. Non disattivarla; la protezione e' il jail fail2ban `sshd`.

Il bootstrap non invia un messaggio Copilot in automatico: VS Code CLI non supporta la selezione/invio di un agente custom. Il primo turno dell'agente `servicess-orchestrator`, una volta selezionato, pone solo la domanda prevista. Il dispatcher admin è sorgente non installata e richiede autorizzazione/revoca dei grant `NOPASSWD: ALL` preesistenti.
