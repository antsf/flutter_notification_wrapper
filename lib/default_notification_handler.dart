// lib/flutter_notification_wrapper.dart
import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import 'notification_config.dart';
import 'notification_wrapper.dart';
import 'utils/logger.dart';

// Utility class for debouncing
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }
}

// Simple wrapper for Rx<T> to avoid GetX dependency
class Rx<T> {
  T _value;
  final _listeners = <void Function(T)>[];

  Rx(this._value);

  T get value => _value;
  set value(T newValue) {
    _value = newValue;
    for (final listener in _listeners) {
      listener(_value);
    }
  }

  void listen(void Function(T) callback) {
    _listeners.add(callback);
  }
}

class DefaultNotificationHandler implements NotificationWrapper {
  final logger = Logger('NotificationWrapper');
  final Debouncer _notificationDebouncer =
      Debouncer(delay: const Duration(milliseconds: 500));
  String? _lastHandledMessageId;
  final Rx<AuthorizationStatus> permissionStatus =
      Rx<AuthorizationStatus>(AuthorizationStatus.notDetermined);
  bool _permissionRequestLock = false;
  NotificationConfig? _config;
  static ReceivePort? receivePort;

  DefaultNotificationHandler({
    this.onMessage = _defaultOnMessage,
    this.onMessageOpenedApp = _defaultOnMessageOpenedApp,
    this.onBackgroundMessage = _defaultOnBackgroundMessage,
    this.onNotificationCreated = _defaultOnNotificationCreated,
    this.onNotificationDisplayed = _defaultOnNotificationDisplayed,
    this.onNotificationDismissed = _defaultOnNotificationDismissed,
    this.handleActionReceived = _defaultHandleActionReceived,
    this.onFailedToResolveHostname,
    this.onIosTokens,
    this.onAndroidPermission,
  });

  // Default Handlers
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

  @override
  void Function(RemoteMessage) onMessage;

  @override
  void Function(RemoteMessage) onMessageOpenedApp;

  @override
  Future<void> Function(RemoteMessage) onBackgroundMessage;

  @override
  Future<void> Function(ReceivedNotification) onNotificationCreated;

  @override
  Future<void> Function(ReceivedNotification) onNotificationDisplayed;

  @override
  Future<void> Function(ReceivedAction) onNotificationDismissed;

  @override
  Future<void> Function(ReceivedAction) handleActionReceived;

  @override
  void Function(Exception exception)? onFailedToResolveHostname;
  @override
  void Function({required String token, required String raw})? onIosTokens;
  @override
  void Function(ReceivedAction action)? onAndroidPermission;

