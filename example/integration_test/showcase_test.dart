import 'package:dynamic_notifications_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Showcase notification emergence, settlement, and dismissal', (tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();

    // 1. Initial settled state
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));

    // 2. Trigger notification
    final bell = find.byTooltip('Show notification (2s)');
    expect(bell, findsOneWidget);
    await tester.tap(bell);

    // 3. Allow animation to play and settle (entrance is ~650ms, timer is 2000ms)
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2000)));
    await tester.pumpAndSettle();

    final message = find.text('New message');
    expect(message.hitTestable(), findsOneWidget);

    // 4. Smooth upward fling to dismiss
    await tester.fling(message, const Offset(0, -65), 850);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 900)));
    await tester.pumpAndSettle();

    expect(find.text('New message'), findsNothing);
  });
}
