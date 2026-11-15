import 'dart:ui' show FrameTiming;

import 'package:local_dynamic_notifications/local_dynamic_notifications.dart';
import 'package:dynamic_notifications_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows a safe-area card, accepts outside taps and dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();

    final frames = <FrameTiming>[];
    void recordTimings(List<FrameTiming> batch) => frames.addAll(batch);
    WidgetsBinding.instance.addTimingsCallback(recordTimings);
    addTearDown(
      () => WidgetsBinding.instance.removeTimingsCallback(recordTimings),
    );

    await tester.tap(find.byTooltip('Show persistent notification'));
    await tester.pumpAndSettle();
    final persistent = find.text('Uploading files');
    expect(persistent.hitTestable(), findsOneWidget);

    final host = tester.element(find.byType(DynamicNotifications));
    final safeTop = MediaQuery.viewPaddingOf(host).top;
    expect(
      tester.getTopLeft(persistent).dy - safeTop,
      inInclusiveRange(26, 54),
    );

    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    expect(find.text('Drop origin lift · 0 pt'), findsOneWidget);
    Navigator.of(tester.element(find.byType(Slider))).pop();
    await tester.pumpAndSettle();
    expect(persistent.hitTestable(), findsOneWidget);
    await tester.fling(persistent, const Offset(0, -60), 800);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Show notification (2s)'));
    await tester.pumpAndSettle();
    final message = find.text('New message');
    expect(persistent, findsNothing);
    expect(message.hitTestable(), findsOneWidget);
    await tester.tap(message);
    await tester.pumpAndSettle();
    expect(find.text('Message opened'), findsOneWidget);
    expect(message, findsNothing);

    await tester.tap(find.byTooltip('Show persistent notification'));
    await tester.pumpAndSettle();
    await tester.fling(persistent, const Offset(0, -60), 800);
    await tester.pumpAndSettle();
    expect(persistent, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    if (frames.isNotEmpty) {
      final build =
          frames.map((frame) => frame.buildDuration.inMicroseconds).toList()
            ..sort();
      final raster =
          frames.map((frame) => frame.rasterDuration.inMicroseconds).toList()
            ..sort();
      final index = ((frames.length - 1) * 0.95).round();
      debugPrint(
        'Notification frame sample: ${frames.length} frames, '
        'build p95 ${build[index] / 1000}ms, '
        'raster p95 ${raster[index] / 1000}ms',
      );
    }
  });
}