  @override
  Future<void> initialize({
    NotificationConfig? config,
    FirebaseOptions? firebaseOptions,
  }) async {
    _config = config ??
        NotificationConfig(
          channelKey: 'basic_channel',
          channelName: 'Basic notifications',
          channelDescription: 'Default notification channel',
        );

    if (firebaseOptions != null) {
      await Firebase.initializeApp(options: firebaseOptions);
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage
          .listen((message) => onMessage(message)); // Initialize onMessage here
      FirebaseMessaging.onMessageOpenedApp.listen((message) =>
          _debounceHandleNotification(message, onMessageOpenedApp));
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        //handle token refresh
      });
    }

    await _setupNotificationChannels();
    await startListeningNotificationEvents();
    await requestPermissions();
  }

  Future<void> _setupNotificationChannels() async {
    await AwesomeNotifications().initialize(
      _config?.androidNotificationIcon,
      [
        NotificationChannel(
          channelKey: _config!.channelKey,
          channelName: _config!.channelName,
          channelDescription: _config?.channelDescription ?? '',
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          defaultColor: _config?.defaultColor ?? Colors.blue,
          defaultPrivacy: NotificationPrivacy.Public,
          groupAlertBehavior: GroupAlertBehavior.Children,
          groupKey: "basic_group",
          // groupName: "Basic Group",
        ),
      ],
      debug: true,
    );
  }

  void _debounceHandleNotification(
      RemoteMessage message, void Function(RemoteMessage) handler) {
    _notificationDebouncer.run(() {
      if (_lastHandledMessageId != message.messageId) {
        logger.d('Notification opened from background: ${message.data}');
        _lastHandledMessageId = message.messageId;
        handler(message);
      }
    });
  }

  @override
  Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      logger.e('Error getting FCM token: $e');
      return null;
    }
  }

  @override
  Future<void> refreshToken(void Function(String) onTokenRefresh) async {
    FirebaseMessaging.instance.onTokenRefresh.listen(onTokenRefresh);
  }

  @override
  void handleNotificationClick(RemoteMessage message) {
    logger.d('Notification clicked: ${message.data}');
    // Implement your notification click handling logic here
  }

  @override
  Future<void> showNotification(RemoteMessage message) async {
    logger.d('Showing notification for message: ${message.data}');
    await _createLocalNotificationFromMessage(message);
  }

  Future<void> _createLocalNotificationFromMessage(
      RemoteMessage message) async {
    try {
      logger
          .d('Creating local notification from message: ${message.messageId}');
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: message.messageId.hashCode,
          channelKey: _config!.channelKey,
          title: message.notification?.title ?? 'New Message',
          body: message.notification?.body ?? 'You have a new message',
          payload: _convertPayload(message.data),
          color: _config?.defaultColor,
          icon: _config?.androidNotificationIcon,
          wakeUpScreen: true,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
        ),
      );
    } catch (e) {
      logger.e('Local notification creation error: $e');
    }
  }

  Map<String, String?> _convertPayload(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, value?.toString()));
  }

  @override
  Future<void> showRegularNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
    String? channelKey,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: channelKey ?? _config!.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: _config?.defaultColor,
          wakeUpScreen: true,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Message,
        ),
      );
    } catch (e) {
      logger.e('Error showing regular notification: $e');
    }
  }

  @override
  Future<void> showActionNotification({
    required String title,
    required String body,
    List<NotificationActionButton>? buttons,
    Map<String, String>? payload,
    String? channelKey,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: channelKey ?? _config!.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: _config?.defaultColor,
          wakeUpScreen: true,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Social,
        ),
        actionButtons: buttons,
      );
    } catch (e) {
      logger.e('Error showing action notification: $e');
    }
  }

  @override
  Future<void> showReplyNotification({
    required String title,
    required String body,
    String? replyLabel,
    String? inputPlaceholder,
    NotificationActionButton? replyButton,
    Map<String, String>? payload,
    String? channelKey,
  }) async {
    try {
      final actionButtons = <NotificationActionButton>[
        replyButton ??
            NotificationActionButton(
              key: 'REPLY',
              label: replyLabel ?? 'Reply',
              requireInputText: true,
              // autoDismiss: true,
              // buttonType: ActionButtonType.InputField,
              actionType: ActionType.Default,
              // inputPlaceholder: inputPlaceholder,
            ),
      ];
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: channelKey ?? _config!.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: _config?.defaultColor,
          wakeUpScreen: true,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Social,
        ),
        actionButtons: actionButtons,
      );
    } catch (e) {
      logger.e('Error showing reply notification: $e');
    }
  }

  @override
  Future<void> showGroupedNotification(
      String groupKey, List<NotificationContent> messages) async {
    try {
      for (final message in messages) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: message.id!,
            channelKey: message.channelKey ?? '',
            title: message.title!,
            body: message.body,
            payload: message.payload,
            color: message.color,
            wakeUpScreen: message.wakeUpScreen ?? false,
            notificationLayout:
                message.notificationLayout ?? NotificationLayout.Default,
            category: message.category,
            groupKey: groupKey,
          ),
        );
      }
    } catch (e) {
      logger.e('Error showing grouped notifications: $e');
    }
  }

  @override
  Future<void> scheduleNotification(
      int id, String title, String body, DateTime scheduledDate,
      {Map<String, String>? payload, String? channelKey}) async {
    try {
      await AwesomeNotifications().createNotification(
        schedule: NotificationCalendar.fromDate(date: scheduledDate),
        content: NotificationContent(
          id: id,
          channelKey: channelKey ?? _config!.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: _config?.defaultColor,
          wakeUpScreen: true,
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Alarm,
        ),
      );
    } catch (e) {
      logger.e('Error scheduling notification: $e');
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }

  @override
  Future<void> updateBadgeCount(int count) async {
    await AwesomeNotifications().setGlobalBadgeCounter(count);
  }

  @override
  Future<void> clearBadgeCount() async {
    await AwesomeNotifications().resetGlobalBadge();
  }

  @override
  Future<void> openAppSettings() async {
    await AwesomeNotifications().showNotificationConfigPage(
        // settingsAndroid: true,
        // settingsIOS: true,
        );
  }

  @override
  Future<void> openNotificationSettings() async {
    await AwesomeNotifications().showNotificationConfigPage();
  }

  @override
  void simulateNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? channelKey,
  }) {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: channelKey ?? _config!.channelKey,
        title: title,
        body: body,
        payload: data?.cast<String, String>(),
        color: _config?.defaultColor,
        wakeUpScreen: true,
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  @override
  void dispose() {
    //  if (receivePort != null) { // commented out to fix error
    //   receivePort?.close();
    //   receivePort = null;
    // }
  }

  @override
  void enableDevTool() {
    // AwesomeNotifications().enableDevMode();
  }

  @override
  void disableDevTool() {
    // AwesomeNotifications().disableDevMode();
  }

  @override
  Future<AuthorizationStatus> requestPermissions() async {
    if (_permissionRequestLock) {
      logger.w('Permission request already in progress');
      return permissionStatus.value;
    }
    _permissionRequestLock = true;
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      permissionStatus.value = settings.authorizationStatus;

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        logger.d('Permissions already granted');
        return permissionStatus.value;
      }

      logger.i('Requesting FCM permissions...');
      if (permissionStatus.value == AuthorizationStatus.notDetermined) {
        final newSettings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        logger.i('FCM permission status: ${newSettings.authorizationStatus}');
        permissionStatus.value = newSettings.authorizationStatus;

        FirebaseAnalytics.instance.logEvent(
          name: 'notification_permission_request',
          parameters: {
            'previous_status': permissionStatus.value.toString(),
            'new_status': newSettings.authorizationStatus.toString(),
          },
        );
      }

      if (!await AwesomeNotifications().isNotificationAllowed()) {
        logger.i('Requesting AwesomeNotifications permissions...');
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }
    } catch (e) {
      logger.e('Firebase permission error: $e');
    } finally {
      _permissionRequestLock = false;
    }
    return permissionStatus.value;
  }

  Future<void> startListeningNotificationEvents() async {
    logger.d("Start listening to notification events");
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onNotificationDismissActionReceivedMethod,
    );
    await initializeIsolateReceivePort();
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    Logger('NotificationWrapper')
        .d('Action received: ${receivedAction.actionType}');
    if (receivedAction.actionType == ActionType.SilentAction ||
        receivedAction.actionType == ActionType.SilentBackgroundAction) {
      Logger('NotificationWrapper').d(
          'Silent action received with input: ${receivedAction.buttonKeyInput}');
      await executeLongTaskInBackground();
    } else {
      if (receivePort == null) {
        Logger('NotificationWrapper')
            .d('onActionREceiveMethod called inside a parallel dart isolate.');
        SendPort? sendPort =
            IsolateNameServer.lookupPortByName('notification_action_port');
        if (sendPort != null) {
          Logger('NotificationWrapper')
              .d('Redirecting action to main isolate.');
          sendPort.send(receivedAction);
          return;
        }
      }
      return onActionReceivedImplementationMethod(receivedAction);
    }
  }

  static Future<void> onActionReceivedImplementationMethod(
      ReceivedAction receivedAction) async {
    Logger('NotificationWrapper')
        .d('Handling action: ${receivedAction.payload}');
    final instance = DefaultNotificationHandler(); // Get an instance
    if (receivedAction.payload != null) {
      instance.handleActionReceived(receivedAction);
    }
  }

  static Future<void> executeLongTaskInBackground() async {
    Logger('NotificationWrapper').d("Starting long background task");
    await Future.delayed(const Duration(seconds: 4));
    Logger('NotificationWrapper').d("Long background task done");
  }

  static Future<void> initializeIsolateReceivePort() async {
    receivePort = ReceivePort('Notification action port in main isolate')
      ..listen((silentData) =>
          onActionReceivedImplementationMethod(silentData as ReceivedAction));
    IsolateNameServer.registerPortWithName(
        receivePort!.sendPort, 'notification_action_port');
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    Logger('NotificationWrapper')
        .d("Notification created with ID: ${receivedNotification.id}");
    final instance = DefaultNotificationHandler(); // Get an instance
    await instance.onNotificationCreated(receivedNotification);
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    Logger('NotificationWrapper')
        .d("Notification displayed with ID: ${receivedNotification.id}");
    final instance = DefaultNotificationHandler(); // Get an instance
    await instance.onNotificationDisplayed(receivedNotification);
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    Logger('NotificationWrapper')
        .d("Notification dismissed with ID: ${receivedAction.id}");
    final instance = DefaultNotificationHandler(); // Get an instance
    await instance.onNotificationDismissed(receivedAction);
  }

  @pragma('vm:entry-point')
  Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    // await Firebase
    //     .initializeApp(); // Ensure Firebase is initialized in the background isolate
    Logger('NotificationWrapper')
        .d('Background message received: ${message.messageId}');
    onBackgroundMessage(message);
  }

  // @override
  // void onFailedToResolveHostname(Exception exception) {
  //   if (onFailedToResolveHostname != null) {
  //     onFailedToResolveHostname!(exception);
  //   }
  // }

  // @override
  // void onIosTokens({required String token, required String raw}) {
  //   if (onIosTokens != null) {
  //     onIosTokens!(token: token, raw: raw);
  //   }
  // }

  // @override
  // void onAndroidPermission(ReceivedAction action) {
  //   if (onAndroidPermission != null) {
  //     onAndroidPermission!(action);
  //   }
  // }
}
