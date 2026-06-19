# flutter_notification_wrapper — example

A runnable demo of [`flutter_notification_wrapper`](../). It exercises the local
notification features on a single screen:

- Request notification permission (contextually, not at startup)
- Regular notification (returns its id)
- Action-button notification
- Reply notification
- Scheduled notification (+5s)
- Grouped notifications
- Badge set / clear
- Cancel all

## Run it

```bash
cd example
flutter pub get
flutter run
```

The example runs **without Firebase configured** — every feature above is served
by AwesomeNotifications alone, so you can try the package in under a minute.

## Enabling Firebase Cloud Messaging (optional)

To receive push messages (foreground / background / terminated):

1. Add `google-services.json` to `android/app/` and
   `GoogleService-Info.plist` to `ios/Runner/`.
2. Generate `firebase_options.dart` with the
   [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup):
   ```bash
   flutterfire configure
   ```
3. Pass the options in `lib/main.dart`:
   ```dart
   await DefaultNotificationHandler.initializeSharedInstance(
     config: config,
     firebaseOptions: DefaultFirebaseOptions.currentPlatform,
   );
   ```

## Android 13+ note

`POST_NOTIFICATIONS` is already declared in
`android/app/src/main/AndroidManifest.xml`. Without it, notifications won't show
on Android 13+ even after the runtime permission is granted.

See the [package README](../README.md) for the full API and configuration guide.
