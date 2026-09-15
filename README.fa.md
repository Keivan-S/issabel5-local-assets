# Issabel 5 Local Assets

[English](README.md) | **فارسی**

فایل‌های محلی برای پنل وب ایزابل ۵

پنل وب ایزابل ۵ تعدادی فونت، آیکون و کتابخانه‌ی JS/CSS را از گوگل و CDNهای دیگر بارگذاری می‌کند. اگر سرور یا مرورگر کاربران به این آدرس‌ها دسترسی نداشته باشند (یا اتصال کُند باشد)، صفحه‌ها دیر باز می‌شوند، گیر می‌کنند یا آیکون‌ها و فونت‌ها به‌هم می‌ریزند.

این پچ همه‌ی این فایل‌ها را روی خود سرور می‌گذارد و فایل‌های ایزابل را به نسخه‌ی محلی آن‌ها وصل می‌کند. همه‌ی فایل‌ها داخل همین ریپو هستند، پس **سرور به اینترنت نیاز ندارد**.

## چه چیزهایی تغییر می‌کند

| فایل روی سرور (زیر `/var/www/html`) | چه چیزی از بیرون بارگذاری می‌شد | الان |
|---|---|---|
| `themes/tenant/_common/index.tpl` | فونت Noto Sans از Google Fonts | محلی |
| `themes/tenant/_common/login.tpl` | Noto Sans + html5shiv + respond.js | محلی |
| `themes/farsi_rtl/_common/login.tpl` | html5shiv + respond.js (`oss.maxcdn.com`) | محلی |
| `themes/tenant/js/joinable.js` و `themes/farsi_rtl/js/joinable.js` | نشانگر ماوس برای کشیدن، از `google.com` | نشانگر `n-resize` |
| `modules/cdrreport/themes/default/cel.tpl` | Noto Sans | محلی |
| `modules/monitoring/themes/default/css/audioplayer.css` | آیکون‌های پخش/توقف (لینک اصلی از کار افتاده، 404) | محلی |
| `admin/views/header.php` | Noto Sans + Font Awesome 4.7 + jQuery (اگر تنظیم CDN گوگل روشن باشد) | محلی |
| `admin/views/issabelpbx.php` | jQuery UI 1.8.9 از گوگل | محلی |
| `admin/views/footer.php` | Chrome Frame (فقط Internet Explorer) | محلی |
| `fop2/css/bootstrap.min.css` | فونت Source Sans Pro از Google Fonts (پنل FOP2) | محلی |
| `fop2/css/bootstrap-theme.css` | فونت Ubuntu از Google Fonts (پنل FOP2) | محلی |

- فایل‌ها در `/var/www/html/issabel5-local-assets/` قرار می‌گیرند و منبع و sha256 هر کدام در [`assets/SOURCES.txt`](assets/SOURCES.txt) ثبت شده است.
- دامنه‌ی `oss.maxcdn.com` صاحب جدید دارد و الان نسخه‌ی دیگری از html5shiv می‌دهد، برای همین نسخه‌ی درست از cdnjs دانلود شده است.
- اسکریپت فقط به جدول بالا تکیه نمی‌کند: کل `/var/www/html` را می‌گردد، پس اگر در نسخه‌ی شما جای این لینک‌ها عوض شده باشد باز هم پیدایشان می‌کند.
- فقط آدرس‌های دقیق جایگزین می‌شوند. به بقیه دست نمی‌زند و اگر چیزی باقی مانده باشد اعلام می‌کند.

## بک‌آپ

قبل از تغییر هر فایل، نسخه‌ی اصلی آن با همان مسیر کامل در `/var/lib/issabel5-local-assets/backup/` کپی می‌شود، مثلاً:

```
/var/lib/issabel5-local-assets/backup/var/www/html/admin/views/header.php
```

- اگر `install.sh` را دوباره اجرا کنید، بک‌آپ اصلی با نسخه‌ی پچ‌شده جایگزین نمی‌شود.
- اگر آپدیت یک پکیج فایل اصلی را برگرداند، بک‌آپ با همان فایل جدید به‌روز می‌شود تا هیچ‌وقت فایل قدیمی برگردانده نشود.
- چک‌سام هر فایل پچ‌شده در `/var/lib/issabel5-local-assets/manifest` نگهداری می‌شود و `uninstall.sh` از آن استفاده می‌کند.

## نصب

با کاربر root:

```bash
git clone https://github.com/Keivan-S/issabel5-local-assets.git
cd issabel5-local-assets
bash install.sh --dry-run
bash install.sh
```

`--dry-run` فقط diff تغییرات را نشان می‌دهد و به چیزی دست نمی‌زند.

مرورگر را با Ctrl+F5 رفرش کنید. در DevTools → Network نباید هیچ درخواستی به هاست دیگری دیده شود.

