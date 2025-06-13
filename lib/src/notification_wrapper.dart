// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// It's good practice to avoid direct dependencies from abstract layers to concrete implementations
// if DefaultNotificationHandler is the *only* implementation, this is okay,
// but for true abstraction, DefaultNotificationHandler().showNotification would be an issue here.
// For now, we'll keep it as it demonstrates the original intent for the default.
// A more advanced solution might involve a separate static helper or a factory.
import 'default_notification_handler.dart';
import 'notification_config.dart';
import 'utils/logger.dart'; // Assuming you have a Logger utility

abstract class NotificationWrapper {
  NotificationWrapper({
    // Allow providing overrides in the constructor
    void Function(RemoteMessage)? onMessageOverride,
    void Function(RemoteMessage)? onMessageOpenedAppOverride,
    Future<void> Function(RemoteMessage)? onBackgroundMessageOverride,
    Future<void> Function(ReceivedNotification)? onNotificationCreatedOverride,
    Future<void> Function(ReceivedNotification)?
        onNotificationDisplayedOverride,
    Future<void> Function(ReceivedAction)? onNotificationDismissedOverride,
    Future<void> Function(ReceivedAction)? handleActionReceivedOverride,
    this.onFailedToResolveHostname,
    this.onIosTokens,
    this.onAndroidPermission,
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
  // FCM & Awesome Notification Listeners
  final void Function(RemoteMessage) onMessage;
  final void Function(RemoteMessage) onMessageOpenedApp;
  final Future<void> Function(RemoteMessage) onBackgroundMessage;
  final Future<void> Function(ReceivedNotification) onNotificationCreated;
  final Future<void> Function(ReceivedNotification) onNotificationDisplayed;
  final Future<void> Function(ReceivedAction) onNotificationDismissed;
  final Future<void> Function(ReceivedAction) handleActionReceived;

  // Optional handlers that might be specific to the implementation
  final void Function(Exception exception)? onFailedToResolveHostname;
  final void Function({required String token, required String raw})?
      onIosTokens;
  final void Function(ReceivedAction action)? onAndroidPermission;

  Future<void> initialize({
    NotificationConfig? config,
    FirebaseOptions? firebaseOptions,
  });

  // ================== FCM TOKEN METHODS ===================
  Future<String?> getFcmToken();
  Future<void> refreshToken(void Function(String) onTokenRefresh);

  // ================== NOTIFICATION PERMISSIONS ===================
  Future<AuthorizationStatus> requestPermissions();
  Future<bool> isNotificationAllowed();

  // ================== NOTIFICATION ACTIONS ===================
  void handleNotificationClick(RemoteMessage message);

  // ================== NOTIFICATION DISPLAY ===================
  Future<void> showNotification(RemoteMessage message);
  Future<void> showRegularNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
    String? channelKey,
  });
  Future<void> showActionNotification({
    required String title,
    required String body,
    List<NotificationActionButton> buttons,
    Map<String, String>? payload,
    String? channelKey,
  });
  Future<void> showReplyNotification({
    required String title,
    required String body,
    String? replyLabel,
    String? inputPlaceholder,
    NotificationActionButton? replyButton,
    Map<String, String>? payload,
    String? channelKey,
  });
  Future<void> showGroupedNotification(
    String groupKey,
    List<NotificationContent> messages,
  );
  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate, {
    Map<String, String>? payload,
    String? channelKey,
  });
  Future<void> cancelNotification(int id);
  Future<void> cancelAllNotifications();

  // ================== BADGE COUNT ===================
  Future<void> updateBadgeCount(int count);
  Future<void> clearBadgeCount();

  // ================== SETTINGS & DEBUG ===================
  Future<void> openAppSettings();
  Future<void> openNotificationSettings();
  void simulateNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? channelKey,
  });
  void dispose();

  // DevTool (Awesome Notifications) - Keep abstract if implementations might vary
  void enableDevTool();
  void disableDevTool();

  // ================== STATIC DEFAULT HANDLERS ===================
  // These are the fallback implementations if no override is provided.

  static void _defaultOnMessage(RemoteMessage message) =>
      const Logger('NotificationWrapper')
          .d('[Default] Foreground message received: ${message.messageId}');

  static void _defaultOnMessageOpenedApp(RemoteMessage message) =>
      const Logger('NotificationWrapper')
          .d('[Default] Message opened from background: ${message.messageId}');

  static Future<void> _defaultOnBackgroundMessage(RemoteMessage message) async {
    const Logger('NotificationWrapper')
        .d('[Default] Background message received: ${message.messageId}');
    // This default implies that DefaultNotificationHandler is always available or can be instantiated.
    // This is a simplification; a more decoupled system might use a different approach.
    // For this to work, DefaultNotificationHandler needs a parameterless constructor
    // or a static way to show notifications if not fully initialized.
    // Given the singleton pattern in the refactored DefaultNotificationHandler,
    // this specific default might need adjustment if DefaultNotificationHandler()
    // is not suitable for a one-off call.
    // A safer default might be to just log, or if DefaultNotificationHandler.I is guaranteed
    // to be initialized by the time a background message comes, it could use that.
    // However, for a truly isolated background task, direct instantiation is common.
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
      const Logger(
        'NotificationWrapper',
      ).d('[Default] Action received: ${action.id}, payload: ${action.payload}');
}
