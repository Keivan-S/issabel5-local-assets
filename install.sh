#!/usr/bin/env bash
#
# issabel5-local-assets: makes the Issabel 5 web UI load its fonts, icons and
# JS/CSS libraries from the PBX itself instead of Google and other CDNs.
#
#   bash install.sh             apply the patch
#   bash install.sh --dry-run   show what would change, touch nothing
#
# Safe to run again at any time. Run it again after updating the Issabel
# packages (yum/dnf update): they bring back the stock files, and with them
# the CDN links.
#
set -euo pipefail

WEBROOT=${WEBROOT:-/var/www/html}
STATE_DIR=${STATE_DIR:-/var/lib/issabel5-local-assets}

# Served as https://<pbx>/issabel5-local-assets/. A folder of its own in the
# web root, named after the package so nobody wonders where it came from.
A=/issabel5-local-assets
ASSET_DIR=$WEBROOT${A}

SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/assets
MANIFEST=$STATE_DIR/manifest

DRY_RUN=0
case ${1:-} in
  '')        ;;
  --dry-run) DRY_RUN=1 ;;
  *)         echo "usage: $0 [--dry-run]" >&2; exit 2 ;;
esac

# --- what gets replaced -------------------------------------------------------
# Triples of: kind, text as found in Issabel, replacement.
#   url   the http:, https: and protocol-relative (//) forms all match
#   text  exact text
RULES=(
  # IssabelPBX admin (admin/views/header.php): Font Awesome 4.7.0. The
  # framework's own copy in libs/font-icons is 4.4.0 and lacks newer icons.
  url  'maxcdn.bootstrapcdn.com/font-awesome/4.7.0/css/font-awesome.min.css'
       "$A/font-awesome-4.7.0/css/font-awesome.min.css"
  # IssabelPBX admin (admin/views/issabelpbx.php): jQuery UI. Its local
  # fallback, assets/js/jquery-ui-1.8.x.min.js, is not shipped.
  url  'ajax.googleapis.com/ajax/libs/jqueryui/1.8.9/jquery-ui.min.js'
       "$A/jquery-ui-1.8.9/jquery-ui.min.js"
  # IssabelPBX admin (admin/views/header.php): jQuery from Google when the
  # "Use Google Distribution Network for js Downloads" setting is on. Point it
  # at the copy the admin already ships (the same file its fallback loads).
  text "//ajax.googleapis.com/ajax/libs/jquery/' . \$amp_conf['JQUERY_VER'] . '/jquery.min.js"
       "assets/js/jquery-' . \$amp_conf['JQUERY_VER'] . '.min.js"
  # IssabelPBX admin (admin/views/footer.php): Chrome Frame, Internet Explorer only.
  url  'ajax.googleapis.com/ajax/libs/chrome-frame/1/CFInstall.min.js'
       "$A/chrome-frame-1/CFInstall.min.js"
  # Login pages of both themes: IE8 polyfills.
  url  'oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js'
       "$A/html5shiv-3.7.0/html5shiv.js"
  url  'oss.maxcdn.com/libs/respond.js/1.4.2/respond.min.js'
       "$A/respond-1.4.2/respond.min.js"
  # PBX -> Monitoring audio player icons (gone from 521dimensions.com, 404).
  url  '521dimensions.com/img/open-source/amplitudejs/examples/single-song/play.svg'
       "$A/amplitudejs/play.svg"
  url  '521dimensions.com/img/open-source/amplitudejs/examples/single-song/pause.svg'
       "$A/amplitudejs/pause.svg"
  # Theme scrollbar (themes/*/js/joinable.js): a Google Maps cursor, only for
  # browsers without the CSS "grab" cursor. Fall back to the cursor it pairs with.
  text 'url(http://www.google.com/intl/en_ALL/mapfiles/openhand.cur),n-resize'
       'n-resize'
)

# Hosts the rules above deal with; used to find candidate files and to report
# anything from them that is still left afterwards.
HOSTS_RE='fonts\.googleapis\.com|fonts\.gstatic\.com|ajax\.googleapis\.com|maxcdn\.bootstrapcdn\.com|oss\.maxcdn\.com|521dimensions\.com/img/|www\.google\.com/intl/en_ALL/mapfiles'

ere_escape()  { printf '%s' "$1" | sed 's,[][\\.*^$+?(){}|#/],\\&,g'; }
repl_escape() { printf '%s' "$1" | sed 's/[\\&#]/\\&/g'; }

