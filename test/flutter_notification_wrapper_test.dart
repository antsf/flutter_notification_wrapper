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

  group('Logger', () {
    test('should create logger with name', () {
      const logger = Logger('TestLogger');
      expect(logger.name, 'TestLogger');
    });

    test('should create logger for class', () {
      final logger = Logger.forClass(String);
      expect(logger.name, 'String');
    });

    test('should create logger for feature', () {
      final logger = Logger.forFeature('Notifications');
      expect(logger.name, 'Feature:Notifications');
    });

    test('should implement equality correctly', () {
      const logger1 = Logger('Test');
      const logger2 = Logger('Test');
      const logger3 = Logger('Different');

      expect(logger1, equals(logger2));
      expect(logger1, isNot(equals(logger3)));
      expect(logger1.hashCode, equals(logger2.hashCode));
    });
  });

  group('Debouncer', () {
    test('should create debouncer with delay', () {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      expect(debouncer.delay, const Duration(milliseconds: 100));
      expect(debouncer.isActive, false);
    });

    test('should execute action after delay', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 50));
      var executed = false;

      debouncer.run(() {
        executed = true;
      });

      expect(debouncer.isActive, true);
      expect(executed, false);

      await Future.delayed(const Duration(milliseconds: 60));

      expect(executed, true);
      expect(debouncer.isActive, false);
    });

    test('should cancel previous action when called again', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      var executionCount = 0;

      debouncer.run(() {
        executionCount++;
      });

      await Future.delayed(const Duration(milliseconds: 50));

      debouncer.run(() {
        executionCount++;
      });

      await Future.delayed(const Duration(milliseconds: 120));

      expect(executionCount, 1); // Only the second action should execute
    });

    test('should cancel pending action', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 100));
      var executed = false;

      debouncer.run(() {
        executed = true;
      });

      expect(debouncer.isActive, true);

      debouncer.cancel();

      expect(debouncer.isActive, false);

      await Future.delayed(const Duration(milliseconds: 120));

      expect(executed, false);
    });
  });

  group('NotificationDebouncer', () {
    test('should track last message ID', () async {
      final debouncer =
          NotificationDebouncer(delay: const Duration(milliseconds: 50));
      var executionCount = 0;

      debouncer.runForMessage('message1', () {
        executionCount++;
      });

      expect(debouncer.lastMessageId, 'message1');

      // Wait for the first action to execute
      await Future.delayed(const Duration(milliseconds: 60));
      expect(executionCount, 1);

      // Same message ID should not execute again
      debouncer.runForMessage('message1', () {
        executionCount++;
      });

      await Future.delayed(const Duration(milliseconds: 60));
      expect(executionCount, 1); // Should still be 1

      // Different message ID should execute
      debouncer.runForMessage('message2', () {
        executionCount++;
      });

      await Future.delayed(const Duration(milliseconds: 60));
      expect(executionCount, 2);
      expect(debouncer.lastMessageId, 'message2');
    });

    test('should reset last message ID', () async {
      final debouncer =
          NotificationDebouncer(delay: const Duration(milliseconds: 50));
      var executionCount = 0;

      debouncer.runForMessage('message1', () {
        executionCount++;
      });

      expect(debouncer.lastMessageId, 'message1');

      // Wait for execution
      await Future.delayed(const Duration(milliseconds: 60));
      expect(executionCount, 1);

      debouncer.resetLastMessageId();

      expect(debouncer.lastMessageId, null);

      // Same message ID should execute after reset
      debouncer.runForMessage('message1', () {
        executionCount++;
      });

      await Future.delayed(const Duration(milliseconds: 60));
      expect(executionCount, 2);
    });
  });

  group('Rx', () {
    test('should create reactive value', () {
      final rx = Rx<int>(0);
      expect(rx.value, 0);
    });

    test('should notify listeners on value change', () {
      final rx = Rx<int>(0);
      int? notifiedValue;

      rx
        ..listen((value) {
          notifiedValue = value;
        })
        ..value = 5;

      expect(notifiedValue, 5);
    });

    test('should not notify listeners if value unchanged', () {
      final rx = Rx<int>(0);
      var notificationCount = 0;

      rx
        ..listen((value) {
          notificationCount++;
        })
        ..value = 0; // Same value

      expect(notificationCount, 0);
    });

    test('should update value using function', () {
      final rx = Rx<int>(5)..update((current) => current * 2);

      expect(rx.value, 10);
    });

    test('should remove listener', () {
      final rx = Rx<int>(0);
      var notificationCount = 0;

      void listener(int value) {
        notificationCount++;
      }

      rx
        ..listen(listener)
        ..value = 1;
      expect(notificationCount, 1);

      rx
        ..removeListener(listener)
        ..value = 2;
      expect(notificationCount, 1); // Should not increase
    });

    test('should clear all listeners', () {
      final rx = Rx<int>(0);
      var notificationCount = 0;

      rx
        ..listen((value) => notificationCount++)
        ..listen((value) => notificationCount++)
        ..value = 1;
      expect(notificationCount, 2);

      rx
        ..clearListeners()
        ..value = 2;
      expect(notificationCount, 2); // Should not increase
    });

    test('should implement equality correctly', () {
      final rx1 = Rx<int>(5);
      final rx2 = Rx<int>(5);
      final rx3 = Rx<int>(10);

      expect(rx1, equals(rx2));
      expect(rx1, isNot(equals(rx3)));
      expect(rx1.hashCode, equals(rx2.hashCode));
    });
  });

  group('RxBool', () {
    test('should toggle value', () {
      final rxBool = RxBool(false)..toggle();
      expect(rxBool.value, true);

      rxBool.toggle();
      expect(rxBool.value, false);
    });

    test('should set true and false', () {
      final rxBool = RxBool(false)..setTrue();
      expect(rxBool.value, true);
      expect(rxBool.isTrue, true);
      expect(rxBool.isFalse, false);

      rxBool.setFalse();
      expect(rxBool.value, false);
      expect(rxBool.isTrue, false);
      expect(rxBool.isFalse, true);
    });
  });

  group('RxInt', () {
    test('should increment and decrement', () {
      final rxInt = RxInt(5)..increment();
      expect(rxInt.value, 6);

      rxInt.decrement();
      expect(rxInt.value, 5);
    });

    test('should add and subtract', () {
      final rxInt = RxInt(10)..add(5);
      expect(rxInt.value, 15);

      rxInt.subtract(3);
      expect(rxInt.value, 12);
    });

    test('should multiply', () {
      final rxInt = RxInt(4)..multiply(3);
      expect(rxInt.value, 12);
    });

    test('should check zero, positive, negative', () {
      final rxInt = RxInt(0);
      expect(rxInt.isZero, true);
      expect(rxInt.isPositive, false);
      expect(rxInt.isNegative, false);

      rxInt.value = 5;
      expect(rxInt.isZero, false);
      expect(rxInt.isPositive, true);
      expect(rxInt.isNegative, false);

      rxInt.value = -3;
      expect(rxInt.isZero, false);
      expect(rxInt.isPositive, false);
      expect(rxInt.isNegative, true);
    });
  });

  group('RxString', () {
    test('should append and prepend', () {
      final rxString = RxString('Hello')..append(' World');
      expect(rxString.value, 'Hello World');

      rxString.prepend('Hi ');
      expect(rxString.value, 'Hi Hello World');
    });

    test('should clear string', () {
      final rxString = RxString('Hello')..clear();
      expect(rxString.value, '');
      expect(rxString.isEmpty, true);
      expect(rxString.isNotEmpty, false);
    });

    test('should check length', () {
      final rxString = RxString('Hello');
      expect(rxString.length, 5);

      rxString.append(' World');
      expect(rxString.length, 11);
    });
  });

  group('RxList', () {
    test('should add and remove items', () {
      final rxList = RxList<String>()..add('item1');
      expect(rxList.value, ['item1']);
      expect(rxList.length, 1);
      expect(rxList.isEmpty, false);
      expect(rxList.isNotEmpty, true);

      rxList.addAll(['item2', 'item3']);
      expect(rxList.value, ['item1', 'item2', 'item3']);
      expect(rxList.length, 3);

      rxList.remove('item2');
      expect(rxList.value, ['item1', 'item3']);

      rxList.removeAt(0);
      expect(rxList.value, ['item3']);
    });

    test('should clear list', () {
      final rxList = RxList<String>(['item1', 'item2'])..clear();
      expect(rxList.value, []);
      expect(rxList.isEmpty, true);
      expect(rxList.length, 0);
    });

    test('should get first and last items', () {
      final rxList = RxList<String>(['first', 'middle', 'last']);

      expect(rxList.firstOrNull, 'first');
      expect(rxList.lastOrNull, 'last');

      rxList.clear();
      expect(rxList.firstOrNull, null);
      expect(rxList.lastOrNull, null);
    });
  });
}
