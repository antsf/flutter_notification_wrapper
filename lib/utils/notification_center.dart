import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationCenter {
  static final List<int> receivedIds = [];
  static final Map<int, RemoteMessage> messageMap = {};

  static void add(int id, RemoteMessage message) {
    receivedIds.add(id);
    messageMap[id] = message;
  }

  static List<RemoteMessage> getAllMessages() => messageMap.values.toList();
}
