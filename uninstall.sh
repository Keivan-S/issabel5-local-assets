#!/usr/bin/env bash
#
# Undoes install.sh: puts the original templates back and removes the local
# font files.
#
# A template is restored only if it is still exactly as install.sh left it.
# If a package update replaced it since, the stock file is already back and
# it is left alone. If it was edited by hand and still uses the local fonts,
# it is reported and the fonts stay until it is sorted out.
#
set -euo pipefail

WEBROOT=${WEBROOT:-/var/www/html}
STATE_DIR=${STATE_DIR:-/var/lib/issabel-local-fonts}
FONT_DIR=$WEBROOT/themes/tenant/fonts/noto-sans
FONT_URL=/themes/tenant/fonts/noto-sans/noto-sans.css
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
  elif [[ -f $file ]] && grep -qF "$FONT_URL" "$file"; then
    warn "skipped  $file (edited since it was patched - fix it by hand, then run again)"
    printf '%s\t%s\n' "$file" "$sum" >> "$pending"
  else
    log "left     $file (replaced since it was patched, e.g. by a package update)"
  fi
done < "$MANIFEST"

if [[ -s $pending ]]; then
  cp "$pending" "$MANIFEST"
  warn "keeping $FONT_DIR while the files above still use it"
  exit 1
fi

if grep -rqIF "$FONT_URL" "$WEBROOT" --exclude-dir=templates_c 2>/dev/null; then
  warn "keeping $FONT_DIR - still referenced by files install.sh did not patch:"
  grep -rlIF "$FONT_URL" "$WEBROOT" --exclude-dir=templates_c >&2 || true
  rm -rf "$STATE_DIR"
  exit 1
fi

rm -rf "$FONT_DIR" "$STATE_DIR"
log "removed $FONT_DIR and $STATE_DIR"
