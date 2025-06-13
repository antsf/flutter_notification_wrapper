/// A comprehensive Flutter package that provides a unified interface for
/// Firebase Cloud Messaging and AwesomeNotifications.
///
/// This library offers:
/// - Unified notification handling across platforms
/// - Background message processing
/// - Action buttons and interactive notifications
/// - Notification scheduling and grouping
/// - Badge count management
/// - Customizable notification channels
///
/// Example usage:
/// ```dart
/// final handler = await DefaultNotificationHandler.initializeSharedInstance(
///   config: NotificationConfig(
///     channelKey: 'app_notifications',
///     channelName: 'App Notifications',
///     channelDescription: 'General app notifications',
///   ),
/// );
///
/// // Show a notification
/// await handler.showRegularNotification(
///   title: 'Hello',
///   body: 'This is a test notification',
/// );
/// ```
library flutter_notification_wrapper;

export '../src/background_message_handler.dart';
export '../src/default_notification_handler.dart';
export '../src/notification_config.dart';
export '../src/notification_wrapper.dart';
export '../src/utils/debounce.dart';
export '../src/utils/logger.dart';
export '../src/utils/notification_analytics.dart';
export '../src/utils/notification_center.dart';
export '../src/utils/rx.dart';
export '../src/utils/type.dart';
