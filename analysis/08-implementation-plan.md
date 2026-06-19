# Implementation Plan — Updating `flutter_notification_wrapper`

> Source: [`06-brutal-review.md`](06-brutal-review.md) +
> [`07-review-of-review.md`](07-review-of-review.md).
> Goal: take the package from **3.5/10 / not-publishable** to a **publishable,
> trustworthy 7+/10** release. Ordered by impact and dependency.
> Target release: **`1.0.0`** (the breaking changes below justify a major bump).

---

## ✅ Status — COMPLETED in v1.0.0 (PR #5, merged 2026-06-19)

All 16 tasks below were implemented, verified, and merged to `main`.

| Phase | Tasks | Status |
|-------|-------|:------:|
| 1 — Publish blockers | T1–T5 | ✅ done |
| 2 — Correctness & resource safety | T6–T9 | ✅ done |
| 3 — API hygiene & DX | T10–T12 | ✅ done |
| 4 — Tests, example, infra, docs | T13–T16 | ✅ done |

Verification at merge: `dart format` clean · `flutter analyze` 0 issues ·
`flutter test` 52 passed · `dart pub publish --dry-run` 0 warnings · CI green.
The checklists below are kept as the historical plan of record.

---

## Strategy & sequencing

Four phases. **Phase 1 must ship before any publish.** Phases are mostly
independent but ordered so each builds on a stable base. Each task lists:
*what · why · files · acceptance.*

Legend: 🔴 blocker · 🟠 major · 🟡 quality · 🟢 infra

---

## Phase 1 — Publish blockers (must-fix before any release)

### T1 🔴 Add a real LICENSE  *(C1)*
- **What:** Replace `LICENSE` (`TODO...`) with full MIT text incl. copyright holder + year.
- **Why:** Legal blocker; `pub publish` license detection; enterprise OSS scanners.
- **Files:** `LICENSE`.
- **Acceptance:** `dart pub publish --dry-run` reports a recognized MIT license; no license warnings.

### T2 🔴 Make `NotificationConfig` actually configure the channel  *(C2)*
- **What:** In `_setupNotificationChannels()` build the main channel from `_config.toNotificationChannel()` instead of the hardcoded literal. Keep fallback/emergency channels but derive their props explicitly.
- **Why:** `silent()`/`lowPriority()`/`enableVibration`/`defaultPrivacy` are currently inert; Android channels are immutable post-creation → permanent wrong config.
- **Files:** `default_notification_handler.dart:201–267`.
- **Acceptance:** A test asserts the channel passed to `AwesomeNotifications().initialize` reflects `_config` (importance, sound, badge, privacy). `silent()` produces a silent, Min-importance channel.

### T3 🔴 Remove the Gemini transcript + all dead code  *(C3, m4)*
- **What:** Delete `default_notification_handler.dart:1066–1163` and the three large commented-out blocks; clean commented init in `example/lib/main.dart`.
- **Why:** Ships an AI chat transcript to every consumer; instant credibility loss.
- **Files:** `default_notification_handler.dart`, `example/lib/main.dart`.
- **Acceptance:** No `/** ... Gemini */` or large `//`-commented blocks remain; `flutter analyze` clean.

### T4 🔴 Fix crash-prone error casts  *(M2)*
- **What:** Change `onFailedToResolveHostname` signature to `void Function(Object error, StackTrace stackTrace)`; rename to `onError` (see T11). Stop `e as Exception`.
- **Why:** `e as Exception` throws on `Error` subtypes inside `catch` → unhandled crash on the bootstrap path.
- **Files:** `notification_wrapper.dart:53`, `default_notification_handler.dart:321,826`.
- **Acceptance:** Throwing an `Error` (not `Exception`) in token/permission path invokes the callback and does not crash; covered by a test.

