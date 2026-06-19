import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notification id generation (T6)', () {
    test('generateId returns unique, positive, increasing ids in a burst', () {
      final ids = <int>[];
      for (var i = 0; i < 1000; i++) {
        ids.add(DefaultNotificationHandler.debugGenerateId());
      }

      // All positive and within 31-bit range.
      expect(ids.every((id) => id > 0 && id < 0x7FFFFFFF), isTrue);
      // No collisions across a rapid burst.
      expect(ids.toSet().length, ids.length);
      // Strictly increasing within the session.
      for (var i = 1; i < ids.length; i++) {
        expect(ids[i], greaterThan(ids[i - 1]));
      }
    });

    test('stableId is deterministic for the same key', () {
      expect(
        DefaultNotificationHandler.debugStableId('msg-123'),
        DefaultNotificationHandler.debugStableId('msg-123'),
      );
    });

    test('stableId differs for different keys and is positive', () {
      final a = DefaultNotificationHandler.debugStableId('msg-a');
      final b = DefaultNotificationHandler.debugStableId('msg-b');
      expect(a, isNot(b));
      expect(a, greaterThanOrEqualTo(0));
      expect(b, greaterThanOrEqualTo(0));
    });

    test('stableId falls back to a generated id for null/empty key', () {
      expect(DefaultNotificationHandler.debugStableId(null), greaterThan(0));
      expect(DefaultNotificationHandler.debugStableId(''), greaterThan(0));
    });
  });
}
