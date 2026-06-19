# Flutter Notification Wrapper

[![pub package](https://img.shields.io/pub/v/flutter_notification_wrapper.svg)](https://pub.dev/packages/flutter_notification_wrapper)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive Flutter package that provides a unified interface for Firebase Cloud Messaging and AwesomeNotifications with advanced features like background handling, action buttons, scheduling, and more.

## 🚀 Features

- **Unified Interface**: Single API for both Firebase Cloud Messaging and AwesomeNotifications
- **Cross-Platform**: Full support for Android and iOS
- **Background Processing**: Handle notifications in foreground, background, and terminated states
- **Interactive Notifications**: Support for action buttons, reply notifications, and custom interactions
- **Advanced Scheduling**: Schedule notifications for future delivery
- **Notification Grouping**: Group related notifications together
- **Badge Management**: Update and clear app badge counts
- **Customizable Channels**: Multiple notification channels with different priorities and behaviors
- **Debug Tools**: Built-in simulation and debugging capabilities
- **Type Safety**: Full Dart type safety with comprehensive error handling
- **Reactive State**: Built-in reactive programming utilities
- **Comprehensive Logging**: Configurable logging system for debugging

## 📦 Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_notification_wrapper: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## 🛠 Setup

### Android Setup

1. Add the following to your `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34

    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

2. **Android 13+ (API 33+) Permission Requirement:**

   Add the `POST_NOTIFICATIONS` permission to your `android/app/src/main/AndroidManifest.xml`:

   ```xml
   <manifest xmlns:android="http://schemas.android.com/apk/res/android">
       <!-- Required for Android 13+ (API 33+) to show notifications -->
       <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

       <application ...>
           <!-- Your application content -->
       </application>
   </manifest>
   ```

   > **Important:** Without this permission declared in the manifest, notifications will not appear on Android 13+ devices even if you request permission at runtime.

3. Add notification icons to `android/app/src/main/res/drawable/`:
   - `notification_icon.png` (for regular notifications)
   - `ic_stat_notification.png` (for status bar)

4. Add Firebase configuration file `google-services.json` to `android/app/`.

### iOS Setup

1. Add Firebase configuration file `GoogleService-Info.plist` to `ios/Runner/`.

2. Configure notification capabilities in `ios/Runner/Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

## 🚀 Quick Start

### Basic Initialization

```dart
import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure notification settings
  final config = NotificationConfig(
    channelKey: 'app_notifications',
    channelName: 'App Notifications',
    channelDescription: 'General notifications from the app',
    defaultColor: Colors.blue,
    androidNotificationIcon: 'resource://drawable/notification_icon',
  );
  
  // Initialize the notification handler.
  // Permissions are opt-in: pass requestPermissionsOnInit: true to prompt now,
  // or call handler.requestPermissions() later at a contextual moment.
  await DefaultNotificationHandler.initializeSharedInstance(
    config: config,
    requestPermissionsOnInit: false,
    // firebaseOptions: DefaultFirebaseOptions.currentPlatform, // If using Firebase
  );
  
  runApp(MyApp());
}
```

> **Display methods return the notification id.** `showRegularNotification`,
> `showActionNotification`, `showReplyNotification` and `scheduleNotification`
> return `Future<int>` (and `showGroupedNotification` returns `Future<List<int>>`)
> so you can later `cancelNotification(id)` the notification you created.

### Showing Notifications

```dart
final handler = DefaultNotificationHandler.I;

// Simple notification
await handler.showRegularNotification(
  title: 'Hello!',
  body: 'This is a test notification',
);

// Notification with action buttons
await handler.showActionNotification(
  title: 'New Message',
  body: 'You have received a new message',
  buttons: [
    NotificationActionButton(
      key: 'REPLY',
      label: 'Reply',
      actionType: ActionType.Default,
    ),
    NotificationActionButton(
      key: 'MARK_READ',
      label: 'Mark as Read',
      actionType: ActionType.SilentAction,
    ),
  ],
);

// Reply notification
await handler.showReplyNotification(
  title: 'Chat Message',
  body: 'John: How are you doing?',
  replyLabel: 'Reply',
);
```

### Scheduling Notifications

```dart
// Schedule a notification for later (named parameters)
await handler.scheduleNotification(
  id: 1,
  title: 'Reminder',
  body: 'Don\'t forget your appointment!',
  scheduledDate: DateTime.now().add(Duration(hours: 2)),
);

// Cancel a scheduled notification
await handler.cancelNotification(1);

// Cancel all notifications
await handler.cancelAllNotifications();
```

### Handling Notification Actions

```dart
// Initialize with custom action handler
await DefaultNotificationHandler.initializeSharedInstance(
  config: config,
  handleActionReceivedOverride: (ReceivedAction action) async {
    switch (action.buttonKeyPressed) {
      case 'REPLY':
        // Handle reply action
        print('Reply: ${action.buttonKeyInput}');
        break;
      case 'MARK_READ':
        // Handle mark as read action
        print('Marked as read');
        break;
    }
  },
);
```

## 🏗️ Architecture: FCM vs AwesomeNotifications

This package combines Firebase Cloud Messaging (FCM) and AwesomeNotifications with clear role separation:

| Feature | Firebase Cloud Messaging | AwesomeNotifications |
|---------|-------------------------|---------------------|
| **Primary Role** | Receive messages from cloud | Display local notifications |
| **Message Reception** | ✅ `onMessage`, `onBackgroundMessage` | ❌ |
| **Notification Display** | Auto-displays (with limitations) | ✅ Full control |
| **Action Buttons** | ❌ | ✅ |
| **Scheduling** | ❌ | ✅ |
| **Reply Input** | ❌ | ✅ |
| **Badge Management** | ❌ | ✅ |

### Avoiding Duplicate Notifications

On Android < 13, FCM automatically displays notifications when the message contains a `notification` field. This can cause duplicates since this package also uses AwesomeNotifications to display.

**Recommended: Use data-only messages from your server:**

```json
// ❌ Avoid: Message with notification field (may cause duplicates on Android < 13)
{
  "to": "device_token",
  "notification": {
    "title": "Hello",
    "body": "World"
  },
  "data": {
    "key": "value"
  }
}

// ✅ Recommended: Data-only message (consistent behavior across all versions)
{
  "to": "device_token",
  "data": {
    "title": "Hello",
    "body": "World",
    "key": "value"
  }
}
```

With data-only messages, this package handles all notification display via AwesomeNotifications, providing consistent behavior across all Android versions including Android 13+.

## 🎯 Advanced Usage

### Multiple Notification Channels

```dart
// High priority notifications
final urgentConfig = NotificationConfig.highPriority(
  channelKey: 'urgent_notifications',
  channelName: 'Urgent Notifications',
  channelDescription: 'Important alerts that require immediate attention',
);

// Low priority notifications
final backgroundConfig = NotificationConfig.lowPriority(
  channelKey: 'background_updates',
  channelName: 'Background Updates',
  channelDescription: 'Non-intrusive background updates',
);

// Silent notifications
final silentConfig = NotificationConfig.silent(
  channelKey: 'silent_sync',
  channelName: 'Silent Sync',
  channelDescription: 'Silent background synchronization',
);
```

### Grouped Notifications

```dart
final messages = [
  NotificationContent(
    id: 1,
    title: 'John Doe',
    body: 'Hey, how are you?',
    groupKey: 'chat_messages',
  ),
  NotificationContent(
    id: 2,
    title: 'Jane Smith',
    body: 'Meeting at 3 PM today',
    groupKey: 'chat_messages',
  ),
];

await handler.showGroupedNotification('chat_messages', messages);
```

### Badge Management

```dart
// Update badge count
await handler.updateBadgeCount(5);

// Clear badge
await handler.clearBadgeCount();
```

### Permission Handling

```dart
// Request notification permissions
final status = await handler.requestPermissions();

if (status == AuthorizationStatus.authorized) {
  print('Notifications are authorized');
} else {
  print('Notifications not authorized: $status');
  
  // Open settings to allow user to enable notifications
  await handler.openNotificationSettings();
}
```

### Firebase Cloud Messaging Integration

```dart
// Get FCM token
final token = await handler.getFcmToken();
print('FCM Token: $token');

// Listen for token refresh
await handler.refreshToken((newToken) {
  print('Token refreshed: $newToken');
  // Send token to your server
});
```

## 🧪 Testing and Debugging

### Simulation for Development

```dart
// Simulate a notification during development (returns its id)
final id = await handler.simulateNotification(
  title: 'Test Notification',
  body: 'This is a simulated notification for testing',
  data: {'key': 'value'},
);
```

### Logging Configuration

The logging utilities live in a separate entrypoint so they don't pollute your
namespace:

```dart
import 'package:flutter_notification_wrapper/utils.dart';

// Set log level
Logger.setLogLevel(LogLevel.debug);

// Configure logging options
Logger.setIncludeTimestamp(true);
Logger.setIncludeLoggerName(true);

// Create custom loggers
final logger = Logger('MyFeature');
logger.i('This is an info message');
logger.w('This is a warning');
logger.e('This is an error');
```

## 🎨 Reactive Programming (optional utilities)

The package ships small reactive helpers used internally. They are **not**
exported from the main entrypoint (to avoid clashing with packages like GetX);
import them explicitly only if you want them:

```dart
import 'package:flutter_notification_wrapper/utils.dart';

// Simple reactive value
final counter = Rx<int>(0);
counter.listen((value) => print('Counter: $value'));
counter.value = 5; // Prints: Counter: 5

// Specialized reactive types
final isLoading = RxBool(false);
final userName = RxString('');
final notifications = RxList<String>();

// Boolean operations
isLoading.toggle();
isLoading.setTrue();
isLoading.setFalse();

// String operations
userName.append(' Doe');
userName.prepend('John ');
userName.clear();

// List operations
notifications.add('New notification');
notifications.addAll(['Notification 1', 'Notification 2']);
notifications.remove('Old notification');
notifications.clear();
```

## 🛡 Error Handling

The package provides comprehensive error handling:

```dart
try {
  await handler.showRegularNotification(
    title: 'Test',
    body: 'Test notification',
  );
} catch (error) {
  print('Failed to show notification: $error');
}

// Centralized error + analytics hooks
await DefaultNotificationHandler.initializeSharedInstance(
  config: config,
  onError: (error, stackTrace) {
    debugPrint('Notification error: $error\n$stackTrace');
  },
  // Optional analytics seam — invoked for permission events so YOU can log
  // them through your own pipeline (after obtaining consent). The package
  // logs nothing externally itself.
  onPermissionEvent: (name, parameters) {
    myAnalytics.logEvent(name, parameters);
  },
);
```

## 🔧 Configuration Options

### NotificationConfig Properties

| Property                   | Type                      | Description                       | Default     |
|----------------------------|---------------------------|-----------------------------------|-------------|
| `channelKey`               | `String`                  | Unique identifier for the channel | Required    |
| `channelName`              | `String`                  | Human-readable channel name       | Required    |
| `channelDescription`       | `String?`                 | Channel description               | `null`      |
| `defaultColor`             | `Color?`                  | Default notification color        | `null`      |
| `androidNotificationIcon`  | `String?`                 | Android notification icon path    | `null`      |
| `importance`               | `NotificationImportance`  | Notification importance level     | `High`      |
| `channelShowBadge`         | `bool`                    | Show badge count                  | `true`      |
| `playSound`                | `bool`                    | Play notification sound           | `true`      |
| `enableVibration`          | `bool`                    | Enable vibration                  | `true`      |
| `enableLights`             | `bool`                    | Enable LED lights (Android)       | `true`      |
| `groupKey`                 | `String?`                 | Group key for grouping            | `null`      |
| `groupAlertBehavior`       | `GroupAlertBehavior`      | Group alert behavior              | `Children`  |
| `defaultPrivacy`           | `NotificationPrivacy`     | Privacy level                     | `Public`    |
| `wakeUpScreen`             | `bool`                    | Wake/turn on screen on display    | `false`     |
| `category`                 | `NotificationCategory?`   | Default notification category     | `null`      |

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Clone the repository
2. Run `flutter pub get`
3. Run tests: `flutter test`
4. Run example: `cd example && flutter run`

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [AwesomeNotifications](https://pub.dev/packages/awesome_notifications) for the excellent local notification system
- [Firebase Messaging](https://pub.dev/packages/firebase_messaging) for cloud messaging capabilities
- The Flutter community for continuous support and feedback

## 📞 Support

If you have any questions or need help, please:

1. Check the [documentation](https://github.com/antsf/flutter_notification_wrapper/wiki)
2. Search [existing issues](https://github.com/antsf/flutter_notification_wrapper/issues)
3. Create a [new issue](https://github.com/antsf/flutter_notification_wrapper/issues/new)

---

Made with ❤️ by the Flutter community
