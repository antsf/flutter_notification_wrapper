// test/notification_config_test.dart
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationConfig', () {
    test('should create default config', () {
      final config = NotificationConfig.defaultConfig();

      expect(config.channelKey, 'basic_channel');
      expect(config.channelName, 'Basic notifications');
      expect(config.importance, NotificationImportance.High);
      expect(config.channelShowBadge, true);
      expect(config.playSound, true);
    });

    test('should create high priority config', () {
      final config = NotificationConfig.highPriority(
        channelKey: 'urgent',
        channelName: 'Urgent Notifications',
      );

      expect(config.channelKey, 'urgent');
      expect(config.importance, NotificationImportance.Max);
      expect(config.groupAlertBehavior, GroupAlertBehavior.All);
    });

    test('should create low priority config', () {
      final config = NotificationConfig.lowPriority(
        channelKey: 'background',
        channelName: 'Background Notifications',
      );

      expect(config.channelKey, 'background');
      expect(config.importance, NotificationImportance.Low);
      expect(config.channelShowBadge, false);
      expect(config.playSound, false);
    });

    test('should validate configuration', () {
      const validConfig = NotificationConfig(
        channelKey: 'valid_channel',
        channelName: 'Valid Channel',
      );

      expect(validConfig.isValid, true);
      expect(validConfig.validate(), isEmpty);
    });

    test('should detect invalid configuration', () {
      const invalidConfig = NotificationConfig(
        channelKey: '', // Empty channel key
        channelName: 'Valid Channel',
      );

      expect(invalidConfig.isValid, false);
      expect(invalidConfig.validate(), contains('channelKey cannot be empty'));
    });

    test('should detect channel key with spaces', () {
      const invalidConfig = NotificationConfig(
        channelKey: 'invalid channel', // Contains space
        channelName: 'Valid Channel',
      );

      expect(invalidConfig.isValid, false);
      expect(
        invalidConfig.validate(),
        contains('channelKey should not contain spaces'),
      );
    });

    test('should convert to NotificationChannel', () {
      const config = NotificationConfig(
        channelKey: 'test_channel',
        channelName: 'Test Channel',
        channelDescription: 'Test Description',
        defaultColor: Color(0xff2196f3), // Use Color instead of Colors.blue
      );

      final channel = config.toNotificationChannel();

      expect(channel.channelKey, 'test_channel');
      expect(channel.channelName, 'Test Channel');
      expect(channel.channelDescription, 'Test Description');
      expect(channel.importance, NotificationImportance.High);
      expect(channel.defaultColor, const Color(0xff2196f3));
    });

    test('should create copy with modified values', () {
      final original = NotificationConfig.defaultConfig();
      final copy = original.copyWith(
        channelName: 'Modified Name',
        importance: NotificationImportance.Low,
      );

      expect(copy.channelKey, original.channelKey); // Unchanged
      expect(copy.channelName, 'Modified Name'); // Changed
      expect(copy.importance, NotificationImportance.Low); // Changed
      expect(copy.channelShowBadge, original.channelShowBadge); // Unchanged
    });

    test('should implement equality correctly', () {
      const config1 = NotificationConfig(
        channelKey: 'test',
        channelName: 'Test',
      );
      const config2 = NotificationConfig(
        channelKey: 'test',
        channelName: 'Test',
      );
      const config3 = NotificationConfig(
        channelKey: 'different',
        channelName: 'Test',
      );

      expect(config1, equals(config2));
      expect(config1, isNot(equals(config3)));
      expect(config1.hashCode, equals(config2.hashCode));
    });
  });
}
