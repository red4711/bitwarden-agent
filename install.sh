#!/usr/bin/env bash
# install.sh — one-line installer for bitwarden-agent (bwa).
#
#   curl -fsSL https://raw.githubusercontent.com/red4711/bitwarden-agent/master/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --bws --skill-dir ~/workspace/skills
#
# Installs: bwa + bwa-onboard into $PREFIX/bin, lib files into $PREFIX/lib,
# the `bw` CLI via npm (global --prefix, no sudo), optionally the `bws` CLI,
# and optionally the drop-in Muse skill.

set -euo pipefail

PREFIX="${HOME}/.local"
WITH_BWS=0
SKILL_DIR=""
REPO_URL="https://github.com/red4711/bitwarden-agent"

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)    PREFIX="$2"; shift 2 ;;
    --bws)       WITH_BWS=1; shift ;;
    --skill-dir) SKILL_DIR="$2"; shift 2 ;;
    --repo)      REPO_URL="$2"; shift 2 ;;
    -h|--help)
      cat >&2 <<'HELPEOF'
install.sh — install bitwarden-agent (bwa).
Options:
  --prefix DIR       install prefix (default: $HOME/.local)
  --bws              also install the Secrets Manager CLI
  --skill-dir DIR    install the drop-in Muse skill here
                     (default: $HOME/workspace/skills, if it exists)
  --repo URL         repo to install from
                     (default: github.com/red4711/bitwarden-agent)
HELPEOF
      exit 0 ;;
    *) echo "install.sh: unknown option '$1'" >&2; exit 1 ;;
  esac
done

log() { printf 'install: %s\n' "$*" >&2; }
die() { printf 'install: error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

have curl || die "curl is required"
[ -n "${BASH_VERSION:-}" ] || die "bash is required"

# ---- fetch the repo ----
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
if [ -f "$(dirname "$0")/bin/bwa" ]; then
  SRC="$(cd "$(dirname "$0")" && pwd)"
  log "using local checkout: $SRC"
elif have git; then
  log "cloning $REPO_URL ..."
  git clone --depth 1 --quiet "$REPO_URL" "$TMPDIR/repo" \
    || die "git clone failed"
  SRC="$TMPDIR/repo"
else
  log "downloading tarball ..."
  curl -fsSL "$REPO_URL/archive/refs/heads/master.tar.gz" \
    | tar -xz -C "$TMPDIR" || die "tarball download failed"
  SRC="$TMPDIR/bitwarden-agent-master"
fi
[ -f "$SRC/bin/bwa" ] || die "repo layout unexpected (bin/bwa missing)"

# ---- install bwa ----
mkdir -p "$PREFIX/bin" "$PREFIX/lib"
install -m 755 "$SRC/bin/bwa" "$PREFIX/bin/bwa"
install -m 755 "$SRC/bin/bwa-onboard" "$PREFIX/bin/bwa-onboard"
install -m 644 "$SRC/lib/bwa-common.sh" "$PREFIX/lib/bwa-common.sh"
install -m 644 "$SRC/lib/bwa-backends.sh" "$PREFIX/lib/bwa-backends.sh"
log "installed bwa $("$PREFIX/bin/bwa" version) to $PREFIX/bin"

# ---- bw CLI ----
if have bw; then
  log "bw CLI already present: $(bw --version 2>/dev/null)"
elif have npm; then
  log "installing @bitwarden/cli via npm (prefix $PREFIX) ..."
  npm install -g --prefix "$PREFIX" @bitwarden/cli --no-audit --no-fund \
    || die "npm install failed"
else
  log "WARNING: node/npm not found, skipping bw CLI install."
  log "Install node, then run: npm install -g --prefix \"$PREFIX\" @bitwarden/cli"
fi

# ---- bws CLI (optional) ----
if [ "$WITH_BWS" -eq 1 ]; then
  if have bws; then
    log "bws CLI already present"
  else
    log "installing bws via official installer ..."
    curl -fsSL https://bws.bitwarden.com/install | sh \
      || die "bws install failed"
    have bws || log "WARNING: bws installed but not on PATH — add its bin dir to PATH"
  fi
fi

have jq || log "WARNING: jq not found — bwa item commands need it."

# ---- drop-in skill ----
if [ -z "$SKILL_DIR" ] && [ -d "$HOME/workspace/skills" ]; then
  SKILL_DIR="$HOME/workspace/skills"   # Muse workspace layout
fi
if [ -n "$SKILL_DIR" ]; then
  mkdir -p "$SKILL_DIR/bitwarden-agent"
  install -m 644 "$SRC/skill/SKILL.md" "$SKILL_DIR/bitwarden-agent/SKILL.md"
  log "installed skill to $SKILL_DIR/bitwarden-agent/SKILL.md"
fi

# ---- done ----
cat >&2 <<EOF

Done. Next:
  1. Ensure $PREFIX/bin is on your PATH:
       export PATH="\$HOME/.local/bin:\$PATH"
  2. Run the interactive setup:
       bwa onboard
  3. Then: bwa status | bwa list | bwa get "name" --field password

Docs: $REPO_URL
EOF
