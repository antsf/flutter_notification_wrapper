/// A Flutter package providing a unified interface over Firebase Cloud
/// Messaging and AwesomeNotifications: background handling, action buttons,
/// scheduling, grouping, badges and channel configuration.
///
/// Example:
/// ```dart
/// final handler = await DefaultNotificationHandler.initializeSharedInstance(
///   config: NotificationConfig(
///     channelKey: 'app_notifications',
///     channelName: 'App Notifications',
///     channelDescription: 'General app notifications',
///   ),
/// );
///
/// await handler.showRegularNotification(
///   title: 'Hello',
///   body: 'This is a test notification',
/// );
/// ```
///
/// The optional utilities (`Logger`, `Rx`, `Debouncer`) are intentionally NOT
/// exported here to avoid polluting the consumer namespace. Import them
/// explicitly if you want them:
/// ```dart
/// import 'package:flutter_notification_wrapper/utils.dart';
/// ```
library;

// Public types required by this package's API surface.
export 'package:awesome_notifications/awesome_notifications.dart'
    show
        ActionType,
        GroupAlertBehavior,
        NotificationActionButton,
        NotificationCalendar,
        NotificationCategory,
        NotificationContent,
        NotificationImportance,
        NotificationLayout,
        NotificationPrivacy,
        ReceivedAction,
        ReceivedNotification;
export 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
export 'package:firebase_messaging/firebase_messaging.dart'
    show AuthorizationStatus, RemoteMessage;

// This package's own public API.
export 'src/background_message_handler.dart';
export 'src/default_notification_handler.dart';
export 'src/notification_config.dart';
export 'src/notification_wrapper.dart';
