# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2024-01-XX

### Added
- **Enhanced NotificationConfig**: Added comprehensive configuration options including importance levels, vibration, LED lights, and privacy settings
- **Multiple Configuration Factories**: Added `highPriority()`, `lowPriority()`, `silent()`, and `custom()` factory constructors
- **Configuration Validation**: Added validation methods to ensure proper configuration setup
- **Advanced Logger**: Implemented configurable logging system with multiple log levels and formatting options
- **Enhanced Debouncer**: Added specialized `NotificationDebouncer` with message ID tracking and async support
- **Reactive Programming Utilities**: Added comprehensive `Rx` classes including `RxBool`, `RxInt`, `RxString`, and `RxList`
- **Comprehensive Documentation**: Added detailed README with examples and API documentation
- **Type Safety**: Added `@immutable` annotations and improved type safety throughout
- **Error Handling**: Enhanced error handling with proper exception management
- **Testing Suite**: Added comprehensive unit tests for all utility classes

### Enhanced
- **NotificationConfig**: Now supports all AwesomeNotifications channel properties
- **Logger**: Added timestamp, logger name configuration, and error/stack trace support
- **Debouncer**: Added cancellation, disposal, and async operation support
- **Rx Classes**: Added stream support, listener management, and specialized type methods

### Fixed
- **Background Message Handling**: Improved background message processing with proper config fallbacks
- **Memory Leaks**: Added proper disposal methods to prevent memory leaks
- **Concurrent Modifications**: Fixed potential concurrent modification issues in reactive classes

### Changed
- **Package Structure**: Reorganized exports to include all utility classes
- **Version Bump**: Updated to version 0.3.0 with improved dependency versions
- **Documentation**: Complete rewrite of README with comprehensive examples and setup instructions

## [0.2.0] - 2024-01-XX

### Added
- Initial implementation of NotificationWrapper abstract class
- DefaultNotificationHandler with singleton pattern
- Basic notification configuration system
- Firebase Cloud Messaging integration
- AwesomeNotifications integration
- Background message handling
- Basic utility classes (Logger, Debouncer, Rx)

### Features
- Foreground, background, and terminated state notification handling
- Action buttons and interactive notifications
- Notification scheduling and cancellation
- Badge count management
- Grouped notifications
- Permission handling
- Debug and simulation tools

## [0.1.0] - 2024-01-XX

### Added
- Initial project setup
- Basic package structure
- Core dependencies configuration
- Example application setup

---

## Migration Guide

### From 0.2.0 to 0.3.0

#### NotificationConfig Changes

**Before (0.2.0):**
```dart
final config = NotificationConfig(
  channelKey: 'basic_channel',
  channelName: 'Basic notifications',
  channelDescription: 'Default notification channel',
  defaultColor: Colors.blue,
  androidNotificationIcon: 'notification_icon',
);
```

**After (0.3.0):**
```dart
// Using the enhanced constructor
final config = NotificationConfig(
  channelKey: 'basic_channel',
  channelName: 'Basic notifications',
  channelDescription: 'Default notification channel',
  defaultColor: Colors.blue,
  androidNotificationIcon: 'resource://drawable/notification_icon', // Note the prefix
  importance: NotificationImportance.High,
  channelShowBadge: true,
  playSound: true,
  enableVibration: true,
);

// Or using factory constructors
final urgentConfig = NotificationConfig.highPriority(
  channelKey: 'urgent',
  channelName: 'Urgent Notifications',
);

final silentConfig = NotificationConfig.silent(
  channelKey: 'background',
  channelName: 'Background Updates',
);
```

#### Logger Changes

**Before (0.2.0):**
```dart
final logger = Logger('MyClass');
logger.d('Debug message');
logger.i('Info message');
```

**After (0.3.0):**
```dart
// Same basic usage, but with enhanced features
final logger = Logger('MyClass');
logger.d('Debug message', error, stackTrace); // Now supports error and stack trace
logger.i('Info message');

// New configuration options
Logger.setLogLevel(LogLevel.debug);
Logger.setIncludeTimestamp(true);

// New factory constructors
final classLogger = Logger.forClass(MyClass);
final featureLogger = Logger.forFeature('Notifications');
```

#### Debouncer Changes

**Before (0.2.0):**
```dart
final debouncer = Debouncer(delay: Duration(milliseconds: 500));
debouncer.run(() {
  // Action
});
```

**After (0.3.0):**
```dart
// Same basic usage, but with enhanced features
final debouncer = Debouncer(delay: Duration(milliseconds: 500));
debouncer.run(() {
  // Action
});

// New features
debouncer.runAsync(() async {
  // Async action
});

debouncer.cancel(); // Cancel pending action
debouncer.dispose(); // Clean up resources

// New specialized debouncer
final notificationDebouncer = NotificationDebouncer(delay: Duration(milliseconds: 500));
notificationDebouncer.runForMessage(messageId, () {
  // Only runs if message ID is different
});
```

#### Rx Changes

**Before (0.2.0):**
```dart
final rx = Rx<int>(0);
rx.listen((value) => print(value));
rx.value = 5;
```

**After (0.3.0):**
```dart
// Enhanced with more features
final rx = Rx<int>(0);
final removeListener = rx.listen((value) => print(value)); // Returns removal function
rx.value = 5;

// New methods
rx.update((current) => current + 1);
rx.stream.listen((value) => print('Stream: $value'));
removeListener(); // Remove specific listener
rx.dispose(); // Clean up resources

// New specialized types
final boolRx = RxBool(false);
boolRx.toggle();
boolRx.setTrue();

final intRx = RxInt(0);
intRx.increment();
intRx.add(5);

final stringRx = RxString('Hello');
stringRx.append(' World');

final listRx = RxList<String>();
listRx.add('Item');
listRx.addAll(['Item1', 'Item2']);
```

### Breaking Changes

1. **Android Notification Icon Path**: Now requires `resource://drawable/` prefix
2. **Logger Constructor**: Error and stack trace parameters are now optional positional parameters
3. **Debouncer Timer Access**: Timer is now private, use `isActive` property instead
4. **Rx Listener Return**: `listen()` method now returns a removal function

### Deprecations

None in this release.

---

## Support

For questions about migration or new features, please:

1. Check the updated [README](README.md)
2. Review the [example](example/) application
3. Create an [issue](https://github.com/antsf/flutter_notification_wrapper/issues) if you need help