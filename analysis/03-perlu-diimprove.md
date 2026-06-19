# 03 — Apa yang Perlu Di-improve (Kualitas, Arsitektur, DX)

---

## Arsitektur & coupling

### #1 — Paksa-pakai 4 dependency berat sekaligus
Package mengikat **firebase_core + firebase_messaging + firebase_analytics +
awesome_notifications** sebagai dependency wajib. Konsumen yang hanya ingin
notifikasi lokal (tanpa FCM), atau hanya FCM (tanpa analytics), tetap menanggung
semuanya.

**Improve:** pisahkan tanggung jawab — analytics jadi opsional (lihat dok 02 #6);
pertimbangkan abstraksi "transport" (FCM) terpisah dari "presenter" (AwesomeNotifications)
agar bisa dipakai sebagian.

### #2 — Singleton + state statis menyulitkan testing
`DefaultNotificationHandler` memakai singleton (`get I`) plus state statis
(`_receivePort`, `_instance`). Sudah ada `resetInstance()` (bagus), tapi semua
panggilan ke `AwesomeNotifications()` / `FirebaseMessaging.instance` hard-coded —
tidak bisa di-mock. Inilah sebabnya `default_notification_handler_test.dart`
seluruhnya dikomentari: penulisnya tidak berhasil mem-mock-nya.

**Improve:** injeksikan dependency (`AwesomeNotifications`, `FirebaseMessaging`)
lewat konstruktor/`@visibleForTesting`, agar handler bisa diuji unit.

### #3 — Penamaan `onFailedToResolveHostname` menyesatkan
Callback ini dipakai sebagai *handler error generik* untuk gagal ambil token &
gagal request permission — bukan khusus "resolve hostname".

**Improve:** ganti nama jadi `onError`/`onNotificationError` dengan payload yang
membawa konteks (operasi mana yang gagal).

---

## Kebenaran perilaku & UX

### #4 — `requestPermissions()` dipanggil otomatis saat `initialize()`
`:177` meminta izin notifikasi langsung saat init. Pedoman iOS & Android 13+
menyarankan meminta izin **kontekstual** (setelah user paham manfaatnya), bukan
saat app pertama kali jalan.

**Improve:** beri flag `requestPermissionOnInit: false` atau biarkan app yang
memanggil `requestPermissions()` sendiri.

### #5 — Dedup hanya di jalur `onMessageOpenedApp`
`_debounceHandleNotification` + `_lastHandledMessageId` (`:293`) hanya melindungi
`onMessageOpenedApp`. Jalur tampilan (`showNotification`) tidak punya dedup,
sehingga duplikasi FCM (lihat catatan Android <13 di README) bisa tetap lolos.

**Improve:** terapkan dedup berbasis `messageId` (manfaatkan `NotificationDebouncer`
yang sudah ada tapi tak dipakai) di jalur display juga.

### #6 — `Rx.listenWithPrevious` rusak secara semantik
`rx.dart:63-73` mengirim `_value` (nilai *saat ini*) sebagai argumen "previous",
sehingga `previous == current` selalu. Komentar mengakui "simplified version".

**Improve:** simpan nilai lama sebenarnya sebelum update, atau hapus method ini
agar tidak menyesatkan.

### #7 — `openAppSettings()` dan `openNotificationSettings()` identik
Keduanya (`:697`, `:704`) sama-sama memanggil `showNotificationConfigPage()`.
Dua nama, satu perilaku.

**Improve:** bedakan perilaku (settings aplikasi vs settings channel/notifikasi),
atau gabungkan menjadi satu method.

---

## Kebersihan & metadata

### #8 — `CHANGELOG.md` memakai tanggal placeholder
Semua rilis tertulis `2024-01-XX`. Tidak informatif & mengurangi kepercayaan.

**Improve:** isi tanggal rilis sebenarnya.

### #9 — Komentar "Assuming you have a Logger utility" basi
`notification_wrapper.dart:14`, `default_notification_handler.dart:17`, dll —
komentar peninggalan template. `Logger` jelas-jelas sudah ada.

**Improve:** bersihkan komentar usang & blok penjelasan panjang di header
`notification_wrapper.dart:7-11`.

### #10 — Banyak `// ignore_for_file` menyembunyikan masalah nyata
Mis. `public_member_api_docs`, `avoid_catches_without_on_clauses`,
`lines_longer_than_80_chars` di-ignore secara berkas. Lint `avoid_catches_without_on_clauses`
yang dimatikan justru menyembunyikan bug `e as Exception` (dok 01 #4).

**Improve:** kurangi ignore global; tangani per-kasus.

### #11 — `catch (e)` menelan error tanpa rethrow/telemetri
Hampir semua method `show*` membungkus dengan `try/catch` yang hanya nge-log lalu
diam. Kegagalan tampil notifikasi jadi *silent failure* bagi pemanggil — bertolak
belakang dengan klaim README "comprehensive error handling".

**Improve:** sediakan jalur propagasi error (return status / lempar ulang opsional /
callback `onError`).
