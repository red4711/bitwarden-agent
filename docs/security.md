# Security model

`bwa` is a thin, opinionated wrapper around the official Bitwarden CLIs
(`bw`, `bws`). It does not implement any cryptography itself; all
encryption stays inside Bitwarden's clients and servers.

## What the tool guarantees

- **Secrets travel only via process environment or hidden prompts.**
  `bwa` never writes a secret to disk, never echoes one to the terminal,
  and never enables shell tracing (`set -x`).
- **The config file holds no secrets** — only backend, server URL, auth
  method, email label, and project id. It is still written `0600`.
- **Interactive prompts hide input** (`stty -echo`) and the wizard
  unsets secret variables from its own shell after the smoke test.

## What the tool does NOT protect against (know the tradeoffs)

- **Environment visibility.** A process's environment is readable by
  other processes running as the same user (`/proc/<pid>/environ`).
  On a single-user agent VM this is the accepted standard (same as
  `direnv`, `op run`, CI secret injection). On a shared machine, prefer
  interactive use or a dedicated service account.
- **Argument visibility.** `bws secret create <key> <value>` passes the
  value as an argument, briefly visible in the process list to the same
  user. Same caveat as above.
- **Persisted sessions.** `bwa session --persist` stores a session key in
  a `0600` file. Anyone who can read that file can read your vault until
  the session is revoked (password change, logout). It exists for cron
  jobs that cannot prompt; the default is per-invocation unlock from the
  environment, with nothing secret at rest.
- **The CLIs' own caches.** `bw login` persists Bitwarden-issued tokens
  in `~/.config/Bitwarden CLI/data.json` (that is the official CLI's
  doing, not bwa's). Protect your home directory accordingly.

## Agent transcript hygiene

When an AI agent uses `bwa`, retrieved values flow through the agent's
context. Rules shipped in `skill/SKILL.md`:

1. `bwa list` (names only) for discovery; `bwa get` only for the value
   the current step needs.
2. Prefer `bwa exec -- <script>`: the script calls `bwa get` itself, so
   values stay inside the subprocess instead of the transcript.
3. Never write values to files, memory, goals, logs, or chat replies.

## Least privilege on the server side

- **Vaultwarden / self-hosted:** use a dedicated bot account inside an
  organization, granted access to exactly one collection. The agent can
  then never see the owner's personal vault. (`bwa onboard` prints this
  checklist for self-hosted setups.)
- **Bitwarden cloud + Secrets Manager:** use a machine account scoped to
  one project with only the access it needs (read vs read/write).
- **API keys:** treat `client_id`/`client_secret` and access tokens like
  passwords. They are shown once; store the backup with your emergency
  sheet, not in the repo.

## Rotation and revocation

- Rotate the master password / API key / access token in the web vault;
  then re-run `bwa onboard` (or `bwa session --clear` + unlock again).
- A compromised session file: `bwa session --clear`, then change the
  master password to invalidate all sessions.
- The repo itself contains no credentials. CI runs only `bash -n`
  syntax checks — never a live login.
