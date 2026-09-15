#!/usr/bin/env bash
#
# Undoes install.sh: puts the original files back from the backups and removes
# the local assets.
#
# A file is restored only if it is still exactly as install.sh left it. If a
# package update replaced it since, the stock file is already back and it is
# left alone. If it was edited by hand and still uses the local assets, it is
# reported and the assets stay until it is sorted out.
#
set -euo pipefail

WEBROOT=${WEBROOT:-/var/www/html}
STATE_DIR=${STATE_DIR:-/var/lib/issabel5-local-assets}
A=/issabel5-local-assets
ASSET_DIR=$WEBROOT${A}
MANIFEST=$STATE_DIR/manifest

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

[[ -f $MANIFEST ]] || { log "not installed (no $MANIFEST)"; exit 0; }
[[ -w $WEBROOT ]] || { echo "ERROR: no write access to $WEBROOT - run as root" >&2; exit 1; }

pending=$(mktemp)
trap 'rm -f "$pending"' EXIT

while IFS=$'\t' read -r file sum; do
  backup=$STATE_DIR/backup$file
  if [[ -f $file && -f $backup && $(sha256sum "$file" | cut -d' ' -f1) == "$sum" ]]; then
    cat "$backup" > "$file"
    log "restored $file"
  elif [[ -f $file ]] && grep -qF "$A/" "$file"; then
    warn "skipped  $file (edited since it was patched - fix it by hand, then run again)"
    printf '%s\t%s\n' "$file" "$sum" >> "$pending"
  else
    log "left     $file (replaced since it was patched, e.g. by a package update)"
  fi
done < "$MANIFEST"

if [[ -s $pending ]]; then
  cp "$pending" "$MANIFEST"
  warn "keeping $ASSET_DIR while the files above still use it"
  exit 1
fi

if grep -rqIF "$A/" "$WEBROOT" --exclude-dir=templates_c --exclude-dir="${A#/}" 2>/dev/null; then
  warn "keeping $ASSET_DIR - still referenced by files install.sh did not patch:"
  grep -rlIF "$A/" "$WEBROOT" --exclude-dir=templates_c --exclude-dir="${A#/}" >&2 || true
  rm -rf "$STATE_DIR"
  exit 1
fi

rm -rf "$ASSET_DIR" "$STATE_DIR"
log "removed $ASSET_DIR and $STATE_DIR"
