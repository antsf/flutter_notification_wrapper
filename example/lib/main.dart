// import 'package:firebase_messaging/firebase_messaging.dart';
// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/material.dart';
import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';
import 'screens/home_screen.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler);

//   final notificationHandler = DefaultNotificationHandler();
//   await notificationHandler.initialize(
//     config: NotificationConfig(
//       channelKey: 'custom_channel',
//       channelName: 'My Custom Notifications',
//       channelDescription: 'Important alerts',
//       defaultColor: Colors.green,
//       androidNotificationIcon:
//           'resource://drawable/notification_icon', // Must exist in /android/app/src/main/res/
//     ),
//     // firebaseOptions: DefaultFirebaseOptions.currentPlatform,
//   );

//   runApp(const MyApp());
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Notification Wrapper',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: HomeScreen(),
      );
}

// // main.dart (or your app's entry point)
// import 'package:your_app/notifications/default_notification_handler.dart';
// import 'package:your_app/notifications/notification_config.dart';
// import 'package:firebase_core/firebase_core.dart';
// // Import your Firebase options if you have them generated (firebase_options.dart)
// // import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Initialize Firebase (if not using firebase_options.dart directly in handler) ---
  // If you have a firebase_options.dart, you can pass DefaultFirebaseOptions.currentPlatform
  // Or, initialize it here if DefaultNotificationHandler won't do it with options.
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform, // If you have firebase_options.dart
  // );

  // --- Configure and Initialize Notification Handler ---
  const notificationConfig = NotificationConfig(
    channelKey: 'app_channel_01',
    channelName: 'App General Notifications',
    channelDescription: 'Main notification channel for the app.',
    androidNotificationIcon:
        'resource://drawable/ic_stat_notification', // Replace with your icon
    defaultColor: Colors.teal,
  );

  // Initialize the shared instance of the notification handler
  await DefaultNotificationHandler.initializeSharedInstance(
    config: notificationConfig,
    // firebaseOptions: DefaultFirebaseOptions
    //     .currentPlatform, // If using firebase_options.dart
    // Optionally, provide custom handlers here if you don't want the defaults
    // from NotificationWrapper or if you want to override specific ones for this app instance:
    // onMessageOverride: (RemoteMessage message) {
    //   print("Custom foreground message handler: ${message.data}");
    //   DefaultNotificationHandler.I.showNotification(message); // Example: still show it
    // },
    // onBackgroundMessageOverride: (RemoteMessage message) async {
    //   print("Custom background message handler: ${message.data}");
    //   await DefaultNotificationHandler.I.showNotification(message);
    // }
  );

  runApp(const MyApp());
}
