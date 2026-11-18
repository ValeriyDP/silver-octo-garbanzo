#!/usr/bin/env bash
# Ensure a vault project's qmd collection exists, then embed + update.
# Agents run this after page add/edit. There are no hooks.
# Usage: qmd-sync.sh [PROJECT_DIR]
set -euo pipefail

PROJECT="${1:-$PWD}"
CONFIG=""
for candidate in "$PROJECT/.qmd-collection" "$PROJECT/qmd-collection"; do
  if [[ -f "$candidate" ]]; then
    CONFIG="$candidate"
    break
  fi
done

if [[ -z "$CONFIG" ]]; then
  echo "qmd-sync: no qmd-collection in $PROJECT" >&2
  exit 0
fi

export PATH="${HOME}/.nvm/versions/node/v22.22.0/bin:/opt/homebrew/bin:/usr/local/bin:${PATH}"
if ! command -v qmd >/dev/null 2>&1; then
  if [[ -s "${HOME}/.nvm/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    . "${HOME}/.nvm/nvm.sh"
  fi
fi
if ! command -v qmd >/dev/null 2>&1; then
  echo "qmd-sync: qmd is not on PATH" >&2
  exit 1
fi

NAME=""
CONTEXT=""
MASK="**/*.md"
REL_PATH=""

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  case "$key" in
    name) NAME="$value" ;;
    context) CONTEXT="$value" ;;
    mask) MASK="$value" ;;
    path) REL_PATH="$value" ;;
  esac
done < "$CONFIG"

if [[ -z "$NAME" ]]; then
  echo "qmd-sync: missing name= in $CONFIG" >&2
  exit 1
fi

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/qmd/sync"
mkdir -p "$CACHE"
LOCK="$CACHE/${NAME}.lock"
PENDING="$CACHE/${NAME}.pending"
LOG="$CACHE/${NAME}.log"

if ! mkdir "$LOCK" 2>/dev/null; then
  if [[ -d "$LOCK" ]]; then
    lock_age=0
    if stat_mtime=$(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK" 2>/dev/null); then
      lock_age=$(( $(date +%s) - stat_mtime ))
    fi
    if (( lock_age < 1800 )); then
      touch "$PENDING"
      echo "qmd-sync: $NAME already running; queued" >&2
      exit 0
    fi
    rm -rf "$LOCK"
    mkdir "$LOCK"
  fi
fi

cleanup() {
  rm -rf "$LOCK"
}
trap cleanup EXIT

sleep "${QMD_SYNC_DEBOUNCE:-8}"

INDEX_PATH="$PROJECT"
if [[ -n "$REL_PATH" ]]; then
  INDEX_PATH="$PROJECT/$REL_PATH"
fi

{
  echo "---- $(date -u +%Y-%m-%dT%H:%M:%SZ) $NAME ----"
  if ! qmd collection list | grep -Fq "$NAME ("; then
    qmd collection add "$INDEX_PATH" --name "$NAME" --mask "$MASK"
    if [[ -n "$CONTEXT" ]] && ! qmd context list | grep -Fq "$NAME"; then
      qmd context add "qmd://${NAME}" "$CONTEXT"
    fi
  elif [[ -n "$CONTEXT" ]] && ! qmd context list | grep -Fq "$NAME"; then
    qmd context add "qmd://${NAME}" "$CONTEXT"
  fi
  qmd update
  qmd embed
} >>"$LOG" 2>&1

if [[ -f "$PENDING" ]]; then
  rm -f "$PENDING"
  echo "qmd-sync: $NAME had queued edits; running again" >&2
  exec "$0" "$PROJECT"
fi
