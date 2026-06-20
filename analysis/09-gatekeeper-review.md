# Gatekeeper Review — `flutter_notification_wrapper@1.0.0`

> ✅ **ADDRESSED in `1.0.0-beta.1`.** All blockers (#1–#8) plus Phase A/B/C of the
> action plan were implemented: wiki link removed, README/CHANGELOG fixed,
> re-versioned to beta, `getInitialMessage()/getInitialAction()`, event streams,
> `Future<int?>` show methods, an injectable plugin seam + real handler tests,
> FCM topics, big-picture helper, and a terminated-state verification procedure
> ([`../VERIFICATION.md`](../VERIFICATION.md)). This document is retained as the
> pre-hardening assessment.

> Strict "does this deserve to be on Pub.dev" audit of the **current `main`
> (v1.0.0)**, after the overhaul in PR #5. Date: 2026-06-20.
> Companion to [`06-brutal-review.md`](06-brutal-review.md) (review of `0.3.0`)
> and [`08-implementation-plan.md`](08-implementation-plan.md) (the overhaul).

---

## Core question

**"Would you personally feel comfortable recommending this package to the
Flutter community?"**

**Not as a *recommendation* — yet. But it is now *safe to publish*.** The v1.0.0
overhaul removed the things that made the old version embarrassing (placeholder
license, inert config, AI transcript in source, crash-on-error, leaks). What
remains is a *competent but unremarkable* wrapper: global-singleton design, a
leaky "unified" abstraction, near-zero tests on the risky code, and thin
differentiation versus incumbents. Publishable — not yet respected-package
material.

**Verdict: B — PUBLISH AFTER MINOR CHANGES** (and as `0.x`/`1.0.0-beta`, not a
bare `1.0.0`).

---

## Missing features (expected, not found)

1. **Stream-based event API.** Everything goes through constructor callbacks
   (`onMessageOverride`, `handleActionReceivedOverride`). Idiomatic packages
   expose `Stream`s consumable anywhere. Forcing all handlers into one init call
   means you can't react to a tap from a screen built later. **#1 DX gap.**
2. **No `getInitialMessage()` / `getInitialAction()`** cold-start retrieval —
   the canonical "deep-link from a terminated notification tap" need. Conspicuous
   for a package whose headline is background/terminated handling.
3. **`refreshToken(callback)` instead of `Stream<String> get onTokenRefresh`** —
   non-idiomatic, single-listener.
4. **No FCM topic subscription** (`subscribeToTopic` / `unsubscribeFromTopic`).
5. **No exposed rich layouts (media/big-picture/progress)** through the unified
   API — you drop to raw `NotificationContent`, defeating "unified".
6. **No web/desktop** (awesome_notifications is mobile-only) — yet README says
   "Cross-Platform".

---

## Missing / weak documentation

1. **`pubspec.yaml: documentation:` points to a GitHub wiki** that almost
   certainly doesn't exist → broken link → pub.dev score hit + bad first
   impression.
2. **`CHANGELOG.md` placeholder dates** `2024-01-XX` for 0.1.0/0.2.0/0.3.0.
3. **README overclaims** — lists "Debug Tools" and "Reactive State" as headline
   features of a notifications package; "comprehensive"/"Full support".
4. **No terminated-state deep-link recipe**, no `dispose()` lifecycle guidance
   for the global singleton, no note that custom background handlers must be
   top-level `@pragma('vm:entry-point')`.
5. **README on `main` still references `notification_icon`** while the code
   default is `ic_notification` (fixed in unmerged PR #6).

---

## API problems

- **Global singleton `DefaultNotificationHandler.I`** — global mutable state;
  can't run two configs; hostile to testing (no injection); the on-the-fly
  `get I` fallback silently fabricates an instance, hiding misconfiguration.
- **`show*` returns an `int` id even on failure** — caught error → `onError` →
  `return id`. Caller gets an id for a notification that may not exist;
  `cancelNotification(id)` becomes a silent no-op. Return value is not a reliable
  success signal. Prefer `Future<int?>` (null on failure) or rethrow.
- **`requestPermissions()` returns only the FCM `AuthorizationStatus`** while
  also requesting AwesomeNotifications permission separately; the two can
  disagree and the return type can't express it.
- **`simulateNotification` is redundant** with `showRegularNotification`.
- **Abstraction leaks both SDKs** — `showGroupedNotification(List<NotificationContent>)`,
  `ReceivedAction`, `RemoteMessage`. The "unified interface" still requires
  fluency in both libraries; re-exporting their types hard-couples your public
  API to their versioning.
- **`NotificationConfig.custom()`** duplicates the default constructor verbatim.

---

## Architecture problems

- **Tight coupling to two fast-moving upstreams you re-export** — their breaking
  changes become yours, and consumers feel them directly.
- **No dependency-injection seam** — `AwesomeNotifications()` /
  `FirebaseMessaging.instance` are concrete singletons throughout. This is why
  your own tests can't cover real logic and consumers can't unit-test against
  the package. **Biggest architectural weakness.**
- **Abstract `NotificationWrapper` reaches into concrete `DefaultNotificationHandler.I`**
  (default background handler) — abstraction depends on implementation.
- **Bundled mini-framework** (`Rx`, `RxBool`, `RxList`, `Debouncer`, `Logger`) —
  scope creep you must maintain forever; respected packages do one thing.

---

## Performance / production risks

- Resource lifecycle is now **correct** (subscriptions cancelled, single refresh
  listener, Rx disposed). Remaining awkwardness: `dispose()` ownership on a
  global singleton across hot restarts / `ReceivePort` name mapping.
- **ID generator resets per process** (`_lastGeneratedId → 0`); reseeded from
  wall-clock, so cross-session collision is unlikely but not impossible.
- **`_stableId = String.hashCode & 0x7FFFFFFF`** — two distinct `messageId`s can
  collide over 31 bits → one notification overwrites another. Rare; ugly when it
  happens in chat/payments.
- **`_permissionRequestLock` is a plain `bool`**, not await-safe.
- **Biggest production risk: the terminated-state path is unverified.** The fix
  is plausible but there is **no integration test and no device proof** that a
  cold-start FCM message actually displays — the package's entire raison d'être.

---

## Testing — the honest gap

`flutter test` → **52 green**, but coverage is misleading: tests cover
`NotificationConfig`→channel mapping, id-generator uniqueness, the singleton
fallback, and `Rx`/`Debouncer`/`Logger`. **Zero tests touch the real flow**
(FCM→display, channel creation, permission flow, action routing, background
isolate) because the platform singletons aren't injectable. The riskiest ~80% of
the package has no automated verification.

---

## Community adoption risks

- **Avoid:** adds a dependency + a second display engine + Firebase to save ~an
  afternoon of wiring devs would rather own.
- **Uninstall:** first upstream breaking change blocks them on your compat
  release; or a terminated-state notification silently fails and they can't
  debug through the abstraction.
- **Maintainers won't recommend:** global singleton, no DI/testability, leaky
  abstraction, 1.0.0 with no track record.
- **Teams reject:** can't unit-test against it; pulls Firebase + awesome
  transitively; "1.0.0" overpromises.

---

## Competitor analysis

- **`flutter_local_notifications`** — de-facto standard; Android/iOS/Linux/macOS;
  years of hardening; rich layouts; `getNotificationAppLaunchDetails()`. **Yours
  is worse** on breadth, maturity, testability, trust; *arguably better* only via
  its opinionated FCM + always-local-display-on-Android-13 default.
- **`firebase_messaging`** (official) — you wrap it, don't beat it.
- **`awesome_notifications`** — you wrap and re-export it; inherit its surface
  without hiding it.
- **Real niche:** FCM + local-display + Android-13 permission/display glue that
  devs hand-wire today. Real but narrow; your value-add is convenience, not
  capability. Devs switch only if the wrapper is rock-solid — not proven yet.

---

## DO NOT PUBLISH YET (blockers, by severity)

| # | Severity | Issue | Impact | Fix |
|---|----------|-------|--------|-----|
| 1 | **High** | `documentation:` → non-existent wiki | Broken link, pub.dev score hit | Create wiki or remove field |
| 2 | **High** | README (main) stale `notification_icon` + overclaims "Debug Tools/Reactive State" | Misleads users; icon mismatch breaks setup | Merge PR #6; trim feature list |
| 3 | **Medium** | CHANGELOG `2024-01-XX` placeholder dates | Reads as careless | Real dates or collapse pre-1.0 history |
| 4 | **Medium** | No `getInitialMessage()/getInitialAction()` cold-start retrieval | Can't deep-link from terminated tap | Add, or document omission loudly |
| 5 | **Medium** | `show*` returns id even on failure | Silent cancel no-ops; dishonest return | `Future<int?>` or rethrow |
| 6 | **Medium** | Terminated-state path unverified | Headline reliability unproven | Integration test or documented manual verification + known-limitations note |
| 7 | **Low** | Global singleton, no DI seam | Limits consumer testability | Document now; injectable instance in 1.x |
| 8 | **Low** | CI `actions/checkout@v4` (Node 20 deprecation) | Warning noise | Bump to `@v5` |

None are "broken/dangerous" — they're "don't put your name on it until fixed".
#1–#3 + #8 are ~an hour; #4–#6 are the gap between *publishable* and
*recommendable*.

---

## Recommended action plan (ordered)

**Phase A — cheap publish-cleanup (do first, ~1h):**
- A1. Remove or fix `pubspec.yaml: documentation:` (drop the wiki link).
- A2. Merge PR #6 (README icon/branding + example README) and trim the README
  feature list to the core (move "reactive utilities" to a one-line "extras").
- A3. Fix CHANGELOG placeholder dates.
- A4. Bump CI `actions/checkout@v4` → `@v5`.
- A5. **Re-version to `1.0.0-beta.1`** (or `0.9.0`) — a fresh, untested-in-the-wild
  rewrite should not claim bare `1.0.0` stability.

**Phase B — earn "recommendable" (before a stable 1.0.0):**
- B1. Add `getInitialMessage()` / `getInitialAction()` for cold-start deep links.
- B2. Add stream getters: `Stream<RemoteMessage> get onMessageOpened`,
  `Stream<ReceivedAction> get onActionReceived`, `Stream<String> get onTokenRefresh`.
- B3. Make `show*` honest: `Future<int?>` (null on failure) or rethrow.
- B4. Add an injection seam (constructor-injectable `AwesomeNotifications` /
  `FirebaseMessaging`) so the core flow becomes testable; add real handler tests.
- B5. Add one integration test (or a documented, repeatable manual procedure)
  proving terminated-state display on Android 13+.
- B6. Decide the fate of the bundled `Rx`/`Debouncer` utilities (keep minimal,
  or split out) to narrow scope.

**Phase C — optional differentiation:**
- C1. `subscribeToTopic` / `unsubscribeFromTopic`.
- C2. Richer unified layout helpers (big-picture / media / progress).

---

## Final decision: Verdict B — PUBLISH AFTER MINOR CHANGES

The hard blockers are gone — licensed, config works, resources clean, errors
don't crash, example runs, CI green, dry-run 0 warnings. But it is not
presentable until Phase A lands, and not *recommendable* until Phase B. Ship
Phase A as **`1.0.0-beta.1`**, gather real-world mileage, then graduate to a
stable `1.0.0` after Phase B.

---

## Confidence check

1. **Recommend if published tomorrow?** No — only "works for the FCM+local glue
   niche; evaluate vs wiring it yourself."
2. **Use in my own production app?** No — I'd use `firebase_messaging` +
   `flutter_local_notifications` directly, unless I specifically wanted the
   Android-13 always-local-display default.
3. **Let my team depend on it?** Not at 1.0.0 with no integration tests + global
   singleton. Maybe after hardening.
4. **Experienced devs respect it?** Neutral-to-mild. They'd respect the cleanup
   and honest migration notes; be skeptical of the singleton, leaky abstraction,
   thin tests.
5. **Solves a real problem better than alternatives?** More *conveniently* for a
   narrow glue case; not *better* in capability, breadth, or trust.
6. **Potential to become recommended?** Yes — if Phase B lands and it survives a
   couple of upstream breaking-change cycles cleanly.
7. **Biggest reason it could fail:** thin wrapper over two fast-moving SDKs with
   no testability seam and unproven terminated-state reliability — upside
   (saved boilerplate) < downside (inherited breakage + undebuggable abstraction)
   for serious teams.
8. **Biggest reason it could succeed:** it nails a genuinely annoying, commonly
   re-wired integration (FCM + AwesomeNotifications + Android-13 consistency)
   behind one opinionated default — if proven reliable, that convenience is worth
   a dependency to many small/mid teams.
