// test/notification_center_test.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_notification_wrapper/src/utils/notification_center.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationCenter', () {
    tearDown(() {
      NotificationCenter.receivedIds.clear();
      NotificationCenter.messageMap.clear();
    });

    test('should add message', () {
      const message = RemoteMessage(messageId: 'test1');

      NotificationCenter.add(1, message);

      expect(NotificationCenter.receivedIds, [1]);
      expect(NotificationCenter.messageMap[1], message);
    });

    test('should get all messages', () {
      const message1 = RemoteMessage(messageId: 'test1');
      const message2 = RemoteMessage(messageId: 'test2');

      NotificationCenter.add(1, message1);
      NotificationCenter.add(2, message2);

      expect(NotificationCenter.getAllMessages(), [message1, message2]);
    });
  });
}
