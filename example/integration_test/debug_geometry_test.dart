import 'package:dynamic_notifications_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Debug Geometry Mode activates, displays diagnostic HUD, and runs benchmark', (
    tester,
  ) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();

    // 1. Initially debug mode is disabled
    expect(find.text('GEOMETRY DIAGNOSTIC HUD'), findsNothing);

    // 2. Tap debug mode button in AppBar
    final debugBtn = find.byTooltip('Toggle Debug Geometry Mode');
    expect(debugBtn, findsOneWidget);
    await tester.tap(debugBtn);
    await tester.pumpAndSettle();

    // 3. Verify Debug HUD is displayed on screen
    expect(find.text('GEOMETRY DIAGNOSTIC HUD'), findsOneWidget);
    expect(find.textContaining('Device'), findsWidgets);
    expect(find.textContaining('API / Target SDK'), findsWidgets);
    expect(find.textContaining('Window Size'), findsWidgets);
    expect(find.textContaining('FlutterView Phys'), findsWidgets);
    expect(find.textContaining('Padding / viewPad'), findsWidgets);
    expect(find.textContaining('Display Features'), findsWidgets);
    expect(find.textContaining('Shape / Source'), findsWidgets);
    expect(find.textContaining('Anchor (X, Top)'), findsWidgets);
    expect(find.textContaining('Top Boundary Y'), findsWidgets);
    expect(find.textContaining('Contact Neck W'), findsWidgets);

    // 4. Test benchmark button
    final benchmarkBtn = find.byIcon(Icons.speed);
    expect(benchmarkBtn, findsOneWidget);
    await tester.tap(benchmarkBtn);
    await tester.pumpAndSettle();

    // 5. Test switching geometry source
    final toggleSourceBtn = find.textContaining('Source:');
    expect(toggleSourceBtn, findsOneWidget);
    await tester.tap(toggleSourceBtn);
    await tester.pumpAndSettle();

    // 6. Trigger notification drop while in debug mode
    final triggerBtn = find.byIcon(Icons.play_arrow);
    expect(triggerBtn, findsOneWidget);
    await tester.tap(triggerBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    // Verify visual guides painted without throwing
    expect(find.byKey(const ValueKey('dynamic-notification-shape')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
  });
}
