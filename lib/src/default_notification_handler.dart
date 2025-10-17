// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs, avoid_catches_without_on_clauses

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'notification_config.dart';
import 'notification_wrapper.dart';
import 'utils/debounce.dart';
import 'utils/logger.dart';
import 'utils/rx.dart'; // Assuming you have a Logger utility

class DefaultNotificationHandler extends NotificationWrapper {
  // Private constructor
  DefaultNotificationHandler._internal({
    // Pass handler overrides to NotificationWrapper's constructor
    super.onMessageOverride,
    super.onMessageOpenedAppOverride,
    super.onBackgroundMessageOverride,
    super.onNotificationCreatedOverride,
    super.onNotificationDisplayedOverride,
    super.onNotificationDismissedOverride,
    super.handleActionReceivedOverride,
    super.onFailedToResolveHostname,
    super.onIosTokens,
    super.onAndroidPermission,
  });
  static const Logger _logger = Logger('DefaultNotificationHandler');
  final Debouncer _notificationDebouncer =
      Debouncer(delay: const Duration(milliseconds: 500));
  String? _lastHandledMessageId;
  final Rx<AuthorizationStatus> permissionStatus =
      Rx<AuthorizationStatus>(AuthorizationStatus.notDetermined);
  bool _permissionRequestLock = false;
  NotificationConfig? _config;
  static ReceivePort? _receivePort;

  // Singleton instance
  static DefaultNotificationHandler? _instance;

  // --- Fallback Channel Keys ---
  static const String _fallbackBackgroundChannelKey =
      'fallback_background_channel';
  static const String _emergencyFallbackChannelKey =
      'emergency_fallback_channel';

  // Static getter for the instance
  static DefaultNotificationHandler get I {
    if (_instance == null) {
      // Initialize with default handlers from NotificationWrapper if not explicitly provided during initializeSharedInstance
      _instance = DefaultNotificationHandler._internal(
        onBackgroundMessageOverride: smartDefaultBackgroundMessageHandler,
      );
      _logger.w(
        'DefaultNotificationHandler singleton created on-the-fly (e.g., in background isolate). Initializing with a fallback config.',
      );
      // **** IMPORTANT FIX FOR BACKGROUND CONFIG ****
      // If a new instance is created (likely in a background isolate without full init),
      // provide it with a default/fallback NotificationConfig.
      _instance!._config = const NotificationConfig(
        channelKey:
            'fallback_background_channel', // Define a specific fallback channel
        channelName: 'Background Notifications',
        channelDescription: 'Notifications processed in the background.',
        androidNotificationIcon:
            'resource://drawable/notification_icon', // Optional: if you have a default icon
        defaultColor: Color(0xff00AADE), // Optional: a default color
      );
      // This new instance also needs its notification channels set up if it's going to show notifications.
      // This implies _setupNotificationChannels might need to be callable safely by such an instance.
      // For simplicity, we assume the channel used by this fallback config is *already*
      // initialized by AwesomeNotifications during the main app startup.
      // If not, _setupNotificationChannels would need to be called here for this fallback channel.
    }
    return _instance!;
  }

  // Add this method to reset the instance for testing
  @visibleForTesting
  static void resetInstance() {
    _logger.d(
        'Resetting DefaultNotificationHandler singleton instance for testing.');
    _instance = null;
  }

  // Static initialization method for the shared instance
  static Future<DefaultNotificationHandler> initializeSharedInstance({
    NotificationConfig? config,
    FirebaseOptions? firebaseOptions,
    // Optional: Allow overriding handlers during shared instance initialization
    void Function(RemoteMessage)? onMessageOverride,
    void Function(RemoteMessage)? onMessageOpenedAppOverride,
    Future<void> Function(RemoteMessage)? onBackgroundMessageOverride,
    Future<void> Function(ReceivedNotification)? onNotificationCreatedOverride,
    Future<void> Function(ReceivedNotification)?
        onNotificationDisplayedOverride,
    Future<void> Function(ReceivedAction)? onNotificationDismissedOverride,
    Future<void> Function(ReceivedAction)? handleActionReceivedOverride,
    void Function(Exception exception)? onFailedToResolveHostname,
    void Function({required String token, required String raw})? onIosTokens,
    void Function(ReceivedAction action)? onAndroidPermission,
  }) async {
    if (_instance == null) {
      _instance = DefaultNotificationHandler._internal(
        onMessageOverride: onMessageOverride,
        onMessageOpenedAppOverride: onMessageOpenedAppOverride,
        onBackgroundMessageOverride: onBackgroundMessageOverride,
        onNotificationCreatedOverride: onNotificationCreatedOverride,
        onNotificationDisplayedOverride: onNotificationDisplayedOverride,
        onNotificationDismissedOverride: onNotificationDismissedOverride,
        handleActionReceivedOverride: handleActionReceivedOverride,
        onFailedToResolveHostname: onFailedToResolveHostname,
        onIosTokens: onIosTokens,
        onAndroidPermission: onAndroidPermission,
      );
      _logger.d('DefaultNotificationHandler shared instance created.');
    } else {
      _logger.i(
        'DefaultNotificationHandler shared instance already exists. Re-initializing with new config if provided.',
      );
      // Optionally update handlers if re-initializing, though typically initializeSharedInstance is called once.
    }
    // The 'initialize' method is now an instance method.
    await _instance!
        .initialize(config: config, firebaseOptions: firebaseOptions);
    return _instance!;
  }

