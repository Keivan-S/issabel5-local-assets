# issabel5-local-fonts

Issabel 5 loads the **Noto Sans** font from `fonts.googleapis.com`. If the server or the users' browsers can't reach Google, or the connection is slow, the login page and the panel load slowly or with a delay.

This patch removes Google Fonts from the templates and serves the font from the server itself. The font files are already in this repo, so **the server doesn't need internet access**.

## What changes

| File on the server | Source (Issabel package) |
|---|---|
| `/var/www/html/themes/tenant/_common/index.tpl` | issabel-framework |
| `/var/www/html/themes/tenant/_common/login.tpl` | issabel-framework |
| `/var/www/html/modules/cdrreport/themes/default/cel.tpl` | issabel-reports |
| `/var/www/html/admin/views/header.php` | issabelPBX |

- The Google `<link>` is replaced with `/themes/tenant/fonts/noto-sans/noto-sans.css`, and the `preconnect` lines to Google are removed.
- The fonts are copied next to the rest of the theme's fonts, in `/var/www/html/themes/tenant/fonts/noto-sans/`.
- The script doesn't rely only on the table above: it scans all of `/var/www/html`, so if the line has moved in your version it still finds it. If any other font (anything besides Noto Sans) is loaded from Google, it leaves it alone and only prints a warning.
- A backup of each file is kept in `/var/lib/issabel-local-fonts/`.

## Install

```bash
git clone https://github.com/<your-user>/issabel5-local-fonts.git
cd issabel5-local-fonts
bash install.sh --dry-run
bash install.sh
```

`--dry-run` only shows a diff of the changes and touches nothing. Run it as root.

Refresh the browser with Ctrl+F5. In DevTools → Network there should no longer be any request to `fonts.googleapis.com` or `fonts.gstatic.com`.

> If the server doesn't have access to GitHub either, download the repo as a zip somewhere else, copy it over with `scp`, and run `install.sh` from inside it.

## After `yum update`

Updating the `issabel-framework`, `issabel-reports` or `issabelPBX` packages brings the original templates back, and with them Google Fonts. Just run it again:

```bash
bash install.sh
```

Running it several times does no harm; files that are already patched are skipped.

## Uninstall

```bash
bash uninstall.sh
```

A file is restored only if it is still exactly as the patch left it. If an update has already replaced it, it is left alone. If it was edited by hand, the script says so and keeps the fonts until you've dealt with it.

## Rebuilding the fonts

On a machine that has access to Google (not on the server):

```bash
bash tools/fetch-fonts.sh
```

This downloads the woff2 files and `noto-sans.css` again (weights 400 and 700 plus italic 400, the same as what Issabel requests from Google) and writes them to `fonts/noto-sans/`.

## License

Noto Sans is released under the [SIL Open Font License 1.1](fonts/noto-sans/OFL.txt) and may be redistributed.
