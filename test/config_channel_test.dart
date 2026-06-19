import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationConfig -> NotificationChannel mapping (T2)', () {
    test('silent() maps to a genuinely silent, low-importance channel', () {
      final channel = NotificationConfig.silent(
        channelKey: 'silent_sync',
        channelName: 'Silent Sync',
      ).toNotificationChannel();

      // These are exactly the properties the old code silently discarded.
      expect(channel.importance, NotificationImportance.Min);
      expect(channel.playSound, isFalse);
      expect(channel.channelShowBadge, isFalse);
      expect(channel.enableVibration, isFalse);
      expect(channel.enableLights, isFalse);
      expect(channel.defaultPrivacy, NotificationPrivacy.Secret);
    });

    test('highPriority() maps to a max-importance channel', () {
      final channel = NotificationConfig.highPriority(
        channelKey: 'urgent',
        channelName: 'Urgent',
      ).toNotificationChannel();

      expect(channel.importance, NotificationImportance.Max);
      expect(channel.groupAlertBehavior, GroupAlertBehavior.All);
    });

    test('custom importance/sound flow through to the channel', () {
      final channel = const NotificationConfig(
        channelKey: 'c',
        channelName: 'C',
        importance: NotificationImportance.Low,
        playSound: false,
        enableVibration: false,
      ).toNotificationChannel();

      expect(channel.importance, NotificationImportance.Low);
      expect(channel.playSound, isFalse);
      expect(channel.enableVibration, isFalse);
    });
  });

  group('NotificationConfig new fields (T9)', () {
    test('wakeUpScreen and category default conservatively', () {
      const config = NotificationConfig(channelKey: 'c', channelName: 'C');
      expect(config.wakeUpScreen, isFalse);
      expect(config.category, isNull);
    });

    test('copyWith updates wakeUpScreen and category', () {
      const config = NotificationConfig(channelKey: 'c', channelName: 'C');
      final updated = config.copyWith(
        wakeUpScreen: true,
        category: NotificationCategory.Alarm,
      );
      expect(updated.wakeUpScreen, isTrue);
      expect(updated.category, NotificationCategory.Alarm);
    });

    test('equality accounts for the new fields', () {
      const a = NotificationConfig(channelKey: 'c', channelName: 'C');
      final b = a.copyWith(wakeUpScreen: true);
      expect(a, isNot(b));
    });
  });
}
