# bitwarden-agent

`bwa` — Bitwarden as an operational secret store for AI agents (and humans).

Agents need somewhere to keep the secrets *they* manage — homelab API tokens,
webhook secrets, generated passwords — without pestering the human every time.
`bwa` is a small, opinionated wrapper around the official Bitwarden CLIs that
makes that safe and boring: secrets travel only via environment or hidden
prompts, an interactive wizard walks through setup, and a drop-in skill teaches
Muse agents the operating rules.

## Quickstart

```bash
# one-line install (bwa + bw CLI; add --bws for Secrets Manager CLI)
curl -fsSL https://raw.githubusercontent.com/red4711/bitwarden-agent/master/install.sh | bash

export PATH="$HOME/.local/bin:$PATH"

# interactive setup wizard: server x auth matrix, smoke-tested
bwa onboard

# use it
bwa status
bwa list
bwa get "proxmox-api" --field password
bwa create "webhook-secret" --generate --notes "deploys"
bwa exec -- ./deploy.sh        # secrets stay inside the subprocess
```

## Backend matrix

One tool, two Bitwarden products, both auth styles:

| backend | server | auth | notes |
|---|---|---|---|
| `bw` | Bitwarden cloud (US/EU) | API key **or** email+password | API-key login skips the 2FA prompt; unlock still needs the master password |
| `bw` | self-hosted **Vaultwarden** | API key **or** email+password | same CLI; Vaultwarden reimplements the password-manager API |
| `bws` | Bitwarden cloud only | machine access token | Secrets Manager; single token, no unlock step |

Vaultwarden does **not** implement the Secrets Manager API (it's a licensed
Bitwarden feature), so `bws` is cloud-only. For Vaultwarden, the equivalent of
a machine account is a dedicated bot user inside an organization, granted access
to exactly one collection — `bwa onboard` prints that checklist for
self-hosted setups. See [docs/security.md](docs/security.md).

## The onboarding flow

`bwa onboard` asks four things, then proves it works:

1. **Backend** — `bw` (universal, recommended) or `bws` (cloud Secrets Manager).
2. **Server** — Bitwarden US / EU cloud, or your Vaultwarden URL.
3. **Auth** — API key (recommended for machines) or email + password.
4. **Secrets** — collected via hidden prompts, used once, never written to disk.

It then writes a secret-free config (`~/.config/bitwarden-agent/config`),
runs a live smoke test (login → unlock → sync → count items), and optionally
persists a `0600` session key for cron jobs.

## For Muse agents

The repo ships a drop-in skill at `skill/SKILL.md` — copy it to
`~/workspace/skills/bitwarden-agent/SKILL.md` (the installer does this with
`--skill-dir`). It covers the tool commands, the env-only auth wiring (via the
Secure Vault connector in Muse), and the operating rules: list names before
fetching values, prefer `bwa exec`, never write values to files/memory/chat.

## Scheduled jobs

```cron
# keep the vault warm (bw backend)
*/15 * * * * /home/user/.local/bin/bwa sync >/dev/null 2>&1
```

With a persisted session (`bwa session --persist`), cron jobs need no secret
in the environment at all.

## Layout

```
bin/bwa            main CLI: get/list/create/edit/delete/sync/status/session/exec
bin/bwa-onboard    interactive setup wizard
lib/               shared helpers + backend matrix (bw/bws)
install.sh         one-line installer (+ optional bws CLI and skill install)
skill/SKILL.md     drop-in Muse skill
docs/security.md   threat model and operating rules
```

## Security

Short version: secrets only via env or hidden prompts, never on disk (unless
you opt into `bwa session --persist`), never echoed, config holds no secrets.
Long version: [docs/security.md](docs/security.md).

## License

MIT — see [LICENSE](LICENSE).
