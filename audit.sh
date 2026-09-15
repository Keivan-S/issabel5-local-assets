#!/usr/bin/env bash
#
# Lists everything under the web root that still makes the browser fetch a
# script, stylesheet, font or image from another host. Read-only.
#
# Run it after install.sh to see what is left - e.g. from add-on modules that
# this package does not know about. Links (<a href>) are not listed; neither
# are calls the PHP code itself makes to the internet.
#
#   bash audit.sh
#
set -euo pipefail

WEBROOT=${WEBROOT:-/var/www/html}

EXTERNAL='(https?:)?//[A-Za-z0-9.-]+\.[A-Za-z]{2,}[^"'"'"' )<>]*'
PATTERNS=(
  # <script src>, <link href>, <img src>, <iframe src>, ...
  "<(script|link|img|iframe|embed|source|audio|video)[^>]*(src|href)=[\\\"']?$EXTERNAL"
  # CSS url(...) and @import
  "(url\\(|@import)[[:space:]]*[\\\"']?$EXTERNAL"
  # asset URLs in JavaScript strings
  "[\\\"']${EXTERNAL}\\.(js|css|woff2?|ttf|eot|otf|svg|png|gif|jpe?g|ico|cur)(\\?[^\\\"']*)?[\\\"']"
)

args=()
for p in "${PATTERNS[@]}"; do args+=(-e "$p"); done

grep -rnIoE "${args[@]}" "$WEBROOT" \
  --include='*.tpl' --include='*.php' --include='*.html' --include='*.htm' \
  --include='*.css' --include='*.js' \
  --exclude-dir=templates_c --exclude-dir=issabel5-local-assets 2>/dev/null \
  | grep -vE '//(www\.)?w3\.org/' \
  | sort -u \
  || { echo "no external assets found in $WEBROOT"; exit 0; }
