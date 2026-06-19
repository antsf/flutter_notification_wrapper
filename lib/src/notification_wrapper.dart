// ignore_for_file: lines_longer_than_80_chars

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'default_notification_handler.dart';
import 'notification_config.dart';
import 'utils/logger.dart';

/// Abstract contract for a unified Firebase Cloud Messaging +
/// AwesomeNotifications handler.
///
/// The concrete [DefaultNotificationHandler] implements every method below.
/// Consumers normally use that implementation via
/// [DefaultNotificationHandler.initializeSharedInstance]; this abstraction
/// exists so the behavior can be swapped or faked in tests.
///
/// All message/notification lifecycle callbacks can be overridden through the
/// constructor. Anything not overridden falls back to a logging-only default.
abstract class NotificationWrapper {
  /// Creates a wrapper, optionally overriding lifecycle callbacks.
  NotificationWrapper({
    void Function(RemoteMessage)? onMessageOverride,
    void Function(RemoteMessage)? onMessageOpenedAppOverride,
    Future<void> Function(RemoteMessage)? onBackgroundMessageOverride,
    Future<void> Function(ReceivedNotification)? onNotificationCreatedOverride,
    Future<void> Function(ReceivedNotification)?
        onNotificationDisplayedOverride,
    Future<void> Function(ReceivedAction)? onNotificationDismissedOverride,
    Future<void> Function(ReceivedAction)? handleActionReceivedOverride,
    this.onError,
    this.onPermissionEvent,
  })  : onMessage = onMessageOverride ?? _defaultOnMessage,
        onMessageOpenedApp =
            onMessageOpenedAppOverride ?? _defaultOnMessageOpenedApp,
        onBackgroundMessage =
            onBackgroundMessageOverride ?? _defaultOnBackgroundMessage,
        onNotificationCreated =
            onNotificationCreatedOverride ?? _defaultOnNotificationCreated,
        onNotificationDisplayed =
            onNotificationDisplayedOverride ?? _defaultOnNotificationDisplayed,
        onNotificationDismissed =
            onNotificationDismissedOverride ?? _defaultOnNotificationDismissed,
        handleActionReceived =
            handleActionReceivedOverride ?? _defaultHandleActionReceived;

  // FCM & AwesomeNotification lifecycle callbacks.
  final void Function(RemoteMessage) onMessage;
  final void Function(RemoteMessage) onMessageOpenedApp;
  final Future<void> Function(RemoteMessage) onBackgroundMessage;
  final Future<void> Function(ReceivedNotification) onNotificationCreated;
  final Future<void> Function(ReceivedNotification) onNotificationDisplayed;
  final Future<void> Function(ReceivedAction) onNotificationDismissed;
  final Future<void> Function(ReceivedAction) handleActionReceived;

  /// Called when an internal operation throws. Receives the raw `error` and its
  /// `stackTrace`. The error is *not* downcast, so any error type is delivered
  /// safely (never rethrown from inside the package's catch blocks).
  final void Function(Object error, StackTrace stackTrace)? onError;

  /// Optional analytics seam. Invoked for notable events (e.g. permission
  /// requests) so the host app can log them through its own analytics pipeline,
  /// after obtaining user consent. The package itself logs nothing externally.
  final void Function(String name, Map<String, Object?> parameters)?
      onPermissionEvent;

  /// Initializes channels, listeners and (optionally) Firebase.
  ///
  /// Set [requestPermissionsOnInit] to `true` to request OS notification
  /// permission during initialization. It defaults to `false` so apps can show
  /// a contextual prompt later via `requestPermissions` (the recommended UX).
  Future<void> initialize({
    NotificationConfig? config,
    FirebaseOptions? firebaseOptions,
    bool requestPermissionsOnInit = false,
  });

  // ================== FCM TOKEN METHODS ===================
  Future<String?> getFcmToken();

  /// Registers [onTokenRefresh] to be called whenever the FCM token changes.
  ///
  /// Idempotent: calling this repeatedly replaces the previous callback rather
  /// than stacking subscriptions.
  Future<void> refreshToken(void Function(String) onTokenRefresh);

  // ================== NOTIFICATION PERMISSIONS ===================
  Future<AuthorizationStatus> requestPermissions();
  Future<bool> isNotificationAllowed();

  // ================== NOTIFICATION DISPLAY ===================
  // Display methods return the generated notification id so callers can later
  // cancel or update the notification they created.
  Future<int> showNotification(RemoteMessage message);
  Future<int> showRegularNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
    String? channelKey,
  });
  Future<int> showActionNotification({
    required String title,
    required String body,
    List<NotificationActionButton> buttons,
    Map<String, String>? payload,
    String? channelKey,
  });
  Future<int> showReplyNotification({
    required String title,
    required String body,
    String? replyLabel,
    NotificationActionButton? replyButton,
    Map<String, String>? payload,
    String? channelKey,
  });
  Future<List<int>> showGroupedNotification(
    String groupKey,
    List<NotificationContent> messages,
  );
  Future<int> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    Map<String, String>? payload,
    String? channelKey,
  });
  Future<void> cancelNotification(int id);
  Future<void> cancelAllNotifications();

  // ================== BADGE COUNT ===================
  Future<void> updateBadgeCount(int count);
  Future<void> clearBadgeCount();

  // ================== SETTINGS & DEBUG ===================
  Future<void> openNotificationSettings();
  Future<int> simulateNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? channelKey,
  });

  /// Cancels listeners and releases resources. Call when the handler is no
  /// longer needed (e.g. on logout or app teardown).
  void dispose();

  // ================== STATIC DEFAULT HANDLERS ===================

  static void _defaultOnMessage(RemoteMessage message) =>
      const Logger('NotificationWrapper')
          .d('[Default] Foreground message received: ${message.messageId}');

  static void _defaultOnMessageOpenedApp(RemoteMessage message) =>
      const Logger('NotificationWrapper')
          .d('[Default] Message opened from background: ${message.messageId}');

  static Future<void> _defaultOnBackgroundMessage(RemoteMessage message) async {
    const Logger('NotificationWrapper')
        .d('[Default] Background message received: ${message.messageId}');
    await DefaultNotificationHandler.I.showNotification(message);
  }

  static Future<void> _defaultOnNotificationCreated(
    ReceivedNotification notification,
  ) async =>
      const Logger('NotificationWrapper')
          .d('[Default] Notification created: ${notification.id}');

  static Future<void> _defaultOnNotificationDisplayed(
    ReceivedNotification notification,
  ) async =>
      const Logger('NotificationWrapper')
          .d('[Default] Notification displayed: ${notification.id}');

  static Future<void> _defaultOnNotificationDismissed(
    ReceivedAction action,
  ) async =>
      const Logger('NotificationWrapper').d(
        '[Default] Notification dismissed: ${action.id}, payload: ${action.payload}',
      );

  static Future<void> _defaultHandleActionReceived(
    ReceivedAction action,
  ) async =>
      const Logger('NotificationWrapper').d(
        '[Default] Action received: ${action.id}, payload: ${action.payload}',
      );
}
