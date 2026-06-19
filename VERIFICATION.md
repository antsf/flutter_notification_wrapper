# Verification

How the package's behavior is verified, and how to reproduce the parts that
cannot be automated.

## Automated

- **Unit tests** (`flutter test`) — config→channel mapping, deterministic id
  generation, the singleton fallback, `Rx.listenWithPrevious`, and the real
  handler logic via an injected `AwesomeNotifications`/`FirebaseMessaging`
  (mocktail): `show*` create on the configured channel, `show*` return `null` and
  report `onError` on platform failure, channel setup reflects `NotificationConfig`,
  and topic/cold-start delegation.
- **Example smoke integration test** (`cd example && flutter test integration_test`)
  — drives the example on a device/emulator and proves the full
  init → channel-setup → `createNotification` path runs without crashing.

## Manual — terminated-state FCM (cannot be automated without a push server)

Displaying an FCM message while the app is **terminated** depends on the OS, a
real device, and a push from a server, so it is verified manually:

1. Configure Firebase in the example (`google-services.json` / FlutterFire) and
   set `firebaseOptions:` in `example/lib/main.dart`.
2. Build a **release** (or profile) build and install on a physical Android 13+
   device: `cd example && flutter run --release`.
3. Grant the notification permission, then fully **swipe the app away** (terminate).
4. Send a **data-only** message to the device token (omit the `notification`
   field) via FCM HTTP v1 / the Firebase console test tool:
   ```json
   { "message": { "token": "<DEVICE_TOKEN>",
       "data": { "title": "Hello", "body": "From a terminated state" } } }
   ```
5. **Expect:** a notification appears even though the app was terminated
   (AwesomeNotifications is initialized on-demand in the background isolate).
6. Tap it; on launch, `getInitialMessage()` / `getInitialAction()` returns the
   payload so the app can deep-link.

Repeat on Android < 13 with a data-only message to confirm there is no duplicate
(see the "Avoiding Duplicate Notifications" section in the README).

## Known limitations

- **Platforms:** Android & iOS only (AwesomeNotifications is mobile-only). No
  web/desktop.
- **Single shared instance:** the handler is a process-wide singleton
  (`DefaultNotificationHandler.I`); running multiple independent configurations
  is not supported.
- **Terminated-state delivery** is environment-dependent (OEM battery policies,
  permission state) and is only validated via the manual procedure above.
