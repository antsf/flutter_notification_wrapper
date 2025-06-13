// ignore_for_file: lines_longer_than_80_chars

import 'dart:ui';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:meta/meta.dart';

/// Configuration class for notification channels and appearance.
///
/// This class defines the properties for notification channels including
/// visual appearance, behavior, and platform-specific settings.
///
/// Example:
/// ```dart
/// final config = NotificationConfig(
///   channelKey: 'app_notifications',
///   channelName: 'App Notifications',
///   channelDescription: 'General notifications from the app',
///   defaultColor: Colors.blue,
///   androidNotificationIcon: 'resource://drawable/ic_notification',
/// );
/// ```
@immutable
class NotificationConfig {
  /// Creates a new [NotificationConfig] with the specified properties.
  const NotificationConfig({
    required this.channelKey,
    required this.channelName,
    this.channelDescription,
    this.defaultColor,
    this.androidNotificationIcon,
    this.importance = NotificationImportance.High,
    this.channelShowBadge = true,
    this.playSound = true,
    this.enableVibration = true,
    this.enableLights = true,
    this.groupKey,
    this.groupAlertBehavior = GroupAlertBehavior.Children,
    this.defaultPrivacy = NotificationPrivacy.Public,
  });

  /// Creates a configuration for silent notifications.
  factory NotificationConfig.silent({
    required String channelKey,
    required String channelName,
    String? channelDescription,
    Color? defaultColor,
    String? androidNotificationIcon,
  }) =>
      NotificationConfig(
        channelKey: channelKey,
        channelName: channelName,
        channelDescription: channelDescription,
        defaultColor: defaultColor ?? const Color(0xff9E9E9E),
        androidNotificationIcon: androidNotificationIcon,
        importance: NotificationImportance.Min,
        channelShowBadge: false,
        playSound: false,
        enableVibration: false,
        enableLights: false,
        groupAlertBehavior: GroupAlertBehavior.Summary,
        defaultPrivacy: NotificationPrivacy.Secret,
      );

  /// Creates a default configuration suitable for most applications.
  factory NotificationConfig.defaultConfig() => const NotificationConfig(
        channelKey: 'basic_channel',
        channelName: 'Basic notifications',
        channelDescription: 'Default notification channel for app',
        defaultColor: Color(0xff00AADE),
        androidNotificationIcon: 'resource://drawable/notification_icon',
        // importance: NotificationImportance.High,
        // channelShowBadge: true,
        // playSound: true,
        // enableVibration: true,
        // enableLights: true,
        // groupAlertBehavior: GroupAlertBehavior.Children,
        // defaultPrivacy: NotificationPrivacy.Public,
      );

  /// Creates a configuration for high-priority notifications.
  factory NotificationConfig.highPriority({
    required String channelKey,
    required String channelName,
    String? channelDescription,
    Color? defaultColor,
    String? androidNotificationIcon,
  }) =>
      NotificationConfig(
        channelKey: channelKey,
        channelName: channelName,
        channelDescription: channelDescription,
        defaultColor: defaultColor ?? const Color(0xffFF5722),
        androidNotificationIcon: androidNotificationIcon,
        importance: NotificationImportance.Max,
        // channelShowBadge: true,
        // playSound: true,
        // enableVibration: true,
        // enableLights: true,
        // defaultPrivacy: NotificationPrivacy.Public,
        groupAlertBehavior: GroupAlertBehavior.All,
      );

  /// Creates a configuration for low-priority notifications.
  factory NotificationConfig.lowPriority({
    required String channelKey,
    required String channelName,
    String? channelDescription,
    Color? defaultColor,
    String? androidNotificationIcon,
  }) =>
      NotificationConfig(
        channelKey: channelKey,
        channelName: channelName,
        channelDescription: channelDescription,
        defaultColor: defaultColor ?? const Color(0xff9E9E9E),
        androidNotificationIcon: androidNotificationIcon,
        importance: NotificationImportance.Low,
        channelShowBadge: false,
        playSound: false,
        enableVibration: false,
        enableLights: false,
        groupAlertBehavior: GroupAlertBehavior.Summary,
        // defaultPrivacy: NotificationPrivacy.Public,
      );

  /// Creates a custom configuration with the specified properties.
  factory NotificationConfig.custom({
    required String channelKey,
    required String channelName,
    String? channelDescription,
    Color? defaultColor,
    String? androidNotificationIcon,
    NotificationImportance importance = NotificationImportance.High,
    bool channelShowBadge = true,
    bool playSound = true,
    bool enableVibration = true,
    bool enableLights = true,
    String? groupKey,
    GroupAlertBehavior groupAlertBehavior = GroupAlertBehavior.Children,
    NotificationPrivacy defaultPrivacy = NotificationPrivacy.Public,
  }) =>
      NotificationConfig(
        channelKey: channelKey,
        channelName: channelName,
        channelDescription: channelDescription,
        defaultColor: defaultColor,
        androidNotificationIcon: androidNotificationIcon,
        importance: importance,
        channelShowBadge: channelShowBadge,
        playSound: playSound,
        enableVibration: enableVibration,
        enableLights: enableLights,
        groupKey: groupKey,
        groupAlertBehavior: groupAlertBehavior,
        defaultPrivacy: defaultPrivacy,
      );

