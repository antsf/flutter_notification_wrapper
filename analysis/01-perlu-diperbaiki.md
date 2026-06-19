# 01 — Apa yang Perlu Diperbaiki (Bug & Kesalahan)

Diurutkan dari dampak tertinggi. Lokasi mengacu `file:baris` pada versi saat ini.

---

## 🔴 #1 — `LICENSE` masih placeholder (blocker legal & publikasi)

`LICENSE` berisi:

```
TODO: Add your license here.
```

Padahal `pubspec.yaml`, `README.md`, dan badge mengklaim **MIT**. Ini:
- membuat `pub publish` gagal/diberi peringatan,
- secara hukum berarti package **tidak punya lisensi** (default: all rights reserved),
- bertentangan dengan klaim README.

**Perbaikan:** isi `LICENSE` dengan teks MIT yang sebenarnya (nama pemegang hak + tahun).

---

## 🔴 #2 — `NotificationConfig` tidak benar-benar diterapkan ke channel

Di `default_notification_handler.dart:201-217`, channel utama dibangun dengan
nilai **hardcoded**, bukan dari `_config`:

```dart
NotificationChannel(
  channelKey: _config!.channelKey,
  channelName: _config!.channelName,
  importance: NotificationImportance.High, // ← hardcoded
  channelShowBadge: true,                  // ← hardcoded
  playSound: true,                         // ← hardcoded
  defaultPrivacy: NotificationPrivacy.Public, // ← hardcoded
  groupAlertBehavior: GroupAlertBehavior.Children, // ← hardcoded
  ...
)
```

Akibatnya `importance`, `playSound`, `enableVibration`, `enableLights`,
`channelShowBadge`, `defaultPrivacy`, `groupAlertBehavior`, `groupKey` dari config
**diabaikan total**. Factory `NotificationConfig.silent()`, `.lowPriority()`,
`.highPriority()` jadi **tidak punya efek apa pun** pada channel sesungguhnya —
ini menggugurkan salah satu fitur utama yang diiklankan README.

Ironisnya sudah ada `NotificationConfig.toNotificationChannel()`
(`notification_config.dart:231`) yang melakukannya dengan benar, **tapi tidak pernah dipanggil.**

**Perbaikan:** ganti pembuatan channel manual dengan `_config!.toNotificationChannel()`.

---

## 🔴 #3 — Hasil dedup channel dibuang (dead code + duplikasi channel)

`default_notification_handler.dart:257-265`:

```dart
final uniqueChannels = <String, NotificationChannel>{};
for (final channel in channelsToCreate) {
  uniqueChannels[channel.channelKey!] = channel;
}

await AwesomeNotifications().initialize(
  _config!.androidNotificationIcon,
  channelsToCreate, // ← memakai list ASLI, bukan uniqueChannels
  debug: true,
);
```

`uniqueChannels` dihitung lalu **tidak dipakai**; yang dikirim justru `channelsToCreate`
yang belum dideduplikasi. Logika dedup jadi sia-sia.

**Perbaikan:** kirim `uniqueChannels.values.toList()`, atau hapus blok dedup jika
tidak diperlukan.

---

## 🟠 #4 — `e as Exception` bisa melempar & menelan error asli

`getFcmToken()` (`:321`) dan `requestPermissions()` (`:826`):

```dart
} catch (e) {
  _logger.e('Error getting FCM token: $e');
  onFailedToResolveHostname?.call(e as Exception); // ← cast bisa gagal
  return null;
}
```

`catch (e)` menangkap `Object`. Jika yang terlempar adalah `Error`
(mis. `TypeError`, `StateError`, null-check error) — bukan `Exception` —
maka `e as Exception` **melempar `CastError` baru** dan menutupi error aslinya,
serta callback tidak terpanggil.

**Perbaikan:** ubah signature callback jadi `Object`, atau guard dengan
`if (e is Exception) onFailedToResolveHostname?.call(e);`.

---

## 🟠 #5 — `debug: true` hardcoded ke produksi

`default_notification_handler.dart:266`:

```dart
debug: true, // Set to false in production
```

Komentar sendiri sudah memperingatkan, tapi nilainya tetap `true`. Ini membuat
AwesomeNotifications memuntahkan log verbose di build rilis.

