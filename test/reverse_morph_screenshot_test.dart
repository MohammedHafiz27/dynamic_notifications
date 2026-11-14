import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:dynamic_notifications/dynamic_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture visual evidence for interactive reverse morph into notch', (
    tester,
  ) async {
    const testSize = Size(412, 915);
    tester.view.physicalSize = const Size(824, 1830);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final outDir = Directory('doc/screenshots/morph');
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
      final file = File('doc/screenshots/morph/$filename');
      file.writeAsBytesSync(byteData!.buffer.asUint8List());
    }

    final repaintKey = GlobalKey();
    final controller = DynamicNotificationController();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9), // Light background for clear contrast
          body: RepaintBoundary(
            key: repaintKey,
            child: MediaQuery(
              data: const MediaQueryData(
                viewPadding: EdgeInsets.only(top: 44, bottom: 20),
                displayFeatures: [
                  DisplayFeature(
                    bounds: Rect.fromLTWH(194, 10, 24, 24),
                    type: DisplayFeatureType.cutout,
                    state: DisplayFeatureState.unknown,
                  ),
                ],
              ),
              child: SizedBox(
                width: testSize.width,
                height: testSize.height,
                child: DynamicNotifications(
                  controller: controller,
                  child: Stack(
                    children: [
                      // Simulated phone top bar & camera lens
                      Positioned(
                        top: 10,
                        left: 194,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 20,
                        child: Text(
                          '9:41',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    controller.show(
      const DynamicNotification(
        title: 'New Message',
        message: 'Maya: Check out the new design system',
        duration: null,
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // 1. Progress 0.0 - Fully Expanded Resting State
    await saveScreenshot(repaintKey, 'morph_0_expanded.png');

    // 2. Progress 0.25 - Small upward drag (-20dp)
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('New Message')),
    );
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await saveScreenshot(repaintKey, 'morph_25_contracting.png');

    // 3. Progress 0.50 - Medium upward drag (-40dp, content fully faded, pill shape)
    await gesture.moveBy(const Offset(0, -20)); // total -40
    await tester.pump();
    await saveScreenshot(repaintKey, 'morph_50_pill.png');

    // 4. Progress 0.75 - Near-complete upward drag (-60dp, liquid suction neck into cutout)
    await gesture.moveBy(const Offset(0, -20)); // total -60
    await tester.pump();
    await saveScreenshot(repaintKey, 'morph_75_bridge.png');

    // 5. Progress 1.00 - Maximum upward drag (-80dp, absorbed into camera aperture)
    await gesture.moveBy(const Offset(0, -20)); // total -80
    await tester.pump();
    await saveScreenshot(repaintKey, 'morph_100_absorbed.png');

    // 6. Direction reversal test: drag back down to 0dp and verify recovery
    await gesture.moveBy(const Offset(0, 80)); // back to 0
    await tester.pump();
    await saveScreenshot(repaintKey, 'morph_reversal_recovery.png');

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
