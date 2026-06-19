# 05 — Apa yang Useful & Masih Relevan (Pertahankan)

Bagian ini menandai kode yang **sudah bagus**, agar perbaikan tidak merusaknya.

---

## 🟢 Sangat useful & relevan

### `NotificationConfig` (`notification_config.dart`)
Contoh value object yang rapi dan layak ditiru:
- `@immutable`, semua field `final`,
- `copyWith`, `==`, `hashCode` (via `Object.hash`), `toString` lengkap,
- `validate()` + `isValid` (validasi channelKey kosong/berspasi, prefix ikon),
- factory bermakna: `silent()`, `defaultConfig()`, `highPriority()`, `lowPriority()`, `custom()`,
- `toNotificationChannel()` — *(catatan: bagus, tapi belum dipakai handler — lihat dok 01 #2)*.

**Pertahankan.** Hanya perlu disambungkan ke handler.

### Abstraksi `NotificationWrapper` (`notification_wrapper.dart`)
Pola override handler (`onMessageOverride`, `onBackgroundMessageOverride`, dst.)
dengan default statis adalah desain yang sehat — konsumen bisa override sebagian
tanpa menulis ulang semuanya. Pemisahan kontrak (abstract) dari implementasi bagus.

**Pertahankan.** Bersihkan komentar header & selaraskan nullability (dok 01 #12).

### `Logger` (`utils/logger.dart`)
Ringan, `@immutable`, level-based (`debug/info/warning/error/none`), early-return
saat level di-skip, factory `forClass`/`forFeature`, konfigurasi timestamp & nama.
Teruji.

**Pertahankan.** Tambah pluggable output (dok 04 #9) sebagai improvement, bukan ganti.

### `Debouncer` & `NotificationDebouncer` (`utils/debounce.dart`)
Implementasi bersih, ada `runAsync` dengan guard error, `dispose`, dan
`NotificationDebouncer.runForMessage` untuk anti-duplikat berbasis `messageId`.
Teruji baik. **Catatan:** `NotificationDebouncer` belum dimanfaatkan handler —
justru ini solusi untuk masalah dedup (dok 03 #5).

**Pertahankan & manfaatkan lebih jauh.**

### `Rx` & turunannya (`utils/rx.dart`)
Reaktif minimal yang berguna: `value`/`update`/`listen` (mengembalikan fungsi
unsubscribe), `stream` broadcast, error-guard di notifikasi listener, `dispose`,
plus turunan praktis `RxBool`/`RxInt`/`RxString`/`RxList`. Teruji lengkap.

**Pertahankan.** Hanya `listenWithPrevious` yang perlu diperbaiki (dok 03 #6),
dan pastikan instance `permissionStatus` di-dispose (dok 02 #1).

---

## 🟢 Keputusan desain yang tepat

### Selalu pakai AwesomeNotifications untuk display (Android 13+)
`smartDefaultBackgroundMessageHandler` (`:1033`) + commit terbaru memilih selalu
menampilkan via AwesomeNotifications, bukan mengandalkan auto-display FCM yang
tidak andal di Android 13+ (butuh `POST_NOTIFICATIONS`). Disertai dokumentasi
alasan yang jelas. Ini **benar** dan relevan.

### Forwarding aksi lewat isolate port
Pola `IsolateNameServer` + `ReceivePort` ('notification_action_port') di
`_onActionReceivedMethod`/`_initializeIsolateReceivePort` (`:855-952`) untuk
meneruskan aksi dari background isolate ke main isolate adalah pendekatan yang
matang untuk masalah nyata.

**Pertahankan.** Pastikan port ditutup di `dispose` (sudah dilakukan — bagus).

### `@visibleForTesting resetInstance()`
Menyediakan reset singleton untuk test (`:85`) — niat yang benar. Tinggal
dilengkapi dengan dependency injection agar benar-benar bisa dipakai (dok 03 #2).

### `@pragma('vm:entry-point')` pada callback statis
Sudah dipasang di handler background/aksi — penting agar tidak di-tree-shake di
release. Benar.

---

## 🟢 Dokumentasi & contoh

### `README.md`
Komprehensif: fitur, setup Android/iOS, quick start, tabel peran FCM vs
AwesomeNotifications, panduan anti-duplikat, tabel properti config. Salah satu aset
terkuat package ini.

**Pertahankan.** Sinkronkan dengan perilaku nyata setelah bug dok 01 diperbaiki
(jangan iklankan DevTool/iOS token sampai benar-benar jalan).

### `CHANGELOG.md` — bagian migration guide
Panduan migrasi 0.2.0 → 0.3.0 detail dan berguna. Hanya tanggalnya placeholder
(dok 03 #8).

### `analysis_options.yaml`
Set lint sangat ketat & lengkap — menunjukkan niat kualitas tinggi. Tinggal
kurangi `ignore_for_file` global (dok 03 #10) agar lint benar-benar menjaga kode.

---

## Ringkasan: prioritas mempertahankan vs memperbaiki

| Komponen | Pertahankan | Tindakan |
|----------|:-----------:|----------|
| `NotificationConfig` | ✅ | Sambungkan `toNotificationChannel()` ke handler |
| `NotificationWrapper` | ✅ | Bersihkan komentar, selaraskan signature |
| `Logger` / `Debouncer` / `Rx` | ✅ | Improve kecil (pluggable output, fix `listenWithPrevious`) |
| Strategi Android 13+ | ✅ | — |
| Forwarding isolate | ✅ | — |
| README / migration guide | ✅ | Sinkronkan dengan perilaku nyata |
| `NotificationCenter` / `NotificationAnalytics` / `type.dart` | ❌ | Hapus atau implementasikan (dok 02 #4) |
| `background_message_handler.dart` | ❌ | Redundan — hapus |
