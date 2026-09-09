#!/usr/bin/env bash
# bwa-common.sh — shared helpers for the bwa CLI.
# Sourced by bin/bwa and bin/bwa-onboard. Not meant to be executed directly.
#
# Security posture: secrets travel ONLY via process environment or hidden
# interactive prompts. This file (and everything in bwa) never writes a
# secret to disk, never echoes one, and never enables `set -x`.

set -euo pipefail

BWA_CONFIG_DIR="${BWA_CONFIG_DIR:-$HOME/.config/bitwarden-agent}"
BWA_CONFIG_FILE="$BWA_CONFIG_DIR/config"
BWA_SESSION_FILE="${BWA_SESSION_FILE:-$BWA_CONFIG_DIR/session}"

bwa_log() { printf 'bwa: %s\n' "$*" >&2; }
bwa_err() { printf 'bwa: error: %s\n' "$*" >&2; }
bwa_die() { bwa_err "$*"; exit 1; }

# Load $BWA_CONFIG_FILE (written only by `bwa onboard`). No secrets live there.
bwa_config_load() {
  [ -f "$BWA_CONFIG_FILE" ] \
    || bwa_die "not configured — run 'bwa onboard' first (missing $BWA_CONFIG_FILE)"
  # shellcheck disable=SC1090
  . "$BWA_CONFIG_FILE"
  : "${BWA_BACKEND:?config is missing BWA_BACKEND}"
  : "${BWA_SERVER:?config is missing BWA_SERVER}"
  : "${BWA_AUTH:?config is missing BWA_AUTH}"
}

# Require an env var to be set; $2 is a human hint shown on failure.
bwa_require_env() {
  local var="$1" hint="${2:-}"
  if [ -z "${!var:-}" ]; then
    bwa_die "$var is not set. ${hint}"
  fi
}

# Hidden prompt. Result lands in $REPLY_RAW. Nothing is echoed or logged.
bwa_prompt_secret() {
  local prompt="$1" val=""
  printf '%s: ' "$prompt" >&2
  if [ -t 0 ]; then stty -echo 2>/dev/null || true; fi
  IFS= read -r val || true
  if [ -t 0 ]; then stty echo 2>/dev/null || true; fi
  printf '\n' >&2
  REPLY_RAW="$val"
}

# Visible prompt with optional default. Result lands in $REPLY_RAW.
bwa_prompt() {
  local prompt="$1" def="${2:-}" val=""
  if [ -n "$def" ]; then
    printf '%s [%s]: ' "$prompt" "$def" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi
  IFS= read -r val || true
  REPLY_RAW="${val:-$def}"
}

# Yes/no prompt. Returns 0 for yes. Result also in $REPLY_YN.
bwa_prompt_yn() {
  local prompt="$1" def="${2:-y}" val=""
  printf '%s [%s]: ' "$prompt" "$def" >&2
  IFS= read -r val || true
  val="${val:-$def}"
  REPLY_YN="$val"
  case "$val" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

bwa_have() { command -v "$1" >/dev/null 2>&1; }