> اگر سرور به GitHub هم دسترسی ندارد، ریپو را جای دیگری به‌صورت zip دانلود کنید، با `scp` روی سرور بریزید و `install.sh` را از داخل آن اجرا کنید.

## آپدیت همین پکیج

```bash
cd issabel5-local-assets
git pull
bash install.sh
```

## بعد از آپدیت ایزابل یا FOP2

آپدیت پکیج‌هایی مثل `issabel-framework`، `issabel-reports` یا `issabelPBX`، یا آپگرید FOP2، فایل‌های اصلی و لینک‌های CDN را برمی‌گرداند. دوباره اجرا کنید:

```bash
bash install.sh
```

چند بار اجرا کردن ضرری ندارد؛ فایل‌هایی که قبلاً پچ شده‌اند رد می‌شوند.

## بررسی موارد باقی‌مانده: `audit.sh`

```bash
bash audit.sh
```

هر چیزی را زیر `/var/www/html` که هنوز باعث می‌شود مرورگر فایلی را از هاست دیگری بارگذاری کند فهرست می‌کند (فقط می‌خواند و چیزی را تغییر نمی‌دهد). برای ماژول‌های جانبی که در این ریپو نیستند مفید است.

بعد از نصب، این موارد ممکن است روی سرور ایزابل ۵ هنوز دیده شوند و **هیچ‌کدام واقعاً بارگذاری نمی‌شوند**:

| چه چیزی | چرا بارگذاری نمی‌شود |
|---|---|
| `cdn.amcharts.com` در `sec_geoip_map/.../map.tpl` | داخل کامنت HTML است؛ ماژول از نسخه‌ی محلی خودش استفاده می‌کند |
| `connect.soundcloud.com` در `amplitude.min.js` | فقط اگر `client_id` ساندکلاد تنظیم شده باشد، که ماژول Monitoring تنظیمش نمی‌کند |
| `cdnjs.../pdfobject` در `8_jspdf.min.js` | فقط برای حالت خروجی `pdfobjectnewwindow` که ایزابل از آن استفاده نمی‌کند |
| `youtube.com` در `sweetalert2.min.js` (و نسخه‌ی کپی آن زیر `admin/modules/framework/`) | یک رشته‌ی مثال داخل کتابخانه است |
| `player.vimeo.com` در `fop2/js/mediaelement.min.js` | فقط وقتی یک ویدیوی Vimeo پخش شود |
| `github.com` و `githubassets.com` در `dashboard/applets/IssabelNetwork/js/toastr.js` و `tpl/css/toastr.css` | این دو فایل صفحه‌ی ذخیره‌شده‌ی سایت GitHub هستند، نه کتابخانه‌ی toastr؛ مرورگر آن‌ها را به‌عنوان JS/CSS می‌خواند، پس تگ‌های HTML داخلشان چیزی بارگذاری نمی‌کنند |

## حذف

```bash
bash uninstall.sh
```

- هر فایل فقط وقتی برگردانده می‌شود که دقیقاً همان‌طور باشد که پچ آن را گذاشته.
- اگر آپدیتی قبلاً آن را جایگزین کرده باشد، به آن دست نمی‌زند.
- اگر دستی ویرایش شده باشد، اسکریپت اعلام می‌کند و فایل‌های محلی را نگه می‌دارد تا تکلیف آن فایل را روشن کنید.

## چه چیزهایی تغییر نمی‌کند

این‌ها قابلیت‌هایی هستند که از سمت **سرور** (PHP) به اینترنت وصل می‌شوند، نه فایل‌هایی که مرورگر بارگذاری می‌کند، و ذاتاً به اینترنت نیاز دارند:

- اپلت **News** داشبورد (`cloud.issabel.org`): از Dashboard → Applet Admin می‌شود خاموشش کرد.
- ماژول **Registration** (`cloud.issabel.org`).
- عکس مخاطبین در **Address Book** که از `gravatar.com` گرفته می‌شود.
- آپدیت دیتابیس GeoIP (MaxMind) و نصب افزونه‌ها.

## ساخت دوباره‌ی فایل‌ها

روی سیستمی که به اینترنت دسترسی دارد (نه روی سرور):

```bash
bash tools/fetch-assets.sh
```

همه‌ی فایل‌ها را دوباره دانلود می‌کند و `assets/SOURCES.txt` را از نو می‌سازد؛ بعد diff را بررسی و commit کنید.

## لایسنس

هر فایل لایسنس خودش را دارد:

- Noto Sans: [OFL 1.1](assets/noto-sans/OFL.txt)
- Source Sans Pro: [OFL 1.1](assets/source-sans-pro/OFL.txt)
- Ubuntu: [Ubuntu Font Licence 1.0](assets/ubuntu/UFL.txt)
- Font Awesome 4.7: فونت با OFL 1.1 و CSS با MIT
- jQuery UI، html5shiv، respond.js و AmplitudeJS: MIT
- Chrome Frame: BSD

متن لایسنس‌ها در ابتدای هر فایل آمده است.
