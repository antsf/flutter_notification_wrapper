# 04 — Apa yang Perlu Ditambahkan

---

## Testing

### #1 — Test untuk handler inti (saat ini 0%)
`test/default_notification_handler_test.dart` seluruhnya dikomentari. Logika paling
kritis — setup channel, alur background, dedup, permission, pembuatan notifikasi —
**tidak diuji sama sekali**. Yang teruji hanya util (`Logger`, `Debouncer`, `Rx`,
`NotificationConfig`).

**Tambahkan:** setelah dependency di-inject (lihat dok 03 #2), tulis test yang:
- memverifikasi `_config` benar-benar dipetakan ke `NotificationChannel`,
- memverifikasi jalur fallback background isolate,
- memverifikasi dedup `messageId`.

### #2 — Test untuk modul yang belum tercakup
`notification_center.dart` & `notification_analytics.dart` punya file test sendiri
tapi modulnya sendiri belum jelas perannya. Bila dipertahankan, lengkapi test;
bila tidak, hapus modul + test-nya.

---

## Infrastruktur / proyek

### #3 — CI (GitHub Actions)
Belum ada workflow CI. Tambahkan pipeline minimal:
`flutter pub get` → `dart format --set-exit-if-changed` → `flutter analyze` →
`flutter test`. Mencegah regresi & dead code menumpuk.

### #4 — Konfigurasi contoh Firebase yang dapat dijalankan
`example/` memakai `DefaultNotificationHandler` tetapi tanpa `firebase_options.dart`
nyata, sehingga FCM tidak bisa benar-benar diuji oleh pengguna baru.

**Tambahkan:** instruksi `flutterfire configure` di README example + placeholder
`firebase_options.dart` beserta langkahnya.

### #5 — Dokumentasi setup native yang lengkap
README sudah menyinggung `POST_NOTIFICATIONS` (bagus). Tambahkan:
- konfigurasi `proguard`/`r8` untuk entry-point `@pragma('vm:entry-point')`,
- langkah ikon notifikasi iOS & service extension (untuk rich notification),
- catatan APNs token iOS.

---

## Fitur API

### #6 — Listing & query notifikasi aktif
Belum ada cara membaca notifikasi yang sedang tampil / terjadwal
(`AwesomeNotifications().listScheduledNotifications()` dll). Berguna untuk
mengelola badge & sinkronisasi state.

### #7 — Cancel by group / by channel
Saat ini hanya `cancel(id)` dan `cancelAll()`. Tambahkan
`cancelNotificationsByChannel`, `cancelNotificationsByGroup`,
`dismissAllNotifications` vs `cancelAllSchedules`.

### #8 — Penjadwalan berulang (recurring) & zona waktu
`scheduleNotification` hanya sekali (`NotificationCalendar.fromDate`). Tambahkan
opsi `repeats`, interval (`NotificationInterval`), dan parameter timezone agar
penjadwalan akurat lintas zona.

### #9 — Pluggable logger / integrasi Crashlytics
`Logger` hanya `debugPrint`. Tambahkan mekanisme `Logger.setOutput((level, msg) {...})`
agar bisa diteruskan ke Crashlytics/Sentry. Ini juga membuat error yang kini
ditelan (dok 03 #11) bisa dilaporkan.

### #10 — Dukungan APNS token & event token iOS yang nyata
Lengkapi `onIosTokens` (kini dead, dok 01 #7) dengan `getAPNSToken()` dan stream
refresh, agar klaim "Cross-Platform: full iOS support" benar.

### #11 — Helper anti-duplikat untuk Android <13
README menyarankan kirim data-only message untuk hindari duplikat, tapi package
tidak menyediakan guard apa pun. Tambahkan opsi untuk men-skip auto-display atau
mendeteksi & menahan duplikat berbasis `messageId`.

---

## Metadata package

### #12 — Lengkapi `pubspec.yaml`
Tambahkan `screenshots:`, `funding:` (opsional), dan pastikan `documentation:`
mengarah ke wiki yang benar-benar ada. Verifikasi versi dependency masih relevan
saat rilis (`awesome_notifications`, `firebase_*`).
