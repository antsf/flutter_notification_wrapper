import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'default_notification_handler.dart';
import 'notification_config.dart';
import 'utils/logger.dart';

abstract class NotificationWrapper {
  NotificationWrapper()
      : onMessage = _defaultOnMessage,
        onMessageOpenedApp = _defaultOnMessageOpenedApp,
        onBackgroundMessage = _defaultOnBackgroundMessage,
        onNotificationCreated = _defaultOnNotificationCreated,
        onNotificationDisplayed = _defaultOnNotificationDisplayed,
        onNotificationDismissed = _defaultOnNotificationDismissed,
        handleActionReceived = _defaultHandleActionReceived;

  Future<void> initialize({
    NotificationConfig? config,
    FirebaseOptions? firebaseOptions,
  });
  // ================== FCM TOKEN METHODS ===================

  /// Get the current FCM token
  Future<String?> getFcmToken();

  /// Listen to FCM token refresh events
  Future<void> refreshToken(void Function(String) onTokenRefresh);

  // ================== NOTIFICATION PERMISSIONS ===================

  /// Get AuthorizationStatus
  Future<AuthorizationStatus> requestPermissions();

  // ================== NOTIFICATION LISTENERS ===================

  /// Called when a message is received while app is in foreground (Firebase Messaging)
  void Function(RemoteMessage) onMessage;

  /// Called when a message is received while app is in background or terminated (Firebase Messaging)
  void Function(RemoteMessage) onMessageOpenedApp;

  /// Background message handler (Firebase Messaging)
  Future<void> Function(RemoteMessage) onBackgroundMessage;

  /// Called when a message is received while app is in foreground (Awesome Notifications)
  Future<void> Function(ReceivedNotification) onNotificationCreated;

  /// Called when notification is displayed (Awesome Notifications)
  Future<void> Function(ReceivedNotification) onNotificationDisplayed;

  /// Called when notification is dismissed (Awesome Notifications)
  Future<void> Function(ReceivedAction) onNotificationDismissed;

  // void onMessage(RemoteMessage message);
  // void onMessageOpenedApp(RemoteMessage message);
  // void onBackgroundMessage(RemoteMessage message);
  // void onMessageInForeground(RemoteMessage message);
  // void onDiagnostics(Request request);
  void Function(Exception exception)? onFailedToResolveHostname;
  void Function({required String token, required String raw})? onIosTokens;
  void Function(ReceivedAction action)? onAndroidPermission;
  // void onSilentDataMessage(Map<String, dynamic> data);
  // Future<void> onNotificationCreated(ReceivedNotification receivedNotification);
  // Future<void> onNotificationDisplayed(
  //     ReceivedNotification receivedNotification);
  // Future<void> onNotificationDismissed(ReceivedAction receivedAction);

  // ================== NOTIFICATION ACTIONS ===================

  /// Called when an action button is pressed (e.g., Reply, Accept)
  Future<void> Function(ReceivedAction) handleActionReceived;

  /// Handle tap on notification (Firebase Message)
  void handleNotificationClick(RemoteMessage message);

  // ================== NOTIFICATION DISPLAY ===================

  /// Show a regular notification (Firebase Message)
  Future<void> showNotification(RemoteMessage message);

  /// Show a basic notification without actions (Awesome Notifications)
  Future<void> showRegularNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
    String? channelKey,
  });

  /// Show a notification with buttons like "Accept"/"Decline" (Awesome Notifications)
  Future<void> showActionNotification({
    required String title,
    required String body,
    List<NotificationActionButton> buttons,
    Map<String, String>? payload,
    String? channelKey,
  });

  /// Show a notification with reply input field (Awesome Notifications)
  Future<void> showReplyNotification({
    required String title,
    required String body,
    String? replyLabel,
    String? inputPlaceholder,
    NotificationActionButton? replyButton,
    Map<String, String>? payload,
    String? channelKey,
  });

  /// Show grouped notifications (for chats or similar) (Awesome Notifications)
  Future<void> showGroupedNotification(
      String groupKey, List<NotificationContent> messages);

  /// Schedule a future notification (Awesome Notifications)
  Future<void> scheduleNotification(
      int id, String title, String body, DateTime scheduledDate,
      {Map<String, String>? payload, String? channelKey});

  /// Cancel a specific notification by ID (Awesome Notifications)
  Future<void> cancelNotification(int id);

  /// Cancel all notifications (Awesome Notifications)
  Future<void> cancelAllNotifications();

  // ================== BADGE COUNT ===================

  /// Update badge count on app icon (Awesome Notifications)
  Future<void> updateBadgeCount(int count);

  /// Clear badge count (Awesome Notifications)
  Future<void> clearBadgeCount();

  // ================== SETTINGS & DEBUG ===================

  /// Open system notification settings (Awesome Notifications)
  Future<void> openAppSettings();

  /// Open app-specific notification settings (Awesome Notifications)
  Future<void> openNotificationSettings();

  /// Simulate notification manually (useful during development) (Awesome Notifications)
  void simulateNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? channelKey,
  });

  /// Lifecycle cleanup
  void dispose();

  // DevTool (Awesome Notifications)
  void enableDevTool();
  void disableDevTool();

  // Default handlers for the abstract class
  static void _defaultOnMessage(RemoteMessage message) =>
      Logger('NotificationWrapper')
          .d('Foreground message received: ${message.data}');
  static void _defaultOnMessageOpenedApp(RemoteMessage message) =>
      Logger('NotificationWrapper')
          .d('Message opened from background: ${message.data}');
  static Future<void> _defaultOnBackgroundMessage(RemoteMessage message) async {
    Logger('NotificationWrapper')
        .d('Background message received (default handler): ${message.data}');
    await DefaultNotificationHandler()
        .showNotification(message); //show notification
  }

  static Future<void> _defaultOnNotificationCreated(
          ReceivedNotification notification) async =>
      Logger('NotificationWrapper')
          .d('Notification created (default handler): ${notification.id}');
  static Future<void> _defaultOnNotificationDisplayed(
          ReceivedNotification notification) async =>
      Logger('NotificationWrapper')
          .d('Notification displayed (default handler): ${notification.id}');
  static Future<void> _defaultOnNotificationDismissed(
          ReceivedAction action) async =>
      Logger('NotificationWrapper').d(
          'Notification dismissed (default handler): ${action.id}, payload: ${action.payload}');
  static Future<
      void> _defaultHandleActionReceived(ReceivedAction action) async => Logger(
          'NotificationWrapper')
      .d('Action received (default handler): ${action.id}, payload: ${action.payload}');
}
