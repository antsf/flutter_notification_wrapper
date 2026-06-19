# 02 — Apa yang Perlu Dioptimize (Leak, Dead Code, Performa)

---

## 🔴 #1 — Resource leak: subscription & Rx tidak di-dispose

Di `initialize()` dibuat beberapa stream subscription yang **tidak pernah disimpan
maupun di-cancel**:

```dart
FirebaseMessaging.onMessage.listen(...);          // :160
FirebaseMessaging.onMessageOpenedApp.listen(...);  // :164
// dan di refreshToken():
FirebaseMessaging.instance.onTokenRefresh.listen(...); // :328
```

`dispose()` (`:732`) hanya menutup `_receivePort` dan `_notificationDebouncer.timer`.
Yang bocor:
- subscription `onMessage`, `onMessageOpenedApp`, `onTokenRefresh`,
- `permissionStatus` (objek `Rx`) — `Rx.dispose()` tak pernah dipanggil → `StreamController` broadcast-nya tak ditutup.

Lint `cancel_subscriptions` & `close_sinks` aktif di `analysis_options.yaml` tetapi
tidak terpicu karena subscription tidak disimpan ke field (lolos deteksi statis).

**Optimasi:**
- Simpan setiap `StreamSubscription` ke field, cancel di `dispose()`.
- Panggil `permissionStatus.dispose()` di `dispose()`.
- `refreshToken()` membuat listener baru tiap dipanggil → idempotent-kan / simpan subscription.

---

## 🔴 #2 — `refreshToken()` menumpuk listener tiap pemanggilan

`:327-333` menambah listener baru ke `onTokenRefresh` setiap kali dipanggil, tanpa
pernah melepas yang lama. Pemanggilan berulang = listener ganda + callback dipicu
berkali-kali.

**Optimasi:** simpan satu subscription; batalkan/abaikan pemanggilan kedua.

---

## 🟠 #3 — Dead code: ~150+ baris komentar yang harus dibuang

- `default_notification_handler.dart:1066-1163` — **~100 baris** penjelasan dari
  Gemini ditempel utuh sebagai komentar blok. Tidak relevan untuk produksi.
- `default_notification_handler.dart:268-289` & `431-461` — blok `initialize`/
  `createNotification` versi lama yang dikomentari.
- `test/default_notification_handler_test.dart` — **seluruh file** (151 baris) adalah
  komentar; tidak ada test aktif.
- `example/lib/main.dart:8-26, 39-45, 71-80` — banyak blok main/handler lama dikomentari.

Dead code ini menambah ukuran, mengaburkan kode aktif, dan menurunkan skor `pub.dev`.

**Optimasi:** hapus seluruh blok komentar mati; simpan penjelasan arsitektur (kalau
perlu) di dokumen terpisah, bukan di sumber.

---

## 🟠 #4 — Modul tak terpakai (dead modules, tetap diekspor)

Diverifikasi lewat grep — tidak ada pemakaian di luar definisinya sendiri:

| Berkas | Status |
|--------|--------|
| `utils/notification_center.dart` | `NotificationCenter` — global mutable state, tak pernah dipakai, tak pernah dibersihkan (potensi tumbuh tanpa batas bila kelak dipakai) |
| `utils/notification_analytics.dart` | `NotificationAnalytics` — hanya `debugPrint`, placeholder, tak terhubung |
| `utils/type.dart` | typedef `MessageHandler`, `NotificationTapHandler`, `ActionReceivedHandler` — tak dipakai |
| `src/background_message_handler.dart` | `backgroundMessageHandler` — redundan dengan handler statis internal; hanya muncul di komentar contoh |

Semuanya diekspor lewat barrel `flutter_notification_wrapper.dart`, sehingga ikut
jadi API publik yang harus didukung.

**Optimasi:** hapus, atau implementasikan & integrasikan dengan benar sebelum
diekspos. Minimal jangan ekspor placeholder.

---

## 🟠 #5 — Barrel export membocorkan seluruh package Firebase

`flutter_notification_wrapper.dart:32-34`:

```dart
export 'package:firebase_analytics/firebase_analytics.dart';
export 'package:firebase_core/firebase_core.dart';
export 'package:firebase_messaging/firebase_messaging.dart';
```

Re-export penuh tiga package Firebase memperbesar permukaan API publik package ini
dan mengikat konsumen ke versi tertentu. Bila salah satu berubah API, package ikut
breaking.

**Optimasi:** ekspor hanya tipe yang benar-benar muncul di API publik (mis.
`RemoteMessage`, `AuthorizationStatus`, `FirebaseOptions`), bukan seluruh library.

---

## 🟡 #6 — `FirebaseAnalytics` dipanggil paksa di dalam `requestPermissions()`

`:783` & `:808` memanggil `FirebaseAnalytics.instance.logEvent(...)` tanpa opsi
nonaktif. Ini:
- memaksa dependensi `firebase_analytics` selalu ada walau aplikasi tak memakai analytics,
- mengirim event tanpa consent/konfigurasi.

**Optimasi:** jadikan analytics opsional (injeksi callback atau flag), lepaskan
`firebase_analytics` dari dependency wajib.

---

## 🟡 #7 — Build `StringBuffer` di logger tetap jalan walau log di-skip

`Logger._log` memeriksa `_shouldLog(level)` di awal (sudah benar, early-return).
Ini sudah baik. Namun pemanggil sering merangkai string interpolasi mahal
*sebelum* memanggil `.d(...)` (mis. `'... ${message.data}'`), yang tetap dievaluasi
walau level di-skip.

**Optimasi (opsional):** sediakan overload `void d(String Function() builder)` untuk
lazy-logging pada path panas (background handler).