### T5 🔴 Initialize AwesomeNotifications in the background isolate  *(M8, under-stated)*
- **What:** Extract channel/plugin setup into a top-level `@pragma('vm:entry-point')` function callable from the background handler; ensure `AwesomeNotifications().initialize(...)` runs (idempotently) before any `createNotification` in the terminated-state path. Verify the fallback channel exists before use.
- **Why:** From terminated state the on-the-fly `get I` never initializes the plugin → background notifications silently fail (worst case for a push package).
- **Files:** `default_notification_handler.dart:54–82, 368–462, 1033–1062`, `background_message_handler.dart`.
- **Acceptance:** Integration test (or documented manual test) shows a data-only FCM message displays a notification when the app is terminated.

---

## Phase 2 — Correctness & resource safety

### T6 🟠 Deterministic, retrievable notification IDs  *(M3, ➕1)*
- **What:** Replace `remainder(100000)` / `messageId.hashCode` with a monotonic id source (or stable positive 31-bit hash of a dedup key). Return the generated `int id` from `showRegularNotification`/`showAction`/`showReply`/`schedule`.
- **Why:** Current scheme collides (wrap every 100s; null→0), silently overwrites, and callers can't cancel what they create.
- **Files:** `default_notification_handler.dart:485,520,571,609,720,384,413`, signatures in `notification_wrapper.dart`.
- **Acceptance:** Test: 1000 rapid notifications get unique ids; returned id round-trips through `cancelNotification`.

### T7 🟠 Fix subscription & Rx leaks; make re-init/refresh idempotent  *(C4, ➕2)*
- **What:** Store all `StreamSubscription`s (`onMessage`, `onMessageOpenedApp`, `onTokenRefresh`); cancel in `dispose()`. `refreshToken` keeps a single subscription. `initializeSharedInstance` either no-ops or fully re-applies config + tears down old listeners. Close `permissionStatus` Rx in `dispose()`.
- **Why:** Re-init/hot-restart/multi-account stacks duplicate listeners → duplicated side effects + memory growth.
- **Files:** `default_notification_handler.dart:135–179, 327–333, 733–742`, `:38`.
- **Acceptance:** Test: calling init twice + refreshToken thrice yields exactly one active subscription each; `dispose()` cancels all.

### T8 🟠 Bound or remove `NotificationCenter`; drop forced analytics  *(M5, M6, ➕)*
- **What:** Delete `NotificationCenter`/`NotificationAnalytics`/`type.dart` (unused) or make `NotificationCenter` bounded + documented. Remove the hard `firebase_analytics` dependency and the in-line `logEvent` calls; expose an optional `onPermissionEvent(name, params)` hook instead.
- **Why:** Unbounded `static` maps leak; analytics-before-consent is a compliance problem and forces an unwanted dependency.
- **Files:** `notification_center.dart`, `notification_analytics.dart`, `type.dart`, `default_notification_handler.dart:783,808`, `pubspec.yaml:15`, barrel exports.
- **Acceptance:** `firebase_analytics` no longer in `pubspec`; no `logEvent` in package; unused files removed; `flutter analyze` clean.

### T9 🟠 Make permission request & UX flags opt-in  *(➕3, ➕4)*
- **What:** Remove the implicit `requestPermissions()` from `initialize()`; expose it for contextual calling (add `requestPermissionsOnInit: false` flag for back-compat if desired). Make `wakeUpScreen`/`category` configurable via `NotificationConfig` rather than hardcoded.
- **Why:** Forced startup prompt is an anti-pattern; forced screen-wake is battery/UX-hostile.
- **Files:** `default_notification_handler.dart:177,419,491,527,663…`, `notification_config.dart`.
- **Acceptance:** Init no longer triggers an OS prompt unless asked; `wakeUpScreen` reflects config.

---

## Phase 3 — API hygiene & DX

### T10 🟠 Stop polluting the consumer namespace  *(M1)*
- **What:** Export only the package's own public types. Stop exporting `Rx*`/`Logger`/`Debouncer` (move to `src`, un-exported, or behind a `notification_wrapper/utils.dart` opt-in import). Reconsider re-exporting all of Firebase — prefer documenting that consumers add Firebase directly; if kept, narrow it.
- **Why:** `Rx`/`Logger`/`Debouncer` collide with GetX/logging packages; full Firebase re-export couples your public API to theirs.
- **Files:** `flutter_notification_wrapper.dart:32–45`.
- **Acceptance:** A sample app importing both this package and GetX compiles without `hide`.

