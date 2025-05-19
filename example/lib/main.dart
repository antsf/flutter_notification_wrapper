import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler);

  final notificationHandler = DefaultNotificationHandler();
  await notificationHandler.initialize(
    config: NotificationConfig(
      channelKey: 'custom_channel',
      channelName: 'My Custom Notifications',
      channelDescription: 'Important alerts',
      defaultColor: Colors.green,
      androidNotificationIcon:
          'resource://drawable/notification_icon', // Must exist in /android/app/src/main/res/
    ),
    // firebaseOptions: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Wrapper',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}
