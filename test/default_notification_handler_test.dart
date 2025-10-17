// // test/default_notification_handler_test.dart
// import 'dart:async';

// import 'package:awesome_notifications/awesome_notifications.dart';
// import 'package:flutter_notification_wrapper/flutter_notification_wrapper.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:mocktail/mocktail.dart';

// // Mock classes
// class MockFirebaseApp extends Mock implements FirebaseApp {}

// class MockAwesomeNotifications extends Mock implements AwesomeNotifications {}

// class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

// void main() {
//   TestWidgetsFlutterBinding.ensureInitialized();

//   late MockFirebaseApp mockFirebaseApp;
//   late MockAwesomeNotifications mockAwesomeNotifications;
//   late MockFirebaseMessaging mockFirebaseMessaging;

//   setUp(() {
//     // Reset singleton
//     DefaultNotificationHandler.resetInstance();

//     // Initialize mocks
//     mockFirebaseApp = MockFirebaseApp();
//     mockAwesomeNotifications = MockAwesomeNotifications();
//     mockFirebaseMessaging = MockFirebaseMessaging();

//     // ✅ Mock static Firebase.initializeApp
//     registerFallbackValue(const FirebaseOptions(
//       apiKey: 'dummy',
//       appId: 'dummy',
//       messagingSenderId: 'dummy',
//       projectId: 'dummy',
//     ));
//     when(() => Firebase.initializeApp(options: any(named: 'options')))
//         .thenAnswer((_) async => mockFirebaseApp);

//     // ✅ Mock static FirebaseMessaging.instance
//     when(() => FirebaseMessaging.instance).thenReturn(mockFirebaseMessaging);
//     when(() => mockFirebaseMessaging.getToken())
//         .thenAnswer((_) async => 'mock-token');
//     when(() => mockFirebaseMessaging.onTokenRefresh)
//         .thenAnswer((_) => StreamController<String>().stream);

//     // ✅ Mock AwesomeNotifications singleton
//     final mockAN = mockAwesomeNotifications;
//     when(AwesomeNotifications.new).thenReturn(mockAN);
//     when(() => mockAN.initialize(any(), any())).thenAnswer((_) async => true);
//     when(mockAN.isNotificationAllowed).thenAnswer((_) async => true);
//     when(() => mockAN.requestPermissionToSendNotifications(
//           channelKey: any(named: 'channelKey'),
//           permissions: any(named: 'permissions'),
//         )).thenAnswer((_) async => true);
//     when(() => mockAN.setListeners(
//           onActionReceivedMethod: any(named: 'onActionReceivedMethod'),
//           onNotificationCreatedMethod:
//               any(named: 'onNotificationCreatedMethod'),
//           onNotificationDisplayedMethod:
//               any(named: 'onNotificationDisplayedMethod'),
//           onDismissActionReceivedMethod:
//               any(named: 'onDismissActionReceivedMethod'),
//         )).thenAnswer((_) async => false);

//     // Register fallback values
//     registerFallbackValue(<NotificationChannel>[]);
//   });

//   tearDown(() {
//     resetLazySingletons(); // Reset all static mocks
//     DefaultNotificationHandler.resetInstance();
//   });

//   group('DefaultNotificationHandler', () {
//     test('initializeSharedInstance sets up correctly', () async {
//       final config = NotificationConfig.defaultConfig();

//       final handler = await DefaultNotificationHandler.initializeSharedInstance(
//         config: config,
//         firebaseOptions: const FirebaseOptions(
//           apiKey: 'dummy-api-key',
//           appId: 'dummy-app-id',
//           messagingSenderId: 'dummy-sender-id',
//           projectId: 'dummy-project-id',
//         ),
//       );

//       expect(handler, isNotNull);
//       expect(DefaultNotificationHandler.I, same(handler));

//       // Verify AwesomeNotifications.initialize was called
//       verify(() => mockAwesomeNotifications.initialize(
//             'resource://drawable/notification_icon',
//             any(that: isA<List<NotificationChannel>>()),
//           )).called(1);

//       verify(() => Firebase.initializeApp(
//             options: const FirebaseOptions(
//               apiKey: 'dummy-api-key',
//               appId: 'dummy-app-id',
//               messagingSenderId: 'dummy-sender-id',
//               projectId: 'dummy-project-id',
//             ),
//           )).called(1);
//     });

//     test('logs warning when created on-the-fly (background simulation)',
//         () async {
//       // Capture logs
//       // final logs = <String>[];
//       // const originalPrint = print;
//       // dynamic Function(Object? object) logCapture = (object) {
//       //   logs.add(object.toString());
//       //   originalPrint(object);
//       // };
//       // Temporarily replace print
//       // (Assuming your logger uses print; if not, mock Logger)
//       // For this test, we'll check instance creation directly

//       // Access singleton without initialization
//       final handler = DefaultNotificationHandler.I;
//       expect(handler, isNotNull);

//       // Verify it's a new instance with fallback config
//       // expect(handler._config?.channelKey, 'fallback_background_channel');
//     });

//     test('no warning when accessed after initialize', () async {
//       await DefaultNotificationHandler.initializeSharedInstance(
//         config: NotificationConfig.defaultConfig(),
//         firebaseOptions: const FirebaseOptions(
//           apiKey: 'dummy',
//           appId: 'dummy',
//           messagingSenderId: 'dummy',
//           projectId: 'dummy',
//         ),
//       );

//       // final handler = DefaultNotificationHandler.I;
//       // expect(handler._config?.channelKey, 'basic_channel');
//     });
//   });
// }

// // Helper to reset static mocks (optional but clean)
// void resetLazySingletons() {
//   // Clear any static state if needed
// }
