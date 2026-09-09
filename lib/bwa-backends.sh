#!/usr/bin/env bash
# bwa-backends.sh — backend matrix for bwa.
#
# Backends:
#   bw   Bitwarden password-manager CLI. Universal: works against Bitwarden
#        cloud (US/EU) AND self-hosted Vaultwarden, because Vaultwarden
#        reimplements the password-manager client API. (Vaultwarden does NOT
#        implement the Secrets Manager API — see docs/backends.md.)
#   bws  Bitwarden Secrets Manager CLI. Bitwarden cloud only. Single access
#        token, no master password, no unlock step.
#
# Auth (bw backend):
#   apikey    BW_CLIENTID + BW_CLIENTSECRET for `bw login --apikey`.
#             Skips the 2FA prompt. NOTE: `bw unlock` still needs the master
#             password (BW_PASSWORD) — API-key login authenticates you, the
#             master password decrypts the vault. Zero-knowledge design.
#   password  BWA_EMAIL + BW_PASSWORD for `bw login`.

bwa_bw_server_apply() {
  local cur
  cur="$(bw config server 2>/dev/null || true)"
  if [ "$cur" != "$BWA_SERVER" ]; then
    if bw login --check >/dev/null 2>&1; then
      bwa_die "already logged into a different server ($cur). Run 'bw logout' first, then retry."
    fi
    bwa_log "pointing bw CLI at $BWA_SERVER"
    bw config server "$BWA_SERVER" >/dev/null
  fi
}

bwa_bw_login_ensure() {
  if bw login --check >/dev/null 2>&1; then return 0; fi
  bwa_log "logging in ($BWA_AUTH) ..."
  case "$BWA_AUTH" in
    apikey)
      bwa_require_env BW_CLIENTID "export BW_CLIENTID (account Settings -> Security -> Keys -> API key)"
      bwa_require_env BW_CLIENTSECRET "export BW_CLIENTSECRET (same page as above)"
      bw login --apikey
      ;;
    password)
      : "${BWA_EMAIL:?config is missing BWA_EMAIL}"
      bwa_require_env BW_PASSWORD "export BW_PASSWORD"
      bw login "$BWA_EMAIL" --passwordenv BW_PASSWORD
      ;;
    *) bwa_die "unknown BWA_AUTH '$BWA_AUTH' (want: apikey|password)" ;;
  esac
}

# Cheap local probe: succeeds only when the vault is unlocked for this session.
bwa_bw_session_valid() {
  bw list folders --session "${BW_SESSION:-__none__}" >/dev/null 2>&1
}

bwa_bw_unlock_from_env() {
  bwa_require_env BW_PASSWORD \
    "the master password is required to unlock the vault (yes, even with API-key login)"
  BW_SESSION="$(bw unlock --raw --passwordenv BW_PASSWORD)"
  export BW_SESSION
}

bwa_bw_session_ensure() {
  if [ -n "${BW_SESSION:-}" ]; then
    export BW_SESSION
    bwa_bw_session_valid \
      || bwa_die "BW_SESSION is set but rejected (locked?). Unset it and retry."
    return 0
  fi
  if [ -f "$BWA_SESSION_FILE" ]; then
    BW_SESSION="$(cat "$BWA_SESSION_FILE")"
    export BW_SESSION
    if bwa_bw_session_valid; then return 0; fi
    bwa_log "stored session is stale; re-unlocking from environment"
  fi
  bwa_bw_unlock_from_env
}

bwa_bws_ensure() {
  bwa_have bws \
    || bwa_die "bws CLI not found. Install it: curl -fsSL https://bws.bitwarden.com/install | sh"
  bwa_require_env BWS_ACCESS_TOKEN \
    "export BWS_ACCESS_TOKEN (Secrets Manager -> Machine accounts -> Access tokens)"
  if [ -n "${BWS_SERVER_URL:-}" ]; then export BWS_SERVER_URL; fi
}

# Ensure the configured backend is ready. Exports BW_SESSION (bw) or
# BWS_ACCESS_TOKEN/BWS_SERVER_URL (bws) for the calling process.
bwa_backend_ensure() {
  case "$BWA_BACKEND" in
    bw)
      bwa_have bw \
        || bwa_die "bw CLI not found. Install it: npm install -g --prefix \"\$HOME/.local\" @bitwarden/cli"
      bwa_bw_server_apply
      bwa_bw_login_ensure
      bwa_bw_session_ensure
      ;;
    bws)
      bwa_bws_ensure
      ;;
    *)
      bwa_die "unknown BWA_BACKEND '$BWA_BACKEND' (want: bw|bws)"
      ;;
  esac
}
