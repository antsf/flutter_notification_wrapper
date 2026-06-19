# Analisa Kode — `flutter_notification_wrapper`

> Dibuat: 2026-06-19 · Versi yang dianalisa: `0.3.0` · Branch: `main`

> ✅ **SUDAH DITINDAKLANJUTI di v1.0.0** (PR #5, merged 2026-06-19). Dokumen 00–05
> ini adalah snapshot analisa awal `0.3.0`. Review tajam + plan implementasi ada
> di [`06-brutal-review.md`](06-brutal-review.md),
> [`07-review-of-review.md`](07-review-of-review.md), dan
> [`08-implementation-plan.md`](08-implementation-plan.md) — semuanya sudah
> diimplementasikan. Lihat juga `1.0.0` di [`../CHANGELOG.md`](../CHANGELOG.md).

Dokumen ini adalah hasil pembacaan menyeluruh seluruh kode package. Tujuannya
memetakan **apa yang rusak, apa yang bisa dioptimalkan, apa yang perlu di-improve,
apa yang perlu ditambah, dan apa yang sudah bagus / masih relevan.**

## Struktur dokumen

| File | Isi |
|------|-----|
| [`01-perlu-diperbaiki.md`](01-perlu-diperbaiki.md) | Bug & kesalahan yang berdampak fungsional/legal (prioritas tinggi) |
| [`02-perlu-dioptimize.md`](02-perlu-dioptimize.md) | Optimasi performa, resource leak, dead code |
| [`03-perlu-diimprove.md`](03-perlu-diimprove.md) | Perbaikan kualitas, arsitektur, dan DX |
| [`04-perlu-ditambahkan.md`](04-perlu-ditambahkan.md) | Fitur/infrastruktur yang sebaiknya ditambah |
| [`05-useful-dan-relevan.md`](05-useful-dan-relevan.md) | Bagian yang bagus & masih relevan untuk dipertahankan |

## Gambaran umum package

Package membungkus **Firebase Cloud Messaging (FCM)** + **AwesomeNotifications**
di balik satu abstraksi `NotificationWrapper` dengan implementasi default
`DefaultNotificationHandler` (singleton). Tersedia utilitas pendukung: `Logger`,
`Debouncer`, `Rx`, plus `NotificationConfig` yang immutable.

```
lib/
├─ flutter_notification_wrapper.dart   # barrel export
└─ src/
   ├─ notification_wrapper.dart        # abstract class + default handler statis
   ├─ default_notification_handler.dart# implementasi utama (singleton) ~1060 baris
   ├─ notification_config.dart         # config channel (immutable, solid)
   ├─ background_message_handler.dart  # helper FCM background (redundan)
   └─ utils/
      ├─ logger.dart                   # logger sederhana (bagus)
      ├─ debounce.dart                 # debouncer (bagus)
      ├─ rx.dart                       # reactive value mini (bagus)
      ├─ notification_analytics.dart   # placeholder, tak terpakai
      ├─ notification_center.dart      # global state, tak terpakai
      └─ type.dart                     # typedef, tak terpakai
```

## Penilaian singkat

| Aspek | Nilai | Catatan |
|-------|:-----:|---------|
| Desain abstraksi | 🟢 Baik | `NotificationWrapper` + override handler rapi |
| `NotificationConfig` | 🟢 Baik | immutable, `copyWith`, `==`, validasi, factory |
| Utilitas (Logger/Debouncer/Rx) | 🟢 Baik | terdokumentasi & teruji |
| Implementasi handler | 🟠 Bermasalah | beberapa bug fungsional (lihat dok 01) |
| Penanganan background/isolate | 🟠 Rapuh | bergantung asumsi yang tak selalu benar |
| Resource management | 🔴 Bocor | subscription & Rx tidak di-dispose |
| Kebersihan kode | 🔴 Kotor | banyak blok komentar mati (>150 baris) |
| Test | 🟠 Parsial | hanya util yang diuji; handler 100% di-comment |
| Legal/publikasi | 🔴 Blocker | `LICENSE` masih placeholder "TODO" |

## 3 hal paling mendesak

1. **`LICENSE` masih berisi `TODO: Add your license here.`** padahal pubspec &
   README mengklaim MIT → blocker publikasi & masalah legal. (dok 01 #1)
2. **`NotificationConfig` tidak benar-benar diterapkan ke channel.**
   `_setupNotificationChannels()` meng-hardcode `importance: High`, `playSound: true`,
   dll, sehingga factory `silent()`/`lowPriority()` **tidak berefek apa pun**. (dok 01 #2)
3. **Resource leak**: listener `onMessage`/`onTokenRefresh` dan beberapa `Rx`
   tidak pernah di-cancel/dispose. (dok 02 #1)