  @override
  Future<void> initialize({
    NotificationConfig? config,
    FirebaseOptions? firebaseOptions,
  }) async {
    _logger.d('Initializing DefaultNotificationHandler instance...');
    _config = config ?? NotificationConfig.defaultConfig();

    if (firebaseOptions != null) {
      // Ensure Firebase is initialized. If called multiple times, it's a no-op.
      _logger.d('Firebase: ${firebaseOptions.appId}');

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: firebaseOptions);
        _logger.d('Firebase initialized with provided options.');
      } else {
        _logger.d('Firebase already initialized.');
      }

      // Use the instance's onBackgroundMessage for the handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Listeners now use the instance's handlers (which could be defaults or overrides)
      FirebaseMessaging.onMessage.listen((message) {
        _logger.d('FCM onMessage received in instance: ${message.messageId}');
        onMessage(message); // Calls the potentially overridden onMessage
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _logger.d(
          'FCM onMessageOpenedApp received in instance: ${message.messageId}',
        );
        _debounceHandleNotification(message, onMessageOpenedApp);
      });
      // Token refresh is handled by the refreshToken method
    } else {
      _logger.w('FirebaseOptions not provided. FCM features might not work.');
    }

    await _setupNotificationChannels();
    await _startListeningAwesomeNotificationEvents();
    await requestPermissions(); // Request permissions after setup
    _logger.d('DefaultNotificationHandler instance initialized.');
  }

  Future<void> _setupNotificationChannels() async {
    _logger.d('Setting up AwesomeNotification channels...');
    if (_config == null) {
      _logger.e(
        'Cannot setup notification channels because _config is null. This should not happen if initialized correctly.',
      );
      // This is a critical state, assign a very basic config to prevent crashes, but log error.
      _config = const NotificationConfig(
        channelKey: _emergencyFallbackChannelKey,
        channelName: 'Error Fallback Channel',
        channelDescription:
            'Critical error: config was null during channel setup.',
      );
    }
    _logger.d(
      'Setting up AwesomeNotification channels. Main config channel: ${_config!.channelKey}',
    );

    // List to hold all channel definitions
    // 1. Add the main channel from the current _config
    final channelsToCreate = <NotificationChannel>[
      NotificationChannel(
        channelKey: _config!.channelKey,
        channelName: _config!.channelName,
        channelDescription:
            _config!.channelDescription ?? 'Notification channel',
        importance: NotificationImportance.High, // Default importance
        channelShowBadge: true,
        playSound: true,
        defaultColor: _config!.defaultColor ?? Colors.blue,
        defaultPrivacy: NotificationPrivacy.Public,
        groupAlertBehavior:
            GroupAlertBehavior.Children, // Default group behavior
        groupKey:
            '${_config!.channelKey}_group', // Group key based on channel key
      ),
    ];

    // 2. Ensure the Fallback Background Channel is defined if it's different from the main channel
    if (_config!.channelKey != _fallbackBackgroundChannelKey) {
      _logger.i(
        "Adding '$_fallbackBackgroundChannelKey' to the initialization list.",
      );
      channelsToCreate.add(
        NotificationChannel(
          channelKey: _fallbackBackgroundChannelKey,
          channelName: 'Background Notifications', // User-friendly name
          channelDescription:
              'Notifications processed when the app is in the background.',
          importance: NotificationImportance.Default, // Adjust as needed
          // Define other properties like sound, badge, color if desired for this specific channel
          playSound: true,
          channelShowBadge: true,
        ),
      );
    }

    // 3. Ensure the Emergency Fallback Channel is defined if it's different from the main and background fallback channels
    if (_config!.channelKey != _emergencyFallbackChannelKey &&
        _fallbackBackgroundChannelKey != _emergencyFallbackChannelKey) {
      _logger.i(
        "Adding '$_emergencyFallbackChannelKey' to the initialization list.",
      );
      channelsToCreate.add(
        NotificationChannel(
          channelKey: _emergencyFallbackChannelKey,
          channelName: 'Emergency Notifications', // User-friendly name
          channelDescription: 'Channel for critical fallback notifications.',
          importance:
              NotificationImportance.High, // Typically high for emergencies
          playSound: true,
          channelShowBadge: true,
        ),
      );
    }

    // Remove duplicate channel definitions by key before initializing
    final uniqueChannels = <String, NotificationChannel>{};
    for (final channel in channelsToCreate) {
      uniqueChannels[channel.channelKey!] = channel;
    }

    await AwesomeNotifications().initialize(
      _config!.androidNotificationIcon,
      channelsToCreate,
      debug: true, // Set to false in production
    );
    // await AwesomeNotifications().initialize(
    //   _config
    //       ?.androidNotificationIcon, // e.g., 'resource://drawable/res_app_icon'
    //   [
    //     NotificationChannel(
    //       channelKey: _config!.channelKey,
    //       channelName: _config!.channelName,
    //       channelDescription:
    //           _config!.channelDescription ?? 'Notification channel',
    //       importance: NotificationImportance.High,
    //       channelShowBadge: true,
    //       playSound: true,
    //       defaultColor: _config?.defaultColor ?? const Color(0xff00AADE),
    //       defaultPrivacy: NotificationPrivacy.Public,
    //       groupAlertBehavior: GroupAlertBehavior.Children,
    //       groupKey:
    //           "${_config!.channelKey}_group", // Ensure groupKey is unique or well-defined
    //     ),
    //     // Add other channels if needed
    //   ],
    //   debug: true, // Set to false in production
    // );
    _logger.d('AwesomeNotification channels configured.');
  }

  void _debounceHandleNotification(
    RemoteMessage message,
    void Function(RemoteMessage) handler,
  ) {
    _notificationDebouncer.run(() {
      if (_lastHandledMessageId != message.messageId ||
          message.messageId == null) {
        _logger.d(
          'Debounced handling for notification: ${message.messageId ?? "N/A"}',
        );
        _lastHandledMessageId = message.messageId;
        handler(message);
      } else {
        _logger.d(
          'Duplicate notification open event debounced: ${message.messageId}',
        );
      }
    });
  }

  @override
  Future<String?> getFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      _logger.d('FCM Token: $token');
      return token;
    } catch (e) {
      _logger.e('Error getting FCM token: $e');
      onFailedToResolveHostname?.call(e as Exception);
      return null;
    }
  }

  @override
  Future<void> refreshToken(void Function(String) onTokenRefresh) async {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _logger.i('FCM Token refreshed: $token');
      onTokenRefresh(token);
      // Optionally, send to your server
    });
  }

  @override
  void handleNotificationClick(RemoteMessage message) {
    _logger.d(
      'Notification click being handled by instance: ${message.messageId}',
    );
    // Default implementation could be empty or log, actual handling is often app-specific
    // and might be done within onMessageOpenedApp or handleActionReceived.
    // This method is here for explicit click handling if needed separately.
  }

  @override
  Future<void> showNotification(RemoteMessage message) async {
    if (_config == null) {
      _logger.e(
        'Attempting to show notification, but _config is null. Message: ${message.messageId}',
      );
      // Optionally, try to use DefaultNotificationHandler.I to ensure _config gets the fallback
      // This is a bit redundant if 'I' getter already sets it, but as a safeguard:
      if (DefaultNotificationHandler.I._config == null) {
        _logger.e(
          'Critical: Fallback _config in singleton is also null. Notification will likely fail.',
        );
        return; // Cannot proceed
      }
      // Use the singleton's config if the current instance's is null (shouldn't happen if 'this' is the singleton)
      _config = DefaultNotificationHandler.I._config;
    }
    _logger.d(
      'Instance (channel: ${_config?.channelKey}) showing notification for FCM message: ${message.messageId}',
    );
    await _createLocalNotificationFromMessage(message);
  }

  Future<void> _createLocalNotificationFromMessage(
    RemoteMessage message,
  ) async {
    if (_config == null) {
      _logger.e(
        'Cannot create local notification because _config is null. Message ID: ${message.messageId}',
      );
      // Attempt to use a hardcoded default channel key as a last resort
      // This indicates a setup problem.
      const emergencyChannelKey = 'emergency_fallback_channel';
      _logger.w('Using emergency fallback channel key: $emergencyChannelKey');
      // Ensure this emergency channel is also created by AwesomeNotifications at startup.
      try {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: message.messageId.hashCode,
            channelKey: emergencyChannelKey, // LAST RESORT
            title: message.notification?.title ??
                message.data['title'] ??
                'New Message',
            body: message.notification?.body ??
                message.data['body'] ??
                'You have a new message.',
            payload: _convertPayload(message.data),
          ),
        );
      } catch (e) {
        _logger.e('Emergency local notification creation error: $e');
      }
      return;
    }

    try {
      final title =
          message.notification?.title ?? message.data['title'] ?? 'New Message';
      final body = message.notification?.body ??
          message.data['body'] ??
          'You have a new message.';
      _logger.d(
        'Creating local notification (channel: ${_config!.channelKey}): "$title" - "$body"',
      );

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: message.messageId.hashCode,
          channelKey: _config!.channelKey, // Uses the _config
          title: title,
          body: body,
          payload: _convertPayload(message.data),
          color: _config!.defaultColor,
          icon: _config!.androidNotificationIcon,
          wakeUpScreen: true,
          category: NotificationCategory.Reminder,
        ),
      );
      _logger.d(
        'Local notification created for FCM message: ${message.messageId}',
      );
    } catch (e) {
      _logger.e(
        'Local notification creation error from FCM: $e. Config channel key was: ${_config?.channelKey}',
      );
    }
    // try {
    //   final title =
    //       message.notification?.title ?? message.data['title'] ?? 'New Message';
    //   final body = message.notification?.body ??
    //       message.data['body'] ??
    //       'You have a new message.';
    //   _logger.d('Creating local notification: "$title" - "$body"');
    //   _logger.d('convert payload: ${message.data}');
    //   _logger.d('config: $_config');

    //   await AwesomeNotifications().createNotification(
    //     content: NotificationContent(
    //       id: message.messageId.hashCode, // Use a consistent ID
    //       channelKey: _config?.channelKey ??
    //           NotificationConfig.defaultConfig().channelKey,
    //       title: title,
    //       body: body,
    //       payload: _convertPayload(message.data),
    //       color: _config?.defaultColor,
    //       icon: _config?.androidNotificationIcon,
    //       wakeUpScreen: true,
    //       notificationLayout: NotificationLayout.Default,
    //       category:
    //           NotificationCategory.Reminder, // Or determine from message data
    //     ),
    //   );
    //   _logger.d(
    //       'Local notification created for FCM message: ${message.messageId}');
    // } catch (e) {
    //   _logger.e('Local notification creation error from FCM: $e');
    // }
  }

  Map<String, String?> _convertPayload(Map<String, dynamic> data) =>
      data.map((key, value) => MapEntry(key, value?.toString()));

  @override
  Future<void> showRegularNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
    String? channelKey,
  }) async {
    if (_config == null && DefaultNotificationHandler.I._config == null) {
      _logger.e('Config is null in showRegularNotification. Cannot proceed.');
      return;
    }
    final currentConfig = _config ?? DefaultNotificationHandler.I._config!;
    _logger.d(
      'Showing regular notification via instance (channel: ${channelKey ?? currentConfig.channelKey}): "$title"',
    );
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: channelKey ?? currentConfig.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: currentConfig.defaultColor,
          wakeUpScreen: true,
          category: NotificationCategory.Reminder,
        ),
      );
    } catch (e) {
      _logger.e('Error showing regular notification: $e');
    }
  }

  @override
  Future<void> showActionNotification({
    required String title,
    required String body,
    List<NotificationActionButton>? buttons, // Made required for clarity
    Map<String, String>? payload,
    String? channelKey,
  }) async {
    if (_config == null && DefaultNotificationHandler.I._config == null) {
      _logger.e('Config is null in showRegularNotification. Cannot proceed.');
      return;
    }
    final currentConfig = _config ?? DefaultNotificationHandler.I._config!;

    _logger.d(
      'Showing action notification via instance (channel: ${channelKey ?? currentConfig.channelKey}): "$title"',
    );
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: channelKey ?? currentConfig.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: currentConfig.defaultColor,
          wakeUpScreen: true,
          category: NotificationCategory.Social, // Example category
        ),
        actionButtons: buttons,
      );
    } catch (e) {
      _logger.e('Error showing action notification: $e');
    }
  }

  @override
  Future<void> showReplyNotification({
    required String title,
    required String body,
    String? replyLabel,
    String?
        inputPlaceholder, // Not directly used by AwesomeNotifications in this way
    NotificationActionButton? replyButton,
    Map<String, String>? payload,
    String? channelKey,
  }) async {
    if (_config == null && DefaultNotificationHandler.I._config == null) {
      _logger.e('Config is null in showRegularNotification. Cannot proceed.');
      return;
    }
    final currentConfig = _config ?? DefaultNotificationHandler.I._config!;

    _logger.d(
      'Showing reply notification via instance (channel: ${channelKey ?? currentConfig.channelKey}): "$title"',
    );

    try {
      final actionButtons = <NotificationActionButton>[
        replyButton ??
            NotificationActionButton(
              key: 'REPLY_ACTION', // Ensure keys are unique and meaningful
              label: replyLabel ?? 'Reply',
              requireInputText: true,
              actionType: ActionType
                  .SilentBackgroundAction, // Or Default if UI should handle
              // autoDismissible: true, // Default is true for ActionType.Default
            ),
      ];
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: channelKey ?? currentConfig.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: currentConfig.defaultColor,
          wakeUpScreen: true,
          notificationLayout:
              NotificationLayout.Messaging, // Better for replies
          category: NotificationCategory.Reminder,
        ),
        actionButtons: actionButtons,
      );
    } catch (e) {
      _logger.e('Error showing reply notification: $e');
    }
  }

  @override
  Future<void> showGroupedNotification(
    String? groupKey,
    List<NotificationContent> messages,
  ) async {
    if (_config == null && DefaultNotificationHandler.I._config == null) {
      _logger.e('Config is null in showRegularNotification. Cannot proceed.');
      return;
    }
    final currentConfig = _config ?? DefaultNotificationHandler.I._config!;

    _logger.d(
      'Showing grouped notification via instance (group: ${groupKey ?? currentConfig.channelKey}): "$messages"',
    );

    try {
      for (final messageContent in messages) {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: messageContent.id ??
                DateTime.now().millisecondsSinceEpoch.remainder(100000),
            channelKey: messageContent.channelKey ?? currentConfig.channelKey,
            title: messageContent.title,
            body: messageContent.body,
            summary: messageContent.summary, // Important for group summary
            payload: messageContent.payload,
            groupKey: groupKey, // Assign the group key
            notificationLayout:
                messageContent.notificationLayout ?? NotificationLayout.Default,
            category: messageContent.category,
            wakeUpScreen: messageContent.wakeUpScreen ?? true,
            color: messageContent.color ?? currentConfig.defaultColor,
          ),
        );
      }
    } catch (e) {
      _logger.e('Error showing grouped notifications: $e');
    }
  }

  @override
  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledDate, {
    Map<String, String>? payload,
    String? channelKey,
  }) async {
    if (_config == null && DefaultNotificationHandler.I._config == null) {
      _logger.e('Config is null in showRegularNotification. Cannot proceed.');
      return;
    }
    final currentConfig = _config ?? DefaultNotificationHandler.I._config!;

    _logger
      ..d(
        'Scheduling notification via instance (channel: ${channelKey ?? currentConfig.channelKey}): "$title"',
      )
      ..d('Scheduling notification ID $id: "$title" for $scheduledDate');

    try {
      await AwesomeNotifications().createNotification(
        schedule: NotificationCalendar.fromDate(
          date: scheduledDate,
          allowWhileIdle: true,
        ),
        content: NotificationContent(
          id: id,
          channelKey: channelKey ?? currentConfig.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: currentConfig.defaultColor,
          wakeUpScreen: true,
          category: NotificationCategory.Reminder, // Example category
        ),
      );
    } catch (e) {
      _logger.e('Error scheduling notification: $e');
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    _logger.d('Cancelling notification ID: $id');
    await AwesomeNotifications().cancel(id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    _logger.d('Cancelling all notifications.');
    await AwesomeNotifications().cancelAll();
  }

  @override
  Future<void> updateBadgeCount(int count) async {
    _logger.d('Updating badge count to: $count');
    await AwesomeNotifications().setGlobalBadgeCounter(count);
  }

  @override
  Future<void> clearBadgeCount() async {
    _logger.d('Clearing badge count.');
    await AwesomeNotifications().resetGlobalBadge();
  }

  @override
  Future<void> openAppSettings() async {
    _logger.d('Opening app system settings.');
    await AwesomeNotifications()
        .showNotificationConfigPage(); // Opens general app settings
  }

  @override
  Future<void> openNotificationSettings() async {
    _logger.d('Opening notification specific settings for the app.');
    await AwesomeNotifications()
        .showNotificationConfigPage(); // Can target a channel
  }

  @override
  void simulateNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? channelKey,
  }) {
    _logger.d('Simulating notification: "$title"');
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: channelKey ?? _config!.channelKey,
        title: title,
        body: body,
        payload: data
            ?.cast<String, String>(), // Ensure payload is Map<String, String?>
        color: _config?.defaultColor,
        wakeUpScreen: true,
      ),
    );
  }

  @override
  void dispose() {
    _logger.d('Disposing DefaultNotificationHandler resources.');
    if (_receivePort != null) {
      IsolateNameServer.removePortNameMapping('notification_action_port');
      _receivePort!.close();
      _receivePort = null;
      _logger.d('ReceivePort closed and removed.');
    }
    _notificationDebouncer.timer?.cancel(); // Dispose debouncer timer
  }

  @override
  void enableDevTool() {
    _logger.d('Enabling AwesomeNotifications DevTool (if available).');
    // AwesomeNotifications().setDevMode(true); // Or similar if API changed
  }

  @override
  void disableDevTool() {
    _logger.d('Disabling AwesomeNotifications DevTool (if available).');
    // AwesomeNotifications().setDevMode(false); // Or similar if API changed
  }

  @override
  Future<AuthorizationStatus> requestPermissions() async {
    if (_permissionRequestLock) {
      _logger.w(
        'Permission request already in progress. Returning current status: ${permissionStatus.value}',
      );
      return permissionStatus.value;
    }
    _permissionRequestLock = true;
    _logger.i('Requesting notification permissions...');

    try {
      // Check FCM permissions first
      var settings = await FirebaseMessaging.instance.getNotificationSettings();
      _logger
          .d('Current FCM permission status: ${settings.authorizationStatus}');
      permissionStatus.value = settings.authorizationStatus;

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        if (settings.authorizationStatus == AuthorizationStatus.notDetermined ||
            settings.authorizationStatus == AuthorizationStatus.denied) {
          _logger.i('Requesting FCM permission...');
          settings = await FirebaseMessaging.instance.requestPermission();
          _logger
              .i('New FCM permission status: ${settings.authorizationStatus}');
          permissionStatus.value = settings.authorizationStatus;

          await FirebaseAnalytics.instance.logEvent(
            name: 'notification_permission_fcm_request',
            parameters: {'status': settings.authorizationStatus.toString()},
          );
        }
      }

      // Then check AwesomeNotifications permissions
      if (!await AwesomeNotifications().isNotificationAllowed()) {
        _logger.i('AwesomeNotifications permission not granted. Requesting...');
        final awesomeRequested =
            await AwesomeNotifications().requestPermissionToSendNotifications(
          channelKey:
              _config?.channelKey, // Optionally request for a specific channel
          permissions: [
            NotificationPermission.Alert,
            NotificationPermission.Sound,
            NotificationPermission.Badge,
            NotificationPermission.Vibration,
            // Add others as needed
          ],
        );
        _logger.i(
          'AwesomeNotifications permission request result: $awesomeRequested',
        );
        await FirebaseAnalytics.instance.logEvent(
          name: 'notification_permission_awesome_request',
          parameters: {'granted': awesomeRequested.toString()},
        );
        // Update overall status if AwesomeNotifications was denied after FCM was authorized
        if (!awesomeRequested &&
            permissionStatus.value == AuthorizationStatus.authorized) {
          // This scenario is tricky; FCM might be authorized but local notifications blocked.
          // The app needs to decide how to represent this.
          _logger.w(
            'FCM authorized, but AwesomeNotifications permission denied by user.',
          );
        }
      } else {
        _logger.d('AwesomeNotifications permission already granted.');
      }
    } catch (e) {
      _logger.e('Error requesting permissions: $e');
      onFailedToResolveHostname?.call(e as Exception);
    } finally {
      _permissionRequestLock = false;
    }
    _logger
        .i('Final permission status after request: ${permissionStatus.value}');
    return permissionStatus.value;
  }

  @override
  Future<bool> isNotificationAllowed() async =>
      AwesomeNotifications().isNotificationAllowed();

  Future<void> _startListeningAwesomeNotificationEvents() async {
    _logger.d('Starting to listen for AwesomeNotification events.');
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
      onNotificationCreatedMethod: _onNotificationCreatedMethod,
      onNotificationDisplayedMethod: _onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: _onNotificationDismissActionReceivedMethod,
    );
    await _initializeIsolateReceivePort();
    _logger.d('AwesomeNotification event listeners set up.');
  }

  // ================== STATIC AWESOME NOTIFICATION CALLBACKS ===================
  // These static methods are entry points for AwesomeNotifications.
  // They will use the singleton DefaultNotificationHandler.I to call instance methods.

  @pragma('vm:entry-point')
  static Future<void> _onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    final logger = const Logger('DefaultNotificationHandlerStatic')
      ..d(
        'Static: Action received - Key: ${receivedAction.buttonKeyPressed}, Type: ${receivedAction.actionType}, Payload: ${receivedAction.payload}',
      );

    // Redirect to main isolate if needed (especially for UI updates or complex logic)
    if (receivedAction.actionType != ActionType.SilentAction &&
        receivedAction.actionType != ActionType.SilentBackgroundAction) {
      if (_receivePort == null) {
        // Check if we are in the main isolate
        logger.d(
          'Action received in background isolate. Forwarding to main isolate.',
        );
        final sendPort =
            IsolateNameServer.lookupPortByName('notification_action_port');
        if (sendPort != null) {
          sendPort.send(receivedAction);
          return; // Handled by forwarding
        } else {
          logger.w(
            'Could not find SendPort "notification_action_port". Handling in current isolate (might be background).',
          );
          // Fallback: handle directly or log error. This might happen if main isolate port isn't registered yet.
        }
      }
    }
    // If it's a silent action or if it's already in the main isolate (or fallback)
    await _onActionReceivedImplementation(receivedAction);
  }

  // This method should be callable from both static context (after potential isolate hop) and directly.
  static Future<void> _onActionReceivedImplementation(
    ReceivedAction receivedAction,
  ) async {
    final logger = const Logger('DefaultNotificationHandlerImpl')
      ..d(
        'Handling action implementation - Key: ${receivedAction.buttonKeyPressed}, Payload: ${DefaultNotificationHandler.I._config?.channelName}',
      );

    if (receivedAction.buttonKeyPressed == 'REPLY_ACTION' &&
        receivedAction.buttonKeyInput.isNotEmpty) {
      logger.d('Reply action: "${receivedAction.buttonKeyInput}"');
      // Example: Process the reply
      // await DefaultNotificationHandler.I.processReply(receivedAction.buttonKeyInput, receivedAction.payload);
    }

    // Call the instance's handler
    // The 'handleActionReceived' is the method from NotificationWrapper,
    // which DefaultNotificationHandler.I implements (or uses the default from NotificationWrapper).
    await DefaultNotificationHandler.I.handleActionReceived(receivedAction);

    if (receivedAction.actionType == ActionType.SilentAction ||
        receivedAction.actionType == ActionType.SilentBackgroundAction) {
      logger.d(
        'Executing long task for silent action: ${receivedAction.buttonKeyPressed}',
      );
      await _executeLongTaskInBackground(receivedAction);
    }
  }

  static Future<void> _executeLongTaskInBackground(
    ReceivedAction receivedAction,
  ) async {
    final logger = const Logger('DefaultNotificationHandlerStatic')
      ..d(
        'Starting long background task for action: ${receivedAction.buttonKeyPressed}',
      );
    // Example: Perform some background processing based on receivedAction
    await Future.delayed(const Duration(seconds: 4));
    logger.d(
      'Long background task done for action: ${receivedAction.buttonKeyPressed}',
    );
  }

  static Future<void> _initializeIsolateReceivePort() async {
    if (_receivePort == null) {
      // Only register once
      _receivePort = ReceivePort('NotificationActionPort_MainIsolate');
      _receivePort!.listen((data) {
        if (data is ReceivedAction) {
          const Logger('DefaultNotificationHandlerStatic').d(
            'Action received in main isolate via port: ${data.buttonKeyPressed}',
          );
          _onActionReceivedImplementation(data);
        }
      });
      IsolateNameServer.registerPortWithName(
        _receivePort!.sendPort,
        'notification_action_port',
      );
      const Logger('DefaultNotificationHandlerStatic')
          .d('Isolate ReceivePort initialized and registered.');
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationCreatedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    const Logger('DefaultNotificationHandlerStatic').d(
      'Static: Notification CREATED - ID: ${receivedNotification.id}, Channel: ${receivedNotification.channelKey}',
    );
    // Call the instance's handler
    await DefaultNotificationHandler.I
        .onNotificationCreated(receivedNotification);
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationDisplayedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    const Logger('DefaultNotificationHandlerStatic')
        .d('Static: Notification DISPLAYED - ID: ${receivedNotification.id}');
    // Call the instance's handler
    await DefaultNotificationHandler.I
        .onNotificationDisplayed(receivedNotification);
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    const Logger('DefaultNotificationHandlerStatic')
        .d('Static: Notification DISMISSED - ID: ${receivedAction.id}');
    // Call the instance's handler
    await DefaultNotificationHandler.I.onNotificationDismissed(receivedAction);
  }

  // ================== STATIC FIREBASE BACKGROUND HANDLER ===================
  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    final logger = const Logger('DefaultNotificationHandlerStatic')
      ..d(
        'Static: Firebase BACKGROUND message received: ${message.messageId}',
      );

    // IMPORTANT: Firebase must be initialized in this background isolate.
    if (Firebase.apps.isEmpty) {
      // You might need to pass FirebaseOptions if not using the default app,
      // which is complex for background isolates. Usually, this relies on
      // the default Firebase app being configured.
      // If you have custom FirebaseOptions, this part needs careful handling.
      try {
        await Firebase.initializeApp(); // Uses default options if available
        logger.d('Firebase initialized in background isolate.');
      } catch (e) {
        logger.e(
          'Error initializing Firebase in background isolate: $e. Notification might not be processed.',
        );
        return;
      }
    }

    // Now, use the singleton instance's onBackgroundMessage handler.
    // This assumes initializeSharedInstance was called when the app started.
    // If _instance is null, it means the app was likely terminated and restarted
    // by this message. DefaultNotificationHandler.I will create a basic instance.
    await DefaultNotificationHandler.I.onBackgroundMessage(message);
    logger.d('Firebase background message processed by instance handler.');
  }

  /// Smart default handler for background messages to avoid duplicates.
  static Future<void> smartDefaultBackgroundMessageHandler(
    RemoteMessage message,
  ) async {
    // Use instance logger or a specific static one
    final logger = const Logger(
      'DefaultNotificationHandler',
    )..d(
        '[SmartBackgroundHandler] Processing message: ${message.messageId}, Has Notification Part: ${message.notification != null}',
      );

    // If message.notification is null, it's likely a data-only message,
    // or FCM isn't auto-displaying. In this case, we show our own.
    if (message.notification == null) {
      logger.i(
        '[SmartBackgroundHandler] Message is data-only or no FCM notification part. Displaying via AwesomeNotifications.',
      );
      await DefaultNotificationHandler.I.showNotification(message);
    } else {
      logger.i(
        '[SmartBackgroundHandler] Message has "notification" part. Assuming FCM SDK handles display (Android). Skipping AwesomeNotifications display to avoid duplicates.',
      );
      // IMPORTANT: If you have other data processing tasks that need to happen
      // for background messages (even those with a 'notification' part),
      // ensure that logic is called here or within a broader data processing function.
      // For example: await DefaultNotificationHandler.I.processBackgroundMessageData(message.data);
    }
    // Example: If you always need to process data regardless of display:
    // await _processDataFromBackgroundMessage(message.data);
  }
}


