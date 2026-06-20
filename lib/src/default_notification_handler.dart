// ignore_for_file: lines_longer_than_80_chars, avoid_catches_without_on_clauses, cascade_invocations

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_config.dart';
import 'notification_wrapper.dart';
import 'utils/debounce.dart';
import 'utils/logger.dart';
import 'utils/rx.dart';

/// Default [NotificationWrapper] implementation backed by AwesomeNotifications
/// for display and Firebase Cloud Messaging for delivery.
///
/// Use [initializeSharedInstance] once at app startup, then access the shared
/// handler via [DefaultNotificationHandler.I].
class DefaultNotificationHandler extends NotificationWrapper {
  DefaultNotificationHandler._internal({
    AwesomeNotifications? awesomeNotifications,
    FirebaseMessaging? firebaseMessaging,
    super.onMessageOverride,
    super.onMessageOpenedAppOverride,
    super.onBackgroundMessageOverride,
    super.onNotificationCreatedOverride,
    super.onNotificationDisplayedOverride,
    super.onNotificationDismissedOverride,
    super.handleActionReceivedOverride,
    super.onError,
    super.onPermissionEvent,
  })  : _awesomeOverride = awesomeNotifications,
        _messagingOverride = firebaseMessaging;

  static const Logger _logger = Logger('DefaultNotificationHandler');

  // --- Injectable plugin seams (default to the real singletons) ---
  final AwesomeNotifications? _awesomeOverride;
  final FirebaseMessaging? _messagingOverride;
  AwesomeNotifications get _awesome =>
      _awesomeOverride ?? AwesomeNotifications();
  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  final Debouncer _notificationDebouncer =
      Debouncer(delay: const Duration(milliseconds: 500));
  String? _lastHandledMessageId;

  final Rx<AuthorizationStatus> _permissionStatus =
      Rx<AuthorizationStatus>(AuthorizationStatus.notDetermined);

  /// The most recently observed notification authorization status.
  AuthorizationStatus get permissionStatus => _permissionStatus.value;

  /// Emits whenever [permissionStatus] changes.
  Stream<AuthorizationStatus> get permissionStatusStream =>
      _permissionStatus.stream;

  // --- Event streams (broadcast) ---
  final StreamController<RemoteMessage> _foregroundMessageController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> _messageOpenedController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<ReceivedAction> _actionController =
      StreamController<ReceivedAction>.broadcast();
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();

  @override
  Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundMessageController.stream;
  @override
  Stream<RemoteMessage> get onMessageOpened => _messageOpenedController.stream;
  @override
  Stream<ReceivedAction> get onActionReceived => _actionController.stream;
  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  bool _permissionRequestLock = false;
  NotificationConfig? _config;

  // Active stream subscriptions, cancelled on [dispose] / re-init.
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  static ReceivePort? _receivePort;
  static const String _portName = 'notification_action_port';

  // Whether AwesomeNotifications has been initialized in the current isolate.
  static bool _awesomeInitialized = false;

  // Monotonically increasing id source (positive, 31-bit) so notifications do
  // not collide or silently overwrite each other within a session.
  static int _lastGeneratedId = 0;

  static DefaultNotificationHandler? _instance;

  // --- Fallback channel keys ---
  static const String _fallbackBackgroundChannelKey =
      'fallback_background_channel';
  static const String _emergencyFallbackChannelKey =
      'emergency_fallback_channel';

  /// The shared handler instance.
  ///
  /// If accessed before [initializeSharedInstance] (e.g. in a background
  /// isolate spawned for a push message), a minimal instance with a fallback
  /// config is created so background notifications can still be displayed.
  static DefaultNotificationHandler get I {
    if (_instance == null) {
      _instance = DefaultNotificationHandler._internal(
        onBackgroundMessageOverride: smartDefaultBackgroundMessageHandler,
      );
      _logger.w(
        'DefaultNotificationHandler created on-the-fly (likely a background isolate). Using a fallback config.',
      );
      _instance!._config = const NotificationConfig(
        channelKey: _fallbackBackgroundChannelKey,
        channelName: 'Background Notifications',
        channelDescription: 'Notifications processed in the background.',
        androidNotificationIcon: 'resource://drawable/ic_notification',
        defaultColor: Color(0xff002B5B),
      );
    }
    return _instance!;
  }

