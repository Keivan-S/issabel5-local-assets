# Issabel 5 Local Assets

**English** | [فارسی](README.fa.md)

The Issabel 5 web panel loads a number of fonts, icons and JS/CSS libraries from Google and other CDNs. If the server or the users' browsers can't reach them (or the connection is slow), pages load slowly, stall, or icons and fonts break.

This patch puts all of those files on the server itself and points the Issabel files at the local copies. Every file is already inside this repo, so **the server doesn't need internet access**.

## What changes

| File on the server (under `/var/www/html`) | What it loaded from outside | Now |
|---|---|---|
| `themes/tenant/_common/index.tpl` | Noto Sans font from Google Fonts | local |
| `themes/tenant/_common/login.tpl` | Noto Sans + html5shiv + respond.js | local |
| `themes/farsi_rtl/_common/login.tpl` | html5shiv + respond.js (`oss.maxcdn.com`) | local |
| `themes/tenant/js/joinable.js` and `themes/farsi_rtl/js/joinable.js` | drag cursor from `google.com` | the `n-resize` cursor |
| `modules/cdrreport/themes/default/cel.tpl` | Noto Sans | local |
| `modules/monitoring/themes/default/css/audioplayer.css` | play/pause icons (the original link is dead, 404) | local |
| `admin/views/header.php` | Noto Sans + Font Awesome 4.7 + jQuery (if the Google CDN setting is on) | local |
| `admin/views/issabelpbx.php` | jQuery UI 1.8.9 from Google | local |
| `admin/views/footer.php` | Chrome Frame (Internet Explorer only) | local |

- The files are placed in `/var/www/html/issabel5-local-assets/`, and each one's source and sha256 is recorded in [`assets/SOURCES.txt`](assets/SOURCES.txt).
- `oss.maxcdn.com` has changed owners and now serves a different version of html5shiv, so the correct version was downloaded from cdnjs.
- The script doesn't rely only on the table above: it scans all of `/var/www/html`, so it still finds these links if they have moved in your version.
- Only exact addresses are replaced. Anything else is left alone, and it tells you if something remains.

## Backup

Before changing any file, its original is copied to `/var/lib/issabel5-local-assets/backup/` with the same full path, e.g.:

```
/var/lib/issabel5-local-assets/backup/var/www/html/admin/views/header.php
```

- If you run `install.sh` again, the original backup is not overwritten with a patched copy.
- If a package update brings back the original file, the backup is refreshed with that new file, so an old file is never restored.
- The checksum of each patched file is kept in `/var/lib/issabel5-local-assets/manifest`, which `uninstall.sh` uses.

## Install

Run as root:

```bash
git clone https://github.com/Keivan-S/issabel5-local-assets.git
cd issabel5-local-assets
bash install.sh --dry-run
bash install.sh
```

`--dry-run` only shows a diff of the changes and touches nothing.

Refresh the browser with Ctrl+F5. In DevTools → Network there should be no requests to other hosts.

> If the server doesn't have access to GitHub either, download the repo as a zip somewhere else, copy it over with `scp`, and run `install.sh` from inside it.

## After updating Issabel

Updating packages such as `issabel-framework`, `issabel-reports` or `issabelPBX` brings back the original files and the CDN links. Run it again:

```bash
bash install.sh
```

Running it several times does no harm; files that are already patched are skipped.

## Checking for anything left: `audit.sh`

```bash
bash audit.sh
```

It lists everything under `/var/www/html` that still makes the browser load a file from another host (read-only; it doesn't change anything). This is useful for add-on modules that aren't in this repo.

On a stock Issabel 5, only these appear, and **none of them is actually loaded**:

| What | Why it isn't loaded |
|---|---|
| `cdn.amcharts.com` in `sec_geoip_map/.../map.tpl` | inside an HTML comment; the module uses its own local copy |
| `connect.soundcloud.com` in `amplitude.min.js` | only if SoundCloud is configured, and Monitoring doesn't configure it |
| `cdnjs.../pdfobject` in `8_jspdf.min.js` | only for a PDF output mode that Issabel doesn't use |
| `youtube.com` in `sweetalert2.min.js` | an example string inside the library |

## Uninstall

```bash
bash uninstall.sh
```

- A file is restored only if it is still exactly as the patch left it.
- If an update has already replaced it, it is left alone.
- If it was edited by hand, the script reports it and keeps the local files until you've dealt with it.

## What this patch doesn't change

These are features that call the internet from the **server** (PHP) side, not files the browser loads. They need internet by nature:

- Dashboard **News** applet (`cloud.issabel.org`): it can be turned off from Dashboard → Applet Admin.
- The **Registration** module (`cloud.issabel.org`).
- Contact photos in the **Address Book**, which are looked up on `gravatar.com`.
- Updating the GeoIP database (MaxMind) and installing add-ons.

## Rebuilding the files

On a machine that has internet access (not on the server):

```bash
bash tools/fetch-assets.sh
```

This downloads all the files again, rebuilds `assets/SOURCES.txt`, and then you can review the diff and commit.

## License

Each file keeps its own license:

- Noto Sans: [OFL 1.1](assets/noto-sans/OFL.txt)
- Font Awesome 4.7: font under OFL 1.1, CSS under MIT
- jQuery UI, html5shiv, respond.js and AmplitudeJS: MIT
- Chrome Frame: BSD

The license notices are in the header of each file.