**Perbaikan:** gunakan `debug: kDebugMode`.

---

## 🟠 #6 — Fitur DevTool yang diiklankan adalah no-op

`enableDevTool()` / `disableDevTool()` (`:744-754`) hanya nge-log; pemanggilan
API aslinya dikomentari:

```dart
void enableDevTool() {
  _logger.d('Enabling AwesomeNotifications DevTool (if available).');
  // AwesomeNotifications().setDevMode(true); // ← mati
}
```

README & `debug_screen.dart` mengeksposnya sebagai tombol fungsional. Pengguna
mengira ada efek, padahal tidak ada.

**Perbaikan:** implementasikan API yang benar, atau hapus method + dokumentasi +
tombol contoh agar tidak menyesatkan.

---

## 🟠 #7 — Callback `onIosTokens` & `onAndroidPermission` tidak pernah dipanggil

Dideklarasikan di `notification_wrapper.dart:54-56` dan diterima di konstruktor +
`initializeSharedInstance`, namun **tidak ada satu pun call-site** di seluruh
`lib/` (sudah diverifikasi dengan grep). Jadi API publik ini menjanjikan sesuatu
yang tidak pernah terjadi:
- `onIosTokens` — APNS token iOS tidak pernah diteruskan.
- `onAndroidPermission` — tidak pernah dipicu.

**Perbaikan:** wire ke alur sebenarnya (mis. `FirebaseMessaging.instance.getAPNSToken()`
untuk iOS; hasil `requestPermissionToSendNotifications` untuk Android), atau hapus
sampai diimplementasikan.

---

## 🟠 #8 — `simulateNotification` memakai force-unwrap `_config!`

`:721`:

```dart
channelKey: channelKey ?? _config!.channelKey,
```

Berbeda dengan method lain yang punya guard `_config == null` + fallback singleton,
di sini `_config!` langsung di-force-unwrap → **crash** bila dipanggil sebelum init
atau di isolate tanpa config.

**Perbaikan:** samakan pola guard/fallback seperti `showRegularNotification`.

---

## 🟠 #9 — Penanganan cold-start dari terminated state masih rapuh

Komentar di `:75-79` mengakui bahwa instance fallback yang dibuat `get I` di
background isolate **mengasumsikan** channel sudah dibuat oleh main app. Pada
skenario *terminated → dibangunkan oleh FCM*, `AwesomeNotifications().initialize()`
belum tentu pernah jalan di isolate itu, sehingga `createNotification` bisa gagal
diam-diam (hanya tertangkap `catch` lalu di-log).

**Perbaikan:** pada path background, panggil inisialisasi channel minimal yang
idempotent sebelum `createNotification`, atau verifikasi channel ada lewat
`AwesomeNotifications().isNotificationAllowed()`/list channel.

---

## 🟡 #10 — Parameter `inputPlaceholder` di `showReplyNotification` tidak dipakai

`:541-542` menerima `inputPlaceholder` dengan komentar
"Not directly used by AwesomeNotifications in this way" — parameter ada tapi
diabaikan. Menyesatkan pemanggil.

**Perbaikan:** petakan ke field yang sesuai, atau hapus parameter.

---

## 🟡 #11 — ID notifikasi rawan tabrakan

Beberapa method memakai:

```dart
id: DateTime.now().millisecondsSinceEpoch.remainder(100000)
```

Dua notifikasi dalam window <1ms (atau hasil remainder yang sama) akan **menimpa**
satu sama lain. `showNotification` lain memakai `message.messageId.hashCode` yang
juga bisa kolisi/negatif.

**Perbaikan:** gunakan generator ID yang lebih aman (counter incremental, atau
`UniqueKey`-style berbasis hash penuh dengan ruang lebih besar).

---

## 🟡 #12 — Mismatch signature override (kosmetik, tapi membingungkan)

- Abstrak `showActionNotification({required ... List<NotificationActionButton> buttons})`
  vs implementasi `List<NotificationActionButton>? buttons` (nullable).
- Abstrak `showGroupedNotification(String groupKey, ...)` vs implementasi `String? groupKey`.

Secara tipe Dart ini valid (kontravarian parameter), tapi kontrak jadi tidak konsisten
antara dokumentasi abstrak dan implementasi.

**Perbaikan:** selaraskan nullability di kedua sisi.
