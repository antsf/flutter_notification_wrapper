// End-to-end smoke test for the example app.
//
// Run on a device/emulator (it touches real platform channels):
//   cd example && flutter test integration_test
//
// It proves the full call path (init → channel setup → createNotification)
// runs without crashing on a real device. It does NOT (and cannot, without a
// push server) assert terminated-state FCM delivery — see VERIFICATION.md for
// the manual procedure for that case.
import 'package:flutter_notification_wrapper_example/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows a local notification end-to-end', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(find.text('Show regular'), findsOneWidget);

    await tester.tap(find.text('Show regular'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Shown regular notification id='),
      findsOneWidget,
    );
  });
}