# Google Fonts, handled by pattern so any variant of the Noto Sans URL matches
# (css and css2 API, any weights, &display=swap, &amp;), plus the
# <link rel="preconnect|dns-prefetch"> hints to the CDN hosts, which are
# dropped: the whole line when it is the only thing on it, otherwise the tag.
HINT_HOSTS='(fonts\.googleapis|fonts\.gstatic|ajax\.googleapis|maxcdn\.bootstrapcdn|oss\.maxcdn)\.com'
HINT_TAG="<link[^>]*(preconnect|dns-prefetch)[^>]*${HINT_HOSTS}[^>]*>|<link[^>]*${HINT_HOSTS}[^>]*(preconnect|dns-prefetch)[^>]*>"
SED_SCRIPT="
/^[[:space:]]*(${HINT_TAG})[[:space:]]*$/d
s#${HINT_TAG}##g
s#(https?:)?//fonts\.googleapis\.com/css2?\?family=Noto\+Sans(:[^\"'&) ]*)?(&[^\"') ]*)?([\"') ])#$A/noto-sans/noto-sans.css\4#g
"
for ((i = 0; i < ${#RULES[@]}; i += 3)); do
  match=$(ere_escape "${RULES[i+1]}")
  [[ ${RULES[i]} == url ]] && match="(https?:)?//$match"
  SED_SCRIPT+="s#$match#$(repl_escape "${RULES[i+2]}")#g"$'\n'
done

# --- helpers ------------------------------------------------------------------
log()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Text files in the web root that mention one of the hosts. Compiled Smarty
# templates are skipped: Smarty rebuilds them once the .tpl mtime changes.
find_candidates() {
  grep -rlIE "$HOSTS_RE" "$WEBROOT" \
    --include='*.tpl' --include='*.php' --include='*.html' --include='*.htm' \
    --include='*.css' --include='*.js' \
    --exclude-dir=templates_c --exclude-dir="${A#/}" 2>/dev/null || true
}

sum_of() { sha256sum "$1" | cut -d' ' -f1; }

recorded_sum() { awk -F'\t' -v f="$1" '$1 == f { print $2 }' "$MANIFEST"; }

# Back up a file before patching it - unless it is still exactly the version
# we left last time (a newer release of this package adding a rule): then the
# backup we already have is the real original, and it must not be replaced
# by a half-patched copy. A file replaced by a package update gets a fresh
# backup, so uninstall never puts back an outdated file.
backup() {
  local file=$1 saved=$STATE_DIR/backup$1
  if [[ -f $saved && $(recorded_sum "$file") == "$(sum_of "$file")" ]]; then
    return
  fi
  mkdir -p "$(dirname "$saved")"
  cp -p "$file" "$saved"
}

record() {
  local file=$1
  { awk -F'\t' -v f="$file" '$1 != f' "$MANIFEST"; printf '%s\t%s\n' "$file" "$(sum_of "$file")"; } > "$MANIFEST.tmp"
  mv "$MANIFEST.tmp" "$MANIFEST"
}

# --- checks -------------------------------------------------------------------
[[ -d $WEBROOT/themes ]] || die "$WEBROOT/themes not found - is this an Issabel 5 server?"
[[ -f $SRC_DIR/SOURCES.txt ]] || die "assets missing in $SRC_DIR"
if (( ! DRY_RUN )); then
  [[ -w $WEBROOT ]] || die "no write access to $WEBROOT - run as root"
  mkdir -p "$STATE_DIR" && chmod 700 "$STATE_DIR"
  touch "$MANIFEST"
fi

# --- assets -------------------------------------------------------------------
if (( DRY_RUN )); then
  log "would install assets to $ASSET_DIR"
else
  # Build next to the target and swap, so files dropped from a newer release
  # of this package do not linger.
  rm -rf "$ASSET_DIR.new"
  cp -R "$SRC_DIR" "$ASSET_DIR.new"
  chmod -R u=rwX,go=rX "$ASSET_DIR.new"
  rm -rf "$ASSET_DIR"
  mv "$ASSET_DIR.new" "$ASSET_DIR"
  command -v restorecon >/dev/null 2>&1 && restorecon -R "$ASSET_DIR" 2>/dev/null || true
  log "assets installed in $ASSET_DIR"
fi

# --- files --------------------------------------------------------------------
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

patched=0
mapfile -t files < <(find_candidates)
# ${a[@]+...}: older bash calls an empty array unbound under set -u.
for file in ${files[@]+"${files[@]}"}; do
  sed -r "$SED_SCRIPT" "$file" > "$tmp"
  cmp -s "$file" "$tmp" && continue

  if (( DRY_RUN )); then
    diff -u "$file" "$tmp" | cut -c1-400 || true
  else
    backup "$file"
    # Write in place: keeps owner, mode and SELinux label of the original.
    cat "$tmp" > "$file"
    record "$file"
    log "patched  $file"
  fi
  patched=$((patched + 1))
done

# --- report -------------------------------------------------------------------
if (( patched == 0 )); then
  log "nothing to patch - already done"
elif (( DRY_RUN )); then
  log "$patched file(s) would be patched"
else
  log "$patched file(s) patched; originals backed up in $STATE_DIR/backup"
fi

if (( ! DRY_RUN )); then
  mapfile -t left < <(find_candidates)
  if (( ${#left[@]} )); then
    warn "still referenced, not covered by the rules (see audit.sh):"
    grep -HnoE ".{0,60}($HOSTS_RE).{0,60}" "${left[@]}" >&2 || true
  fi
fi
