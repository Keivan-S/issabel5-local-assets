#!/usr/bin/env bash
#
# Makes the Issabel 5 web UI load Noto Sans from the PBX itself instead of
# fonts.googleapis.com / fonts.gstatic.com.
#
#   bash install.sh             apply the patch
#   bash install.sh --dry-run   show what would change, touch nothing
#
# Safe to run again at any time. Run it again after `yum update`: an updated
# issabel-framework / issabel-reports / issabelPBX package brings back the
# stock templates, and with them the Google Fonts links.
#
set -euo pipefail

WEBROOT=${WEBROOT:-/var/www/html}
STATE_DIR=${STATE_DIR:-/var/lib/issabel-local-fonts}

# The fonts sit next to the rest of the tenant theme's assets (it already has
# a fonts/ folder). Not a new folder directly under themes/: Issabel lists
# every directory there as a selectable theme.
FONT_DIR=$WEBROOT/themes/tenant/fonts/noto-sans
FONT_URL=/themes/tenant/fonts/noto-sans/noto-sans.css

SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fonts/noto-sans
MANIFEST=$STATE_DIR/manifest

DRY_RUN=0
case ${1:-} in
  '')        ;;
  --dry-run) DRY_RUN=1 ;;
  *)         echo "usage: $0 [--dry-run]" >&2; exit 2 ;;
esac

GOOGLE_RE='fonts\.(googleapis|gstatic)\.com'

# 1. <link rel="preconnect|dns-prefetch" href="https://fonts.g...">: dropped
#    (whole line when it is the only thing on it, otherwise just the tag).
# 2. Noto Sans stylesheet URLs (css and css2 API, http/https/protocol-less, in
#    href="..." or @import url(...)): pointed at the local noto-sans.css.
#    Other families are left alone and reported at the end.
HINT_TAG="<link[^>]*(preconnect|dns-prefetch)[^>]*${GOOGLE_RE}[^>]*>|<link[^>]*${GOOGLE_RE}[^>]*(preconnect|dns-prefetch)[^>]*>"
SED_SCRIPT="
/^[[:space:]]*(${HINT_TAG})[[:space:]]*$/d
s#${HINT_TAG}##g
s#(https?:)?//fonts\.googleapis\.com/css2?\?family=Noto\+Sans(:[^\"'&) ]*)?(&[^\"') ]*)?([\"') ])#${FONT_URL}\4#g
"

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -d $WEBROOT/themes/tenant ]] || die "$WEBROOT/themes/tenant not found - is this an Issabel 5 server?"
[[ -f $SRC_DIR/noto-sans.css ]] || die "font files missing in $SRC_DIR"
if (( ! DRY_RUN )); then
  [[ -w $WEBROOT ]] || die "no write access to $WEBROOT - run as root"
fi

# Every text file in the web root that mentions Google Fonts. Compiled Smarty
# templates are skipped: Smarty rebuilds them once the .tpl mtime changes.
find_google_refs() {
  grep -rlIE "$GOOGLE_RE" "$WEBROOT" \
    --include='*.tpl' --include='*.php' --include='*.html' --include='*.htm' --include='*.css' \
    --exclude-dir=templates_c 2>/dev/null || true
}

record() {  # record <file>: remember the checksum we left the file with
  local file=$1 sum
  sum=$(sha256sum "$file" | cut -d' ' -f1)
  touch "$MANIFEST"
  grep -vF "$file"$'\t' "$MANIFEST" > "$MANIFEST.tmp" || true
  printf '%s\t%s\n' "$file" "$sum" >> "$MANIFEST.tmp"
  mv "$MANIFEST.tmp" "$MANIFEST"
}

# --- fonts --------------------------------------------------------------------
if (( DRY_RUN )); then
  log "would copy fonts to $FONT_DIR"
else
  install -d -m 0755 "$FONT_DIR"
  install -m 0644 "$SRC_DIR"/* "$FONT_DIR"/
  command -v restorecon >/dev/null 2>&1 && restorecon -R "$FONT_DIR" 2>/dev/null || true
  log "fonts installed in $FONT_DIR"
fi

# --- templates ----------------------------------------------------------------
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

patched=0
mapfile -t files < <(find_google_refs)
# ${a[@]+...}: bash 4.2 (CentOS 7) calls an empty array unbound under set -u.
for file in ${files[@]+"${files[@]}"}; do
  sed -r "$SED_SCRIPT" "$file" > "$tmp"
  cmp -s "$file" "$tmp" && continue   # only non-Noto references, reported below

  if (( DRY_RUN )); then
    diff -u "$file" "$tmp" || true
  else
    # Keep the pre-patch file for uninstall.sh. Refreshed on every patch, so
    # after a package update the backup is the new stock file, not an old one.
    mkdir -p "$STATE_DIR/backup$(dirname "$file")"
    cp -p "$file" "$STATE_DIR/backup$file"
    # Write in place: keeps owner, mode and SELinux label of the original.
    cat "$tmp" > "$file"
    record "$file"
    log "patched  $file"
  fi
  patched=$((patched + 1))
done

# --- report -------------------------------------------------------------------
if (( patched == 0 )); then
  log "nothing to patch - templates already use the local fonts"
elif (( DRY_RUN )); then
  log "$patched file(s) would be patched"
else
  log "$patched file(s) patched; backups in $STATE_DIR/backup"
fi

if (( ! DRY_RUN )); then
  mapfile -t left < <(find_google_refs)
  if (( ${#left[@]} )); then
    warn "these files still reference Google Fonts (not Noto Sans, left untouched):"
    grep -nHE "$GOOGLE_RE" "${left[@]}" >&2 || true
  fi
fi
