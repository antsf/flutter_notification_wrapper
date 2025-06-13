import 'package:firebase_messaging/firebase_messaging.dart';
import 'default_notification_handler.dart';

Future<void> backgroundMessageHandler(RemoteMessage message) async {
  await DefaultNotificationHandler.I.onBackgroundMessage(message);
}
