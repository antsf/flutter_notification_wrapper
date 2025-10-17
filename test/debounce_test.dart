// test/debounce_test.dart

import 'package:flutter_notification_wrapper/src/utils/debounce.dart'
    show Debouncer, NotificationDebouncer;
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
