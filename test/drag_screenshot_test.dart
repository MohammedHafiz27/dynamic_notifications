import 'dart:io';
import 'dart:ui' as ui;

import 'package:local_dynamic_notifications/local_dynamic_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture visual evidence for interactive downward drag states', (
    tester,
  ) async {
    const testSize = Size(412, 915);
    tester.view.physicalSize = const Size(824, 1830);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final outDir = Directory('doc/screenshots/drag');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    Future<void> saveScreenshot(GlobalKey repaintKey, String filename) async {
      final boundary =
          repaintKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final ui.Image image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: 2.0),
      ) as ui.Image;
      final byteData = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      final file = File('doc/screenshots/drag/$filename');
      file.writeAsBytesSync(byteData!.buffer.asUint8List());
    }

    // --- Scenario 1: Drag displacements (Initial, Partial 25, Medium 60, Max 120) ---
    final repaintKey = GlobalKey();
    final controller = DynamicNotificationController();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF18181B),
          body: RepaintBoundary(
            key: repaintKey,
            child: SizedBox(
              width: testSize.width,
              height: testSize.height,
              child: DynamicNotifications(
                controller: controller,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

    var opened = false;
    controller.show(
      DynamicNotification(
        title: 'Downward Drag Audit',
        message: 'White background must persist at all drag offsets',
        duration: null,
        onTap: () => opened = true,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // 1. Initial resting state
    await saveScreenshot(repaintKey, 'drag_0_initial.png');

    // 2. Partial downward drag: 25px
    final textFinder = find.text('Downward Drag Audit');
    final textCenter = tester.getCenter(textFinder);
    final gesture = await tester.startGesture(textCenter);
    await gesture.moveBy(const Offset(0, 25));
    await tester.pump();
    expect(controller.dragOffset, 25.0);
    await saveScreenshot(repaintKey, 'drag_25_partial.png');

    // 3. Medium downward drag: 60px (> openThreshold 44px)
    await gesture.moveBy(const Offset(0, 35));
    await tester.pump();
    expect(controller.dragOffset, 60.0);
    await saveScreenshot(repaintKey, 'drag_60_medium.png');

    // 4. Maximum downward drag: 120px (clamped to maxDownwardDrag)
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    expect(controller.dragOffset, 120.0);
    await saveScreenshot(repaintKey, 'drag_120_max.png');

    // 5. Drag release that triggers opening
    await gesture.up();
    expect(opened, isTrue);
    expect(controller.interactionState, NotificationInteractionState.opening);
    // Pump into opening reverse transition
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await saveScreenshot(repaintKey, 'drag_release_opening.png');
    await tester.pumpAndSettle();

    // --- Scenario 2: Interrupted drag & Pointer cancellation ---
    final repaintKey2 = GlobalKey();
    final controller2 = DynamicNotificationController();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF18181B),
          body: RepaintBoundary(
            key: repaintKey2,
            child: SizedBox(
              width: testSize.width,
              height: testSize.height,
              child: DynamicNotifications(
                controller: controller2,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

    controller2.show(
      const DynamicNotification(
        title: 'Interruption & Cancel',
        message: 'Verifying spring-back and cancellation',
        duration: null,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // Drag downward 50px
    final gesture2 = await tester.startGesture(
      tester.getCenter(find.text('Interruption & Cancel')),
    );
    await gesture2.moveBy(const Offset(0, 50));
    await tester.pump();

    // 6. Pointer cancellation
    await gesture2.cancel();
    await tester.pump();
    expect(
      controller2.interactionState,
      NotificationInteractionState.returning,
    );
    await saveScreenshot(repaintKey2, 'drag_cancelled.png');

    // Let it spring back partially (80ms) and touch down to interrupt
    await tester.pump(const Duration(milliseconds: 80));
    final gesture3 = await tester.startGesture(
      tester.getCenter(find.text('Interruption & Cancel')),
    );
    await tester.pump();
    expect(controller2.interactionState, NotificationInteractionState.holding);

    // 7. Interrupted drag holding
    await saveScreenshot(repaintKey2, 'drag_interrupted.png');

    await gesture3.up();
    await tester.pumpAndSettle();

    // Verify all 7 screenshots exist and are valid PNGs (> 2KB)
    final expectedFiles = [
      'drag_0_initial.png',
      'drag_25_partial.png',
      'drag_60_medium.png',
      'drag_120_max.png',
      'drag_release_opening.png',
      'drag_cancelled.png',
      'drag_interrupted.png',
    ];
    for (final f in expectedFiles) {
      final file = File('doc/screenshots/drag/$f');
      expect(file.existsSync(), isTrue, reason: '$f must exist');
      expect(
        file.lengthSync(),
        greaterThan(2000),
        reason: '$f must be a non-empty image',
      );
    }
  });
}
