import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DefaultNotificationHandler singleton', () {
    tearDown(DefaultNotificationHandler.resetInstance);

    test('I returns a stable singleton instance', () {
      final a = DefaultNotificationHandler.I;
      final b = DefaultNotificationHandler.I;
      expect(identical(a, b), isTrue);
    });

    test('on-the-fly instance gets the background fallback config (T5)', () {
      // Accessing I before initializeSharedInstance simulates a background
      // isolate. It must receive a usable fallback config so background
      // notifications can still be displayed.
      final handler = DefaultNotificationHandler.I;
      expect(handler.debugConfig, isNotNull);
      expect(handler.debugConfig!.channelKey, 'fallback_background_channel');
    });

    test('resetInstance clears the singleton', () {
      final first = DefaultNotificationHandler.I;
      DefaultNotificationHandler.resetInstance();
      final second = DefaultNotificationHandler.I;
      expect(identical(first, second), isFalse);
    });
  });
}
