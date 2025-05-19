import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

typedef MessageHandler = Future<void> Function(RemoteMessage message);
typedef NotificationTapHandler = Future<void> Function(
    Map<String, dynamic> payload);
typedef ActionReceivedHandler = Future<void> Function(ReceivedAction action);