/**
 * You're observing that config (specifically, the _config field within your DefaultNotificationHandler instance) is null when processing a background message. This is a common issue related to how Dart isolates work and how your DefaultNotificationHandler singleton is initialized, especially when the app might be started from a terminated state by a notification.

Here's a breakdown of why this happens and how the provided code structure leads to it:

Background Message Handling and Isolates:
When a Firebase Cloud Messaging (FCM) message arrives while your app is in the background or terminated, Firebase typically starts a new Dart isolate (or reuses a limited pool) to handle that message. This background isolate is separate from your main application isolate where your UI runs. Crucially, isolates do not share memory by default.

Singleton Initialization (DefaultNotificationHandler.I):
You're using a singleton pattern for DefaultNotificationHandler with a static getter I. Let's look at its relevant part from default_notification_handler.dart:

Dart

// Static getter for the instance
static DefaultNotificationHandler get I {
  if (_instance == null) {
    // Initialize with default handlers from NotificationWrapper if not explicitly provided during initializeSharedInstance
    _instance = DefaultNotificationHandler._internal(); // <-- A new instance is created here
    _logger.w(
        "DefaultNotificationHandler accessed before initializeSharedInstance. Created with default internal handlers. Call initializeSharedInstance first for custom handlers.");
  }
  return _instance!;
}
_config Initialization:
The _config field (which holds your NotificationConfig object with channel keys, etc.) is populated within the instance method initialize():

Dart

// In DefaultNotificationHandler
@override
Future<void> initialize({
  NotificationConfig? config,
  FirebaseOptions? firebaseOptions,
}) async {
  _logger.d("Initializing DefaultNotificationHandler instance...");
  _config = config ?? // <-- _config is set here
      NotificationConfig(
        channelKey: 'basic_channel',
        channelName: 'Basic notifications',
        channelDescription: 'Default notification channel for app',
      );
  // ... rest of initialization
}
This initialize() method is normally called via DefaultNotificationHandler.initializeSharedInstance() when your app starts up in the main isolate.

The Sequence of Events for a Background Message (App Terminated):

An FCM background message arrives.
The system starts a new Dart isolate to run your _firebaseMessagingBackgroundHandler (defined in default_notification_handler.dart).
Inside _firebaseMessagingBackgroundHandler, it eventually calls DefaultNotificationHandler.I.onBackgroundMessage(message).
If this is the first time DefaultNotificationHandler.I is accessed in this new isolate (or if the app was terminated, so _instance is globally null), the if (_instance == null) condition in the I getter is true.
A new, minimal DefaultNotificationHandler instance is created via DefaultNotificationHandler._internal(). This new instance has not yet had its initialize() method called, so its _config field remains null.
The onBackgroundMessage handler (which might be the default one from NotificationWrapper if not overridden, or your custom one) is then executed on this new instance.
The default background handler in NotificationWrapper is:
Dart

static Future<void> _defaultOnBackgroundMessage(RemoteMessage message) async {
  // ...
  await DefaultNotificationHandler.I.showNotification(message);
}
DefaultNotificationHandler.I.showNotification(message) is called.
Inside showNotification, it calls _createLocalNotificationFromMessage(message).
Inside _createLocalNotificationFromMessage, it tries to access _config!.channelKey. Since _config is null on this freshly created instance, this line will throw a "null check operator used on a null value" error, or if you're checking _config before use, you'll find it's null.
In essence: The NotificationConfig (_config) is tied to the full initialization flow (initializeSharedInstance -> initialize) which happens in your main app startup. When a background message spawns a new isolate and a new "bare" DefaultNotificationHandler instance is created on-the-fly by the I getter, that instance doesn't have its _config set.

The warning log _logger.w("DefaultNotificationHandler accessed before initializeSharedInstance. Created with default internal handlers...") is precisely indicating this scenario.

How to Address This (Solutions are already hinted at or partially implemented in your refactored code, but need to be robust for this case):

The most straightforward way to ensure _config is available for background processing is to make sure that even a "default" instance created by DefaultNotificationHandler.I in a background isolate gets a minimal, usable NotificationConfig.

I'll provide a modified version of default_notification_handler.dart that explicitly sets a default _config if a new instance is created by the I getter. This ensures that showNotification can at least use a fallback channel.
default_notification_handler.dart (Fixed Background Config)
20 May, 11:23

Key changes in the default_notification_handler.dart (Fixed Background Config) immersive:

DefaultNotificationHandler.I Getter Modified:

When _instance is null and a new DefaultNotificationHandler is created, it now immediately assigns a fallback NotificationConfig to _instance!._config.
Dart

_instance!._config = NotificationConfig(
  channelKey: 'fallback_background_channel', // You should define this channel
  channelName: 'Background Notifications',
  // ... other default config values
);
_setupNotificationChannels() Considerations:

You must ensure that the channel key used in the fallback config (e.g., 'fallback_background_channel') is actually created by AwesomeNotifications().initialize(...) when your main app starts up. If AwesomeNotifications doesn't know about this channel, it can't display notifications using it.
The provided code adds a small check to _setupNotificationChannels to attempt to create this fallback channel if it's different from the main config's channel and not yet created. This makes it more robust.
Safeguards in showNotification and _createLocalNotificationFromMessage:

Added checks for _config == null even in these methods. If, for some reason, _config is still null, it logs an error and attempts to use an "emergency" hardcoded channel key. This is a last resort and indicates a setup issue that should be fixed.
By ensuring that any instance of DefaultNotificationHandler (even one created on-the-fly in a background isolate) has a valid _config (even if it's a fallback), you prevent the null error and allow background notifications to be processed and displayed using a predefined channel. Remember to define 'fallback_background_channel' (or your chosen key) in your AwesomeNotifications channel setup during app initialization.
 
 source: Gemini
 */