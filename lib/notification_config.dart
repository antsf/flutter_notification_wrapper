import 'dart:ui';

class NotificationConfig {
  final String channelKey;
  final String channelName;
  final String? channelDescription;
  final Color? defaultColor;
  final String? androidNotificationIcon;

  NotificationConfig({
    required this.channelKey,
    required this.channelName,
    this.channelDescription,
    this.defaultColor,
    this.androidNotificationIcon,
  });
}
