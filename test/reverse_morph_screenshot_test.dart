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
                size: testSize,
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

  testWidgets('Capture visual evidence for interactive reverse morph into Dynamic Island', (
    tester,
  ) async {
    const testSize = Size(393, 852);
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final outDir = Directory('doc/screenshots/morph/island');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    Future<void> saveScreenshot(GlobalKey repaintKey, String filename) async {
      final boundary =
          repaintKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final ui.Image image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: 3.0),
      ) as ui.Image;
      final byteData = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      final file = File('doc/screenshots/morph/island/$filename');
      file.writeAsBytesSync(byteData!.buffer.asUint8List());
    }

    final repaintKey = GlobalKey();
    final controller = DynamicNotificationController();

    const cutoutBounds = Rect.fromLTWH(134.5, 11.0, 124.0, 37.0);
    const testGeometry = NotchGeometry(
      bounds: cutoutBounds,
      center: Offset(196.5, 29.5),
      width: 124.0,
      height: 37.0,
      top: 11.0,
      bottom: 48.0,
      screenSize: testSize,
      insets: EdgeInsets.only(top: 54.0),
      source: NotchGeometrySource.displayFeature,
      confidence: NotchGeometryConfidence.exact,
      shape: NotchShape.pill,
      hasCutout: true,
      devicePixelRatio: 3.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: RepaintBoundary(
            key: repaintKey,
            child: MediaQuery(
              data: const MediaQueryData(
                size: testSize,
                viewPadding: EdgeInsets.only(top: 54, bottom: 34),
                displayFeatures: [
                  DisplayFeature(
                    bounds: cutoutBounds,
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
                  geometryOverride: testGeometry,
                  child: Stack(
                    children: [
                      // Simulated Dynamic Island hardware pill
                      Positioned(
                        top: 11,
                        left: 134.5,
                        child: Container(
                          width: 124,
                          height: 37,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(18.5),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 28,
                        child: Text(
                          '9:41',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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
        title: 'Incoming Call',
        message: 'Sarah Jenkins is calling...',
        duration: null,
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // 1. Progress 0.0 - Fully Expanded Resting State
    await saveScreenshot(repaintKey, 'island_0_expanded.png');

    // 2. Progress 0.25 - Small upward drag (-20dp)
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Incoming Call')),
    );
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await saveScreenshot(repaintKey, 'island_25_contracting.png');

    // 3. Progress 0.50 - Medium upward drag (-40dp, pendant liquid droplet)
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await saveScreenshot(repaintKey, 'island_50_droplet.png');

    // 4. Progress 0.75 - Near-complete upward drag (-60dp, liquid neck retraction)
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await saveScreenshot(repaintKey, 'island_75_neck.png');

    // 5. Progress 1.00 - Maximum upward drag (-80dp, fully absorbed into Dynamic Island)
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await saveScreenshot(repaintKey, 'island_100_absorbed.png');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Capture visual evidence for horizontal left-side cutout liquid morph', (
    tester,
  ) async {
    const testSize = Size(892, 412);
    tester.view.physicalSize = const Size(1784, 824);
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

    const leftGeometry = NotchGeometry(
      bounds: Rect.fromLTWH(12, 194, 24, 24),
      center: Offset(24, 206),
      width: 24,
      height: 24,
      top: 194,
      bottom: 218,
      screenSize: testSize,
      insets: EdgeInsets.only(left: 48),
      source: NotchGeometrySource.displayFeature,
      confidence: NotchGeometryConfidence.exact,
      shape: NotchShape.punchHole,
      hasCutout: true,
      edge: CutoutEdge.left,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: RepaintBoundary(
            key: repaintKey,
            child: MediaQuery(
              data: const MediaQueryData(
                size: testSize,
                viewPadding: EdgeInsets.only(left: 48),
                displayFeatures: [
                  DisplayFeature(
                    bounds: Rect.fromLTWH(12, 194, 24, 24),
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
                  geometryOverride: leftGeometry,
                  child: Stack(
                    children: [
                      // Simulated phone side bezel & camera lens
                      Positioned(
                        top: 194,
                        left: 12,
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
                        left: 56,
                        child: Text(
                          '9:41 AM - Landscape',
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
        title: 'Package Delivered',
        message: 'Your order was placed at front door',
        duration: null,
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // 1. Progress 0.0 - Fully Expanded Resting Card (Centered horizontally, upright)
    await saveScreenshot(repaintKey, 'side_left_0_expanded.png');

    // 2. Progress 0.25 - Leftward drag -20dp
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Package Delivered')),
    );
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await saveScreenshot(repaintKey, 'side_left_25_contracting.png');

    // 3. Progress 0.50 - Leftward drag -40dp (horizontal airborne droplet migrating to left cutout)
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await saveScreenshot(repaintKey, 'side_left_50_droplet.png');

    // 4. Progress 0.75 - Leftward drag -60dp (neck attaches to left cutout)
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await saveScreenshot(repaintKey, 'side_left_75_neck.png');

    // 5. Progress 1.00 - Leftward drag -80dp (absorbed into left camera cutout)
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await saveScreenshot(repaintKey, 'side_left_100_absorbed.png');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Capture visual evidence for horizontal right-side cutout liquid morph', (
    tester,
  ) async {
    const testSize = Size(892, 412);
    tester.view.physicalSize = const Size(1784, 824);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    const rightGeometry = NotchGeometry(
      bounds: Rect.fromLTWH(856, 194, 24, 24),
      center: Offset(868, 206),
      width: 24,
      height: 24,
      top: 194,
      bottom: 218,
      screenSize: testSize,
      insets: EdgeInsets.only(right: 48),
      source: NotchGeometrySource.displayFeature,
      confidence: NotchGeometryConfidence.exact,
      shape: NotchShape.punchHole,
      hasCutout: true,
      edge: CutoutEdge.right,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: RepaintBoundary(
            key: repaintKey,
            child: MediaQuery(
              data: const MediaQueryData(
                size: testSize,
                viewPadding: EdgeInsets.only(right: 48),
                displayFeatures: [
                  DisplayFeature(
                    bounds: Rect.fromLTWH(856, 194, 24, 24),
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
                  geometryOverride: rightGeometry,
                  child: Stack(
                    children: [
                      // Simulated phone right bezel & camera lens
                      Positioned(
                        top: 194,
                        right: 12,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
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
        title: 'Meeting in 5 min',
        message: 'Product Review sync',
        duration: null,
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // 1. Progress 0.0 - Fully Expanded
    await saveScreenshot(repaintKey, 'side_right_0_expanded.png');

    // 2. Progress 0.25 - Rightward drag +20dp
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Meeting in 5 min')),
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await saveScreenshot(repaintKey, 'side_right_25_contracting.png');

    // 3. Progress 0.50 - Rightward drag +40dp
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await saveScreenshot(repaintKey, 'side_right_50_droplet.png');

    // 4. Progress 0.75 - Rightward drag +60dp (neck attached to right cutout)
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await saveScreenshot(repaintKey, 'side_right_75_neck.png');

    // 5. Progress 1.00 - Rightward drag +80dp (absorbed into right cutout)
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await saveScreenshot(repaintKey, 'side_right_100_absorbed.png');

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