  /// The currently active config (fallback config in a background isolate).
  /// Test-only.
  @visibleForTesting
  NotificationConfig? get debugConfig => _config;

  /// Exposes the internal monotonic id generator for tests.
  @visibleForTesting
  static int debugGenerateId() => _generateId();

  /// Exposes the internal stable-id derivation for tests.
  @visibleForTesting
  static int debugStableId(String? key) => _stableId(key);

  /// Creates an instance wired to injected plugins and registers it as the
  /// shared singleton, *without* running [initialize]. Test-only.
  @visibleForTesting
  static DefaultNotificationHandler createForTest({
    required AwesomeNotifications awesomeNotifications,
    FirebaseMessaging? firebaseMessaging,
    NotificationConfig? config,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    final handler = DefaultNotificationHandler._internal(
      awesomeNotifications: awesomeNotifications,
      firebaseMessaging: firebaseMessaging,
      onError: onError,
    );
    handler._config = config ?? NotificationConfig.defaultConfig();
    _instance = handler;
    return handler;
  }

  /// Resets the singleton. Test-only.
  @visibleForTesting
  static void resetInstance() {
    _logger.d('Resetting DefaultNotificationHandler singleton for testing.');
    _instance?._notificationDebouncer.cancel();
    _instance = null;
    _awesomeInitialized = false;
    _lastGeneratedId = 0;
  }

  /// Creates and initializes the shared instance. Call once at startup.
  static Future<DefaultNotificationHandler> initializeSharedInstance({
    NotificationConfig? config,
    FirebaseOptions? firebaseOptions,
    bool requestPermissionsOnInit = false,
    void Function(RemoteMessage)? onMessageOverride,
    void Function(RemoteMessage)? onMessageOpenedAppOverride,
    Future<void> Function(RemoteMessage)? onBackgroundMessageOverride,
    Future<void> Function(ReceivedNotification)? onNotificationCreatedOverride,
    Future<void> Function(ReceivedNotification)?
        onNotificationDisplayedOverride,
    Future<void> Function(ReceivedAction)? onNotificationDismissedOverride,
    Future<void> Function(ReceivedAction)? handleActionReceivedOverride,
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function(String name, Map<String, Object?> parameters)?
        onPermissionEvent,
  }) async {
    _instance ??= DefaultNotificationHandler._internal(
      onMessageOverride: onMessageOverride,
      onMessageOpenedAppOverride: onMessageOpenedAppOverride,
      onBackgroundMessageOverride:
          onBackgroundMessageOverride ?? smartDefaultBackgroundMessageHandler,
      onNotificationCreatedOverride: onNotificationCreatedOverride,
      onNotificationDisplayedOverride: onNotificationDisplayedOverride,
      onNotificationDismissedOverride: onNotificationDismissedOverride,
      handleActionReceivedOverride: handleActionReceivedOverride,
      onError: onError,
      onPermissionEvent: onPermissionEvent,
    );
    await _instance!.initialize(
      config: config,
      firebaseOptions: firebaseOptions,
      requestPermissionsOnInit: requestPermissionsOnInit,
    );
    return _instance!;
  }

  @override
  Future<void> initialize({
    NotificationConfig? config,
    FirebaseOptions? firebaseOptions,
    bool requestPermissionsOnInit = false,
  }) async {
    _logger.d('Initializing DefaultNotificationHandler...');
    _config = config ?? NotificationConfig.defaultConfig();

    // Idempotent re-init: drop any previously registered listeners first.
    await _clearSubscriptions();

    if (firebaseOptions != null) {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: firebaseOptions);
        _logger.d('Firebase initialized with provided options.');
      } else {
        _logger.d('Firebase already initialized.');
      }

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((message) {
          _logger.d('FCM onMessage: ${message.messageId}');
          onMessage(message);
          if (!_foregroundMessageController.isClosed) {
            _foregroundMessageController.add(message);
          }
        }),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _logger.d('FCM onMessageOpenedApp: ${message.messageId}');
          _debounceHandleNotification(message, _handleMessageOpened);
        }),
      );
      _subscriptions.add(
        _messaging.onTokenRefresh.listen((token) {
          _logger.i('FCM Token refreshed: $token');
          if (!_tokenRefreshController.isClosed) {
            _tokenRefreshController.add(token);
          }
        }),
      );
    } else {
      _logger.w('FirebaseOptions not provided. FCM features are disabled.');
    }

    await _setupNotificationChannels();
    await _startListeningAwesomeNotificationEvents();

    if (requestPermissionsOnInit) {
      await requestPermissions();
    }
    _logger.d('DefaultNotificationHandler initialized.');
  }

  void _handleMessageOpened(RemoteMessage message) {
    onMessageOpenedApp(message);
    if (!_messageOpenedController.isClosed) {
      _messageOpenedController.add(message);
    }
  }

  Future<void> _clearSubscriptions() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> _setupNotificationChannels() async {
    final config = _config ??= NotificationConfig.defaultConfig();
    _logger.d('Setting up channels. Main channel: ${config.channelKey}');

    final channels = <NotificationChannel>[
      // Honour the user's NotificationConfig instead of hardcoded defaults.
      config.toNotificationChannel(),
      if (config.channelKey != _fallbackBackgroundChannelKey)
        NotificationChannel(
          channelKey: _fallbackBackgroundChannelKey,
          channelName: 'Background Notifications',
          channelDescription:
              'Notifications processed when the app is in the background.',
          importance: NotificationImportance.Default,
          playSound: true,
          channelShowBadge: true,
        ),
      if (config.channelKey != _emergencyFallbackChannelKey &&
          _fallbackBackgroundChannelKey != _emergencyFallbackChannelKey)
        NotificationChannel(
          channelKey: _emergencyFallbackChannelKey,
          channelName: 'Emergency Notifications',
          channelDescription: 'Channel for critical fallback notifications.',
          importance: NotificationImportance.High,
          playSound: true,
          channelShowBadge: true,
        ),
    ];

    // De-duplicate by channel key.
    final unique = <String, NotificationChannel>{
      for (final channel in channels) channel.channelKey!: channel,
    };

    await _awesome.initialize(
      config.androidNotificationIcon,
      unique.values.toList(),
      debug: kDebugMode,
    );
    _awesomeInitialized = true;
    _logger.d('AwesomeNotifications channels configured.');
  }

  /// Ensures AwesomeNotifications is initialized in the current isolate.
  ///
  /// Critical for the terminated-state background path: the on-the-fly [I]
  /// instance never runs [initialize], so without this the background isolate
  /// would call `createNotification` on an uninitialized plugin and fail
  /// silently.
  Future<void> _ensureChannelsInitialized() async {
    if (_awesomeInitialized) return;
    await _setupNotificationChannels();
  }

  void _debounceHandleNotification(
    RemoteMessage message,
    void Function(RemoteMessage) handler,
  ) {
    _notificationDebouncer.run(() {
      if (_lastHandledMessageId != message.messageId ||
          message.messageId == null) {
        _lastHandledMessageId = message.messageId;
        handler(message);
      } else {
        _logger.d('Duplicate open event debounced: ${message.messageId}');
      }
    });
  }

  // ================== ID GENERATION ===================

  /// Returns a unique, positive 31-bit id, strictly increasing within a session
  /// and seeded from wall-clock time so ids rarely collide across restarts.
  static int _generateId() {
    var id = DateTime.now().millisecondsSinceEpoch.remainder(0x7FFFFFFF);
    if (id <= _lastGeneratedId) {
      id = _lastGeneratedId + 1;
    }
    if (id >= 0x7FFFFFFF) {
      id = 1;
    }
    _lastGeneratedId = id;
    return id;
  }

  /// Returns a stable, positive id derived from [key] so the same FCM message
  /// maps to the same notification (idempotent display). Falls back to a fresh
  /// id when [key] is null/empty.
  static int _stableId(String? key) {
    if (key == null || key.isEmpty) return _generateId();
    return key.hashCode & 0x7FFFFFFF;
  }

  // ================== COLD-START / DEEP LINK ===================

  @override
  Future<RemoteMessage?> getInitialMessage() async {
    try {
      return await _messaging.getInitialMessage();
    } catch (e, st) {
      _logger.e('Error reading initial FCM message: $e');
      onError?.call(e, st);
      return null;
    }
  }

  @override
  Future<ReceivedAction?> getInitialAction() async {
    try {
      return await _awesome.getInitialNotificationAction();
    } catch (e, st) {
      _logger.e('Error reading initial notification action: $e');
      onError?.call(e, st);
      return null;
    }
  }

  // ================== FCM TOKEN & TOPICS ===================

  @override
  Future<String?> getFcmToken() async {
    try {
      final token = await _messaging.getToken();
      _logger.d('FCM Token: $token');
      return token;
    } catch (e, st) {
      _logger.e('Error getting FCM token: $e');
      onError?.call(e, st);
      return null;
    }
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      _logger.d('Subscribed to topic: $topic');
    } catch (e, st) {
      _logger.e('Error subscribing to topic "$topic": $e');
      onError?.call(e, st);
    }
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      _logger.d('Unsubscribed from topic: $topic');
    } catch (e, st) {
      _logger.e('Error unsubscribing from topic "$topic": $e');
      onError?.call(e, st);
    }
  }

  // ================== DISPLAY ===================

  @override
  Future<int?> showNotification(RemoteMessage message) async {
    await _ensureChannelsInitialized();
    final config = _config ??= NotificationConfig.defaultConfig();
    final id = _stableId(message.messageId);
    final title =
        message.notification?.title ?? message.data['title'] ?? 'New Message';
    final body = message.notification?.body ??
        message.data['body'] ??
        'You have a new message.';
    try {
      await _awesome.createNotification(
        content: NotificationContent(
          id: id,
          channelKey: config.channelKey,
          title: title,
          body: body,
          payload: _convertPayload(message.data),
          color: config.defaultColor,
          icon: config.androidNotificationIcon,
          wakeUpScreen: config.wakeUpScreen,
          category: config.category,
        ),
      );
      _logger.d('Local notification created for FCM: ${message.messageId}');
      return id;
    } catch (e, st) {
      _logger.e('Error showing notification from FCM: $e');
      onError?.call(e, st);
      return null;
    }
  }

  Map<String, String?> _convertPayload(Map<String, dynamic> data) =>
      data.map((key, value) => MapEntry(key, value?.toString()));

  @override
  Future<int?> showRegularNotification({
    required String title,
    required String body,
    Map<String, String>? payload,
    String? channelKey,
  }) async {
    await _ensureChannelsInitialized();
    final config = _config ??= NotificationConfig.defaultConfig();
    final id = _generateId();
    _logger.d('Showing regular notification: "$title"');
    try {
      await _awesome.createNotification(
        content: NotificationContent(
          id: id,
          channelKey: channelKey ?? config.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: config.defaultColor,
          wakeUpScreen: config.wakeUpScreen,
          category: config.category,
        ),
      );
      return id;
    } catch (e, st) {
      _logger.e('Error showing regular notification: $e');
      onError?.call(e, st);
      return null;
    }
  }

  @override
  Future<int?> showActionNotification({
    required String title,
    required String body,
    List<NotificationActionButton>? buttons,
    Map<String, String>? payload,
    String? channelKey,
  }) async {
    await _ensureChannelsInitialized();
    final config = _config ??= NotificationConfig.defaultConfig();
    final id = _generateId();
    _logger.d('Showing action notification: "$title"');
    try {
      await _awesome.createNotification(
        content: NotificationContent(
          id: id,
          channelKey: channelKey ?? config.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: config.defaultColor,
          wakeUpScreen: config.wakeUpScreen,
          category: config.category ?? NotificationCategory.Social,
        ),
        actionButtons: buttons,
      );
      return id;
    } catch (e, st) {
      _logger.e('Error showing action notification: $e');
      onError?.call(e, st);
      return null;
    }
  }

  @override
  Future<int?> showReplyNotification({
    required String title,
    required String body,
    String? replyLabel,
    NotificationActionButton? replyButton,
    Map<String, String>? payload,
    String? channelKey,
  }) async {
    await _ensureChannelsInitialized();
    final config = _config ??= NotificationConfig.defaultConfig();
    final id = _generateId();
    _logger.d('Showing reply notification: "$title"');
    try {
      final actionButtons = <NotificationActionButton>[
        replyButton ??
            NotificationActionButton(
              key: 'REPLY_ACTION',
              label: replyLabel ?? 'Reply',
              requireInputText: true,
              actionType: ActionType.SilentBackgroundAction,
            ),
      ];
      await _awesome.createNotification(
        content: NotificationContent(
          id: id,
          channelKey: channelKey ?? config.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: config.defaultColor,
          wakeUpScreen: config.wakeUpScreen,
          notificationLayout: NotificationLayout.Messaging,
          category: config.category ?? NotificationCategory.Message,
        ),
        actionButtons: actionButtons,
      );
      return id;
    } catch (e, st) {
      _logger.e('Error showing reply notification: $e');
      onError?.call(e, st);
      return null;
    }
  }

  @override
  Future<int?> showBigPictureNotification({
    required String title,
    required String body,
    required String bigPicture,
    String? largeIcon,
    Map<String, String>? payload,
    String? channelKey,
  }) async {
    await _ensureChannelsInitialized();
    final config = _config ??= NotificationConfig.defaultConfig();
    final id = _generateId();
    _logger.d('Showing big-picture notification: "$title"');
    try {
      await _awesome.createNotification(
        content: NotificationContent(
          id: id,
          channelKey: channelKey ?? config.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: config.defaultColor,
          wakeUpScreen: config.wakeUpScreen,
          category: config.category,
          notificationLayout: NotificationLayout.BigPicture,
          bigPicture: bigPicture,
          largeIcon: largeIcon,
        ),
      );
      return id;
    } catch (e, st) {
      _logger.e('Error showing big-picture notification: $e');
      onError?.call(e, st);
      return null;
    }
  }

  @override
  Future<List<int>> showGroupedNotification(
    String groupKey,
    List<NotificationContent> messages,
  ) async {
    await _ensureChannelsInitialized();
    final config = _config ??= NotificationConfig.defaultConfig();
    _logger.d('Showing grouped notification (group: $groupKey)');
    final ids = <int>[];
    for (final messageContent in messages) {
      final id = messageContent.id ?? _generateId();
      try {
        await _awesome.createNotification(
          content: NotificationContent(
            id: id,
            channelKey: messageContent.channelKey ?? config.channelKey,
            title: messageContent.title,
            body: messageContent.body,
            summary: messageContent.summary,
            payload: messageContent.payload,
            groupKey: groupKey,
            notificationLayout:
                messageContent.notificationLayout ?? NotificationLayout.Default,
            category: messageContent.category ?? config.category,
            wakeUpScreen: messageContent.wakeUpScreen ?? config.wakeUpScreen,
            color: messageContent.color ?? config.defaultColor,
          ),
        );
        ids.add(id);
      } catch (e, st) {
        _logger.e('Error showing grouped notification $id: $e');
        onError?.call(e, st);
      }
    }
    return ids;
  }

  @override
  Future<int?> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    Map<String, String>? payload,
    String? channelKey,
  }) async {
    await _ensureChannelsInitialized();
    final config = _config ??= NotificationConfig.defaultConfig();
    _logger.d('Scheduling notification ID $id: "$title" for $scheduledDate');
    try {
      await _awesome.createNotification(
        schedule: NotificationCalendar.fromDate(
          date: scheduledDate,
          allowWhileIdle: true,
        ),
        content: NotificationContent(
          id: id,
          channelKey: channelKey ?? config.channelKey,
          title: title,
          body: body,
          payload: payload,
          color: config.defaultColor,
          wakeUpScreen: config.wakeUpScreen,
          category: config.category ?? NotificationCategory.Reminder,
        ),
      );
      return id;
    } catch (e, st) {
      _logger.e('Error scheduling notification: $e');
      onError?.call(e, st);
      return null;
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    _logger.d('Cancelling notification ID: $id');
    await _awesome.cancel(id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    _logger.d('Cancelling all notifications.');
    await _awesome.cancelAll();
  }

  @override
  Future<void> updateBadgeCount(int count) async {
    _logger.d('Updating badge count to: $count');
    await _awesome.setGlobalBadgeCounter(count);
  }

  @override
  Future<void> clearBadgeCount() async {
    _logger.d('Clearing badge count.');
    await _awesome.resetGlobalBadge();
  }

  @override
  Future<void> openNotificationSettings() async {
    _logger.d('Opening notification settings.');
    await _awesome.showNotificationConfigPage();
  }

  @override
  Future<int?> simulateNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? channelKey,
  }) async {
    _logger.d('Simulating notification: "$title"');
    return showRegularNotification(
      title: title,
      body: body,
      payload: data?.map((key, value) => MapEntry(key, value.toString())),
      channelKey: channelKey,
    );
  }

  @override
  void dispose() {
    _logger.d('Disposing DefaultNotificationHandler resources.');
    unawaited(_clearSubscriptions());
    if (_receivePort != null) {
      IsolateNameServer.removePortNameMapping(_portName);
      _receivePort!.close();
      _receivePort = null;
    }
    _notificationDebouncer.cancel();
    _permissionStatus.dispose();
    unawaited(_foregroundMessageController.close());
    unawaited(_messageOpenedController.close());
    unawaited(_actionController.close());
    unawaited(_tokenRefreshController.close());
  }

  // ================== PERMISSIONS ===================

  @override
  Future<AuthorizationStatus> requestPermissions() async {
    if (_permissionRequestLock) {
      _logger.w('Permission request already in progress.');
      return _permissionStatus.value;
    }
    _permissionRequestLock = true;
    _logger.i('Requesting notification permissions...');

    try {
      var settings = await _messaging.getNotificationSettings();
      _permissionStatus.value = settings.authorizationStatus;

      if (settings.authorizationStatus == AuthorizationStatus.notDetermined ||
          settings.authorizationStatus == AuthorizationStatus.denied) {
        settings = await _messaging.requestPermission();
        _permissionStatus.value = settings.authorizationStatus;
        onPermissionEvent?.call('notification_permission_fcm_request', {
          'status': settings.authorizationStatus.toString(),
        });
      }

      if (!await _awesome.isNotificationAllowed()) {
        final granted = await _awesome.requestPermissionToSendNotifications(
          channelKey: _config?.channelKey,
          permissions: const [
            NotificationPermission.Alert,
            NotificationPermission.Sound,
            NotificationPermission.Badge,
            NotificationPermission.Vibration,
          ],
        );
        onPermissionEvent?.call('notification_permission_awesome_request', {
          'granted': granted,
        });
        if (!granted &&
            _permissionStatus.value == AuthorizationStatus.authorized) {
          _logger.w('FCM authorized, but local notifications denied by user.');
        }
      }
    } catch (e, st) {
      _logger.e('Error requesting permissions: $e');
      onError?.call(e, st);
    } finally {
      _permissionRequestLock = false;
    }
    _logger.i('Final permission status: ${_permissionStatus.value}');
    return _permissionStatus.value;
  }

  @override
  Future<bool> isNotificationAllowed() => _awesome.isNotificationAllowed();

  // ================== AWESOME EVENT LISTENERS ===================

  Future<void> _startListeningAwesomeNotificationEvents() async {
    await _awesome.setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
      onNotificationCreatedMethod: _onNotificationCreatedMethod,
      onNotificationDisplayedMethod: _onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: _onNotificationDismissActionReceivedMethod,
    );
    await _initializeIsolateReceivePort();
  }

  @pragma('vm:entry-point')
  static Future<void> _onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    const logger = Logger('DefaultNotificationHandlerStatic');
    logger.d(
      'Action received - Key: ${receivedAction.buttonKeyPressed}, Type: ${receivedAction.actionType}',
    );

    final isSilent = receivedAction.actionType == ActionType.SilentAction ||
        receivedAction.actionType == ActionType.SilentBackgroundAction;

    // Forward non-silent actions to the main isolate for UI handling.
    if (!isSilent && _receivePort == null) {
      final sendPort = IsolateNameServer.lookupPortByName(_portName);
      if (sendPort != null) {
        sendPort.send(receivedAction);
        return;
      }
      logger.w('Main-isolate port not found; handling in current isolate.');
    }
    await _onActionReceivedImplementation(receivedAction);
  }

  static Future<void> _onActionReceivedImplementation(
    ReceivedAction receivedAction,
  ) async {
    final handler = DefaultNotificationHandler.I;
    if (!handler._actionController.isClosed) {
      handler._actionController.add(receivedAction);
    }
    await handler.handleActionReceived(receivedAction);
  }

  static Future<void> _initializeIsolateReceivePort() async {
    if (_receivePort != null) return;
    _receivePort = ReceivePort('NotificationActionPort_MainIsolate')
      ..listen((data) {
        if (data is ReceivedAction) {
          _onActionReceivedImplementation(data);
        }
      });
    IsolateNameServer.registerPortWithName(_receivePort!.sendPort, _portName);
    _logger.d('Isolate ReceivePort initialized and registered.');
  }

  @pragma('vm:entry-point')
  static Future<void> _onNotificationCreatedMethod(
    ReceivedNotification receivedNotification,
  ) =>
      DefaultNotificationHandler.I.onNotificationCreated(receivedNotification);

  @pragma('vm:entry-point')
  static Future<void> _onNotificationDisplayedMethod(
    ReceivedNotification receivedNotification,
  ) =>
      DefaultNotificationHandler.I
          .onNotificationDisplayed(receivedNotification);

  @pragma('vm:entry-point')
  static Future<void> _onNotificationDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) =>
      DefaultNotificationHandler.I.onNotificationDismissed(receivedAction);

  // ================== FIREBASE BACKGROUND HANDLER ===================

  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
  ) async {
    const logger = Logger('DefaultNotificationHandlerStatic');
    logger.d('Firebase BACKGROUND message: ${message.messageId}');

    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp();
      } catch (e) {
        logger.e('Error initializing Firebase in background isolate: $e');
        return;
      }
    }
    await DefaultNotificationHandler.I.onBackgroundMessage(message);
  }

  /// Default background handler. Always displays via AwesomeNotifications for
  /// consistent behavior across Android versions, especially Android 13+
  /// (API 33+) where FCM auto-display requires POST_NOTIFICATIONS and silently
  /// fails without it.
  ///
  /// To avoid duplicate notifications on Android < 13, send data-only messages
  /// from your server (omit the `notification` field).
  @pragma('vm:entry-point')
  static Future<void> smartDefaultBackgroundMessageHandler(
    RemoteMessage message,
  ) async {
    const Logger('DefaultNotificationHandler')
        .d('[SmartBackgroundHandler] Processing: ${message.messageId}');
    await DefaultNotificationHandler.I.showNotification(message);
  }
}
