# Flutter Notification Wrapper

A powerful wrapper over Firebase Messaging and AwesomeNotifications.

## Features
- Unified interface for Android/iOS
- Supports foreground/background/terminated state
- Customizable handlers
- Simulate notifications via devtool
- Action buttons, badge count, scheduling, grouping

## Usage

### Install
Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_notification_wrapper:
    path: ../flutter_notification_wrapper
```

### Initialize
```dart
final handler = DefaultNotificationHandler();
await handler.initialize();
```

### Simulate Notifications (for dev)
```dart
handler.enableDevTool();
handler.simulateNotification(title: "Hi", body: "Test message");
```

For full example see `/example`.