### T11 🟡 Clean up the public API surface  *(API design, M6, m1, m2, m3, m5)*
- **What:** Rename `onFailedToResolveHostname`→`onError`. Convert `scheduleNotification` positional params to named. Delete or implement `enableDevTool`/`disableDevTool`/`handleNotificationClick`/`onIosTokens`. Fix copy-pasted wrong log strings. Differentiate `openAppSettings` vs `openNotificationSettings` or merge to one.
- **Why:** Lying/dead API and misleading names waste integration time and erode trust.
- **Files:** `notification_wrapper.dart`, `default_notification_handler.dart:336,509,548,595,639,697–708,745–754`.
- **Acceptance:** Every public method does what its name/docs claim; no dead stubs exported.

### T12 🟡 Fix `Rx.listenWithPrevious` or remove it  *(m6, ➕6)*
- **What:** Track the actual previous value (or delete the method). Route the debug `print` through `Logger`.
- **Files:** `rx.dart:63–73,104`.
- **Acceptance:** Test asserts `listenWithPrevious` reports the true previous value.

---

## Phase 4 — Tests, example, infra, docs

### T13 🟠 Replace the commented-out handler test with real coverage  *(Testing 2/10)*
- **What:** Delete duplicate util tests; write real tests for: channel setup reflects config (T2), id uniqueness/round-trip (T6), dispose cancels subscriptions (T7), error-callback on `Error` (T4), permission flow, FCM→local mapping. Align mocking lib (`pubspec` says `mockito`, dead test used `mocktail` — pick one).
- **Files:** `test/*`, `pubspec.yaml:27`.
- **Acceptance:** `flutter test` green; core handler logic covered (target ≥70% on `default_notification_handler.dart`).

### T14 🟠 Ship a runnable example  *(M7)*
- **What:** Add `android/` + `ios/` to `example/`; un-comment real init; demonstrate FCM receive → local display, action buttons, scheduling, badge, terminated-state.
- **Files:** `example/`.
- **Acceptance:** `cd example && flutter run` launches; README quick-start matches the example.

### T15 🟢 Add CI  *(Maintainability 3/10)*
- **What:** GitHub Actions: `flutter analyze`, `flutter test`, `dart pub publish --dry-run`, format check on PR + main.
- **Files:** `.github/workflows/ci.yaml`.
- **Acceptance:** CI green on a PR.

### T16 🟡 Docs & metadata truthfulness  *(m9, README accuracy)*
- **What:** Real CHANGELOG dates + a `1.0.0` entry documenting breaking changes (T4/T6/T9/T10/T11). Trim README to only document working features; remove `onIosTokens`/`enableDevTool` until implemented. Add migration notes.
- **Files:** `CHANGELOG.md`, `README.md`, `pubspec.yaml` (version bump).
- **Acceptance:** No documented feature is a no-op; `pub.dev` score has no "dangling docs" deductions.

---

## Suggested milestones

| Milestone | Tasks | Outcome |
|-----------|-------|---------|
| **M1 — Unblock publish** | T1–T5 | Legal + core-correctness; technically shippable as `1.0.0-dev`. |
| **M2 — Trustworthy core** | T6–T9 | No leaks, deterministic ids, opt-in permissions, no forced analytics. |
| **M3 — Clean API** | T10–T12 | Stable, non-polluting public surface. |
| **M4 — Proof & release** | T13–T16 | Tests, runnable example, CI, honest docs → tag `1.0.0`. |

## Definition of done (for `1.0.0`)
- `dart pub publish --dry-run` clean (license, no warnings).
- `flutter analyze` zero issues; `flutter test` green with core coverage.
- Example runs and demonstrates terminated-state delivery.
- No dead/lying public API; no namespace-polluting exports; no forced analytics.
- CHANGELOG documents every breaking change; README documents only what works.
