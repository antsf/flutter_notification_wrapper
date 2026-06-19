import 'package:flutter/material.dart';
import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';

import 'screens/home_screen.dart';

/// Demonstrates flutter_notification_wrapper end-to-end.
///
/// This example runs WITHOUT Firebase configured: it shows the local
/// notification features (regular / action / reply / scheduled / grouped /
/// badges) which work through AwesomeNotifications alone.
///
/// To enable Firebase Cloud Messaging:
///  1. Add `google-services.json` (Android) / `GoogleService-Info.plist` (iOS).
///  2. Generate `firebase_options.dart` with the FlutterFire CLI.
///  3. Pass `firebaseOptions: DefaultFirebaseOptions.currentPlatform` below.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const config = NotificationConfig(
    channelKey: 'app_channel_01',
    channelName: 'App General Notifications',
    channelDescription: 'Main notification channel for the example app.',
    defaultColor: Colors.teal,
    // androidNotificationIcon: 'resource://drawable/ic_stat_notification',
  );

  await DefaultNotificationHandler.initializeSharedInstance(
    config: config,
    // firebaseOptions: DefaultFirebaseOptions.currentPlatform,
    onError: (error, stackTrace) =>
        debugPrint('Notification error: $error\n$stackTrace'),
    onPermissionEvent: (name, params) =>
        debugPrint('Permission event: $name $params'),
    handleActionReceivedOverride: (action) async {
      debugPrint('Action received: ${action.buttonKeyPressed} '
          'input="${action.buttonKeyInput}" payload=${action.payload}');
    },
  );

  // Cold-start deep links: read whatever launched the app from a terminated
  // state (null in the common case).
  final initialMessage = await DefaultNotificationHandler.I.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('Launched from FCM message: ${initialMessage.data}');
  }
  final initialAction = await DefaultNotificationHandler.I.getInitialAction();
  if (initialAction != null) {
    debugPrint('Launched from notification action: ${initialAction.payload}');
  }

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Notification Wrapper Example',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const HomeScreen(),
      );
}
