#!/usr/bin/env bash
#
# Lists what under the web root still makes the browser fetch a script,
# stylesheet, font or image from another host. Read-only.
#
# Run it after install.sh to see what is left - e.g. from add-on modules that
# this package does not know about. Links (<a href>) are not listed; neither
# are calls the PHP code itself makes to the internet.
#
#   bash audit.sh         only what needs a look
#   bash audit.sh --all   also the references that never load, with the reason
#
# Exit status: 0 when nothing needs a look, 1 otherwise.
#
set -euo pipefail

WEBROOT=${WEBROOT:-/var/www/html}

SHOW_ALL=0
case ${1:-} in
  '')    ;;
  --all) SHOW_ALL=1 ;;
  *)     echo "usage: $0 [--all]" >&2; exit 2 ;;
esac

EXTERNAL='(https?:)?//[A-Za-z0-9.-]+\.[A-Za-z]{2,}[^"'"'"' )<>]*'
PATTERNS=(
  # <script src>, <link href>, <img src>, <iframe src>, ...
  "<(script|link|img|iframe|embed|source|audio|video)[^>]*(src|href)=[\\\"']?$EXTERNAL"
  # CSS url(...) and @import
  "(url\\(|@import)[[:space:]]*[\\\"']?$EXTERNAL"
  # asset URLs in JavaScript strings
  "[\\\"']${EXTERNAL}\\.(js|css|woff2?|ttf|eot|otf|svg|png|gif|jpe?g|ico|cur)(\\?[^\\\"']*)?[\\\"']"
)

# Library code that contains a CDN URL on a path Issabel and FOP2 never take.
# Triples of: file name regex, URL regex, reason.
KNOWN=(
  'sweetalert2(\.min)?\.js$'  'youtube\.com/embed'
    'example text inside SweetAlert2'
  'mediaelement[^/]*\.js$'    'player\.vimeo\.com'
    'MediaElement.js, only when a Vimeo video is played'
  'jspdf[^/]*\.js$'           'cdnjs\.cloudflare\.com/ajax/libs/pdfobject/'
    'jsPDF, only for output("pdfobjectnewwindow"), which is not used'
  'amplitude[^/]*\.js$'       'connect\.soundcloud\.com'
    'AmplitudeJS, only when a SoundCloud client_id is set, which it is not'
)

# The file with <!-- ... --> blanked out and line breaks kept, so line numbers
# still match. IE conditional comments (<!--[if ...]>) are kept: IE does load
# what is inside them.
strip_html_comments() {
  awk '
    {
      out = ""; s = $0
      while (s != "") {
        if (in_comment) {
          i = index(s, "-->")
          if (i) { s = substr(s, i + 3); in_comment = 0 } else s = ""
        } else {
          i = index(s, "<!--")
          if (!i) { out = out s; break }
          if (substr(s, i + 4, 3) == "[if") {
            out = out substr(s, 1, i + 3); s = substr(s, i + 4)
          } else {
            out = out substr(s, 1, i - 1); s = substr(s, i + 4); in_comment = 1
          }
        }
      }
      print out
    }' "$1"
}

# A .js/.css file whose content is really an HTML document (e.g. a GitHub page
# saved instead of the raw file). The browser parses it as JS/CSS, so the tags
# in it never load anything.
is_html_page() {
  awk 'NF { html = tolower($0) ~ /^[[:space:]]*<(!doctype html|html[[:space:]>])/; exit } END { exit !html }' "$1"
}

# Prints why a reference never loads, or nothing if it may.
why_hidden() {
  local file=$1 line=$2 match=$3 i
  case $file in
    *.tpl|*.html|*.htm|*.php)
      if ! strip_html_comments "$file" | sed -n "${line}p" | grep -qF -- "$match"; then
        echo "inside an HTML comment"
        return
      fi
      ;;
    *.js|*.css)
      if is_html_page "$file"; then
        echo "file is a saved HTML page, not real JS/CSS"
        return
      fi
      ;;
  esac
  for ((i = 0; i < ${#KNOWN[@]}; i += 3)); do
    if [[ $file =~ ${KNOWN[i]} && $match =~ ${KNOWN[i+1]} ]]; then
      echo "${KNOWN[i+2]}"
      return
    fi
  done
}

args=()
for p in "${PATTERNS[@]}"; do args+=(-e "$p"); done

mapfile -t hits < <(
  grep -rnIoE "${args[@]}" "$WEBROOT" \
    --include='*.tpl' --include='*.php' --include='*.html' --include='*.htm' \
    --include='*.css' --include='*.js' \
    --exclude-dir=templates_c --exclude-dir=issabel5-local-assets 2>/dev/null \
    | grep -vE '//(www\.)?w3\.org/' \
    | sort -u | sort -s -t: -k1,1 -k2,2n \
    || true
)

shown=0
hidden=0
declare -A hidden_by
for hit in ${hits[@]+"${hits[@]}"}; do
  file=${hit%%:*}
  rest=${hit#*:}
  line=${rest%%:*}
  match=${rest#*:}
  reason=$(why_hidden "$file" "$line" "$match")
  if [[ -z $reason ]]; then
    printf '%s\n' "$hit"
    shown=$((shown + 1))
  else
    (( SHOW_ALL )) && printf '%s    <- never loads: %s\n' "$hit" "$reason"
    hidden_by[$reason]=$(( ${hidden_by[$reason]:-0} + 1 ))
    hidden=$((hidden + 1))
  fi
done

(( shown )) || echo "Nothing under $WEBROOT loads assets from another host."

if (( hidden )); then
  echo
  echo "$hidden reference(s) never load and are $( (( SHOW_ALL )) && echo marked above || echo hidden ):"
  for reason in "${!hidden_by[@]}"; do
    printf '  %4d  %s\n' "${hidden_by[$reason]}" "$reason"
  done | sort -rn
  (( SHOW_ALL )) || echo "Run 'bash audit.sh --all' to list them."
fi

(( shown == 0 ))