  /// Unique identifier for the notification channel
  final String channelKey;

  /// Human-readable name for the notification channel
  final String channelName;

  /// Description of what this channel is used for
  final String? channelDescription;

  /// Default color for notifications in this channel
  final Color? defaultColor;

  /// Path to the Android notification icon resource
  final String? androidNotificationIcon;

  /// Importance level for notifications (Android)
  final NotificationImportance importance;

  /// Whether to show badge count for this channel
  final bool channelShowBadge;

  /// Whether to play sound for notifications
  final bool playSound;

  /// Whether to enable vibration for notifications
  final bool enableVibration;

  /// Whether to enable LED lights for notifications (Android)
  final bool enableLights;

  /// Group key for notification grouping
  final String? groupKey;

  /// Group alert behavior for grouped notifications
  final GroupAlertBehavior groupAlertBehavior;

  /// Privacy level for lock screen notifications
  final NotificationPrivacy defaultPrivacy;

  /// Creates a copy of this config with the given fields replaced with new values.
  NotificationConfig copyWith({
    String? channelKey,
    String? channelName,
    String? channelDescription,
    Color? defaultColor,
    String? androidNotificationIcon,
    NotificationImportance? importance,
    bool? channelShowBadge,
    bool? playSound,
    bool? enableVibration,
    bool? enableLights,
    String? groupKey,
    GroupAlertBehavior? groupAlertBehavior,
    NotificationPrivacy? defaultPrivacy,
  }) =>
      NotificationConfig(
        channelKey: channelKey ?? this.channelKey,
        channelName: channelName ?? this.channelName,
        channelDescription: channelDescription ?? this.channelDescription,
        defaultColor: defaultColor ?? this.defaultColor,
        androidNotificationIcon:
            androidNotificationIcon ?? this.androidNotificationIcon,
        importance: importance ?? this.importance,
        channelShowBadge: channelShowBadge ?? this.channelShowBadge,
        playSound: playSound ?? this.playSound,
        enableVibration: enableVibration ?? this.enableVibration,
        enableLights: enableLights ?? this.enableLights,
        groupKey: groupKey ?? this.groupKey,
        groupAlertBehavior: groupAlertBehavior ?? this.groupAlertBehavior,
        defaultPrivacy: defaultPrivacy ?? this.defaultPrivacy,
      );

  /// Converts this config to a [NotificationChannel] for AwesomeNotifications.
  NotificationChannel toNotificationChannel() => NotificationChannel(
        channelKey: channelKey,
        channelName: channelName,
        channelDescription: channelDescription ?? 'Notification channel',
        importance: importance,
        channelShowBadge: channelShowBadge,
        playSound: playSound,
        enableVibration: enableVibration,
        enableLights: enableLights,
        defaultColor: defaultColor ?? const Color(0xff00AADE),
        defaultPrivacy: defaultPrivacy,
        groupAlertBehavior: groupAlertBehavior,
        groupKey: groupKey ?? '${channelKey}_group',
      );

  /// Validates the configuration and returns a list of validation errors.
  List<String> validate() {
    final errors = <String>[];

    if (channelKey.isEmpty) {
      errors.add('channelKey cannot be empty');
    }

    if (channelName.isEmpty) {
      errors.add('channelName cannot be empty');
    }

    if (channelKey.contains(' ')) {
      errors.add('channelKey should not contain spaces');
    }

    if (androidNotificationIcon != null &&
        !androidNotificationIcon!.startsWith('resource://drawable/')) {
      errors.add(
        'androidNotificationIcon should start with "resource://drawable/"',
      );
    }

    return errors;
  }

  /// Returns true if this configuration is valid.
  bool get isValid => validate().isEmpty;

  @override
  String toString() => 'NotificationConfig{'
      'channelKey: $channelKey, '
      'channelName: $channelName, '
      'channelDescription: $channelDescription, '
      'defaultColor: $defaultColor, '
      'androidNotificationIcon: $androidNotificationIcon, '
      'importance: $importance, '
      'channelShowBadge: $channelShowBadge, '
      'playSound: $playSound, '
      'enableVibration: $enableVibration, '
      'enableLights: $enableLights, '
      'groupKey: $groupKey, '
      'groupAlertBehavior: $groupAlertBehavior, '
      'defaultPrivacy: $defaultPrivacy'
      '}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationConfig &&
          runtimeType == other.runtimeType &&
          channelKey == other.channelKey &&
          channelName == other.channelName &&
          channelDescription == other.channelDescription &&
          defaultColor == other.defaultColor &&
          androidNotificationIcon == other.androidNotificationIcon &&
          importance == other.importance &&
          channelShowBadge == other.channelShowBadge &&
          playSound == other.playSound &&
          enableVibration == other.enableVibration &&
          enableLights == other.enableLights &&
          groupKey == other.groupKey &&
          groupAlertBehavior == other.groupAlertBehavior &&
          defaultPrivacy == other.defaultPrivacy;

  @override
  int get hashCode => Object.hash(
        channelKey,
        channelName,
        channelDescription,
        defaultColor,
        androidNotificationIcon,
        importance,
        channelShowBadge,
        playSound,
        enableVibration,
        enableLights,
        groupKey,
        groupAlertBehavior,
        defaultPrivacy,
      );
}
