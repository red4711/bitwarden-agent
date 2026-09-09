---
name: "bitwarden-agent"
description: "Use Bitwarden (cloud or self-hosted Vaultwarden) as the agent's operational secret store via the bwa CLI: get, list, create, edit, and delete secrets. Use when the task involves retrieving or storing service credentials, API tokens, generated passwords, or any secret the agent manages itself. Not for the user's website logins — those stay in the Secure Vault."
---

# Bitwarden Agent Skill

## Purpose

`bwa` gives the agent its own credential store, separate from the user's Secure Vault. The agent has full read/write here: it can generate and store service credentials (homelab API tokens, webhook secrets, deploy keys) without asking the user, and fetch them at runtime. The Secure Vault remains the user-facing store for website logins and stays approval-gated and read-never.

## Tooling

`bwa` must be installed (`install.sh` in the repo, or `bwa doctor` to verify). It must have been configured once via `bwa onboard`.

- `bwa status` — backend, server, login/session state. Run first when unsure.
- `bwa sync` — pull latest vault state (bw backend; bws is stateless).
- `bwa list` — names only, no values. Prefer this for discovery.
- `bwa get NAME [--field F]` — fetch one item. bw fields: `username`, `password`, `uri`, `notes`, `totp`, or a custom-field name; default prints full item JSON. bws default field is `value`.
- `bwa create NAME [--username U] [--password P | --generate] [--url URL] [--notes T] [--folder F] [--field k=v]` — bw backend. bws: `--value V | --generate [--length N] [--note T]`.
- `bwa edit NAME [same flags]` / `bwa delete NAME [--yes]`
- `bwa exec -- CMD [ARGS...]` — run CMD with the session in its environment. **Prefer this** when a script needs secrets: values stay inside the subprocess instead of flowing through the transcript.
- `bwa session --persist | --clear` — opt-in 0600 session file for cron jobs.

Backends: `bw` works against Bitwarden cloud (US/EU) and self-hosted Vaultwarden, with API-key or email+password auth. `bws` (Secrets Manager machine token) is Bitwarden cloud only — Vaultwarden does not implement that API.

## Auth

`bwa` reads auth material **only** from the environment — never from files, chat, or memory:

- bw backend: `BW_CLIENTID` + `BW_CLIENTSECRET` (API key) and/or `BW_PASSWORD` (master password — always required to *unlock*, even with API-key login). Non-secret identity (`BWA_EMAIL`) lives in the config file.
- bws backend: `BWS_ACCESS_TOKEN`, optional `BWS_SERVER_URL` / `BWS_PROJECT_ID`.

In Muse, store the material with `credentials.request_api_access` (one connector per value) and inject it at runtime with the scaffolded helper before invoking `bwa`. A persisted session file (`bwa session --persist`, 0600) is the alternative for cron-style jobs: one unlock, then no secret in the environment at all. Never paste values in chat.

## Operating Rules

1. Fetch a secret only into the command that needs it. Do not write values to files, memory notes, goals, logs, or messages — including your own reply text.
2. `bwa list` before `bwa get`: discover names first, pull values only when needed.
3. After writes, run `bwa sync` so other clients see the change.
4. Treat `bwa get` output as sensitive in transit: pass it straight into the tool call that needs it (e.g. an env var for one exec), don't restate it.
5. The user's website logins are NOT here. If a task needs a site login, that is the Secure Vault + browser fill flow, not `bwa`.
6. If `bwa` reports a stale session or failed login, run `bwa status` / `bwa doctor` and surface the blocker to the user — do not ask the user to paste secrets in chat; use the approved secure-entry flow.
