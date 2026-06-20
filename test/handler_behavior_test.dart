import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAwesomeNotifications extends Mock implements AwesomeNotifications {}

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

void main() {
  setUpAll(() {
    registerFallbackValue(<NotificationChannel>[]);
    registerFallbackValue(
      NotificationContent(id: 0, channelKey: 'fallback'),
    );
  });

  late MockAwesomeNotifications awesome;

  setUp(() {
    DefaultNotificationHandler.resetInstance();
    awesome = MockAwesomeNotifications();
    when(() => awesome.initialize(any(), any(), debug: any(named: 'debug')))
        .thenAnswer((_) async => true);
  });

  tearDown(DefaultNotificationHandler.resetInstance);

  group('show* behaviour (B3/B4)', () {
    test('showRegularNotification creates on the config channel and returns id',
        () async {
      when(() => awesome.createNotification(content: any(named: 'content')))
          .thenAnswer((_) async => true);

      final handler = DefaultNotificationHandler.createForTest(
        awesomeNotifications: awesome,
        config: const NotificationConfig(
          channelKey: 'chat_channel',
          channelName: 'Chat',
        ),
      );

      final id = await handler.showRegularNotification(title: 't', body: 'b');

      expect(id, isNotNull);
      final content = verify(
        () => awesome.createNotification(content: captureAny(named: 'content')),
      ).captured.single as NotificationContent;
      expect(content.channelKey, 'chat_channel');
      expect(content.id, id);
      expect(content.title, 't');
    });

    test('show* returns null and reports onError when the platform fails',
        () async {
      when(() => awesome.createNotification(content: any(named: 'content')))
          .thenThrow(Exception('platform failure'));

      Object? reported;
      final handler = DefaultNotificationHandler.createForTest(
        awesomeNotifications: awesome,
        config: const NotificationConfig(channelKey: 'c', channelName: 'C'),
        onError: (error, _) => reported = error,
      );

      final id = await handler.showRegularNotification(title: 't', body: 'b');

      expect(id, isNull, reason: 'failed notification must not return an id');
      expect(reported, isA<Exception>());
    });

    test('channel setup reflects NotificationConfig (silent -> Min/no sound)',
        () async {
      when(() => awesome.createNotification(content: any(named: 'content')))
          .thenAnswer((_) async => true);

      final handler = DefaultNotificationHandler.createForTest(
        awesomeNotifications: awesome,
        config: NotificationConfig.silent(
          channelKey: 'silent_channel',
          channelName: 'Silent',
        ),
      );

      // First show triggers lazy channel initialization.
      await handler.showRegularNotification(title: 't', body: 'b');

      final channels = verify(
        () => awesome.initialize(
          any(),
          captureAny(),
          debug: any(named: 'debug'),
        ),
      ).captured.single as List<NotificationChannel>;
      final main = channels.firstWhere((c) => c.channelKey == 'silent_channel');
      expect(main.importance, NotificationImportance.Min);
      expect(main.playSound, isFalse);
      expect(main.channelShowBadge, isFalse);
    });
  });

  group('FCM topics + cold start (B1/C1)', () {
    test(
        'subscribeToTopic / unsubscribeFromTopic delegate to FirebaseMessaging',
        () async {
      final messaging = MockFirebaseMessaging();
      when(() => messaging.subscribeToTopic(any())).thenAnswer((_) async {});
      when(() => messaging.unsubscribeFromTopic(any()))
          .thenAnswer((_) async {});

      final handler = DefaultNotificationHandler.createForTest(
        awesomeNotifications: awesome,
        firebaseMessaging: messaging,
        config: const NotificationConfig(channelKey: 'c', channelName: 'C'),
      );

      await handler.subscribeToTopic('news');
      await handler.unsubscribeFromTopic('news');

      verify(() => messaging.subscribeToTopic('news')).called(1);
      verify(() => messaging.unsubscribeFromTopic('news')).called(1);
    });

    test('getInitialAction returns null gracefully when none / on error',
        () async {
      when(() => awesome.getInitialNotificationAction())
          .thenAnswer((_) async => null);
      final handler = DefaultNotificationHandler.createForTest(
        awesomeNotifications: awesome,
        config: const NotificationConfig(channelKey: 'c', channelName: 'C'),
      );

      expect(await handler.getInitialAction(), isNull);

      when(() => awesome.getInitialNotificationAction())
          .thenThrow(Exception('boom'));
      expect(await handler.getInitialAction(), isNull);
    });
  });
}
