import 'dart:io';
import 'dart:ui' as ui;

import 'package:dynamic_notifications/dynamic_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture reproducible baseline screenshots for verified renderer', (
    tester,
  ) async {
    final progressSteps = [0.0, 0.05, 0.10, 0.15, 0.20, 0.30, 0.50, 0.75, 1.0];

    // Android Pixel 7a hardware profile: 412 x 915 logical dp, DPR = 2.625
    const testSize = Size(412, 915);
    tester.view.physicalSize = Size(testSize.width * 2.625, testSize.height * 2.625);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Centered punch hole cutout at top of screen:
    // Left: 193.1, Top: 12.6, Right: 218.3, Bottom: 37.7 (Width: 25.14, Height: 25.14)
    const cutoutBounds = Rect.fromLTRB(193.1, 12.6, 218.3, 37.7);
    const testGeometry = NotchGeometry(
      bounds: cutoutBounds,
      center: Offset(205.7, 25.14),
      width: 25.14,
      height: 25.14,
      top: 12.6,
      bottom: 37.7,
      screenSize: testSize,
      insets: EdgeInsets.only(top: 45.0),
      source: NotchGeometrySource.nativePath,
      confidence: NotchGeometryConfidence.exact,
      shape: NotchShape.punchHole,
      hasCutout: true,
      devicePixelRatio: 2.625,
    );

    for (final p in progressSteps) {
      final repaintKey = GlobalKey();
      final controller = DynamicNotificationController();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: RepaintBoundary(
              key: repaintKey,
              child: SizedBox(
                width: testSize.width,
                height: testSize.height,
                child: Stack(
                  children: [
                    // Simulated app content
                    Container(
                      color: const Color(0xFFF8F9FA),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE9232E),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'MediaFeed',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.search, size: 22),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Container(
                                    height: 180,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E0E0),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.video_library, size: 48, color: Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Exploring Japanese Alps in Autumn',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '184K views · 3 days ago',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Hardware camera cutout representation (black circle on screen)
                    Positioned(
                      left: cutoutBounds.left,
                      top: cutoutBounds.top,
                      width: cutoutBounds.width,
                      height: cutoutBounds.height,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    // Dynamic Notification with verified renderer at progress p
                    Positioned.fill(
                      child: DynamicNotifications(
                        controller: controller,
                        geometryOverride: testGeometry,
                        progressOverride: p,
                        renderMode: NotificationRenderMode.standard,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Render RepaintBoundary to PNG image
      final boundary = repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2.0)) as ui.Image;
      final byteData = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      final pngBytes = byteData!.buffer.asUint8List();

      final percent = (p * 100).round();
      final file = File('doc/screenshots/baseline/progress_$percent.png');
      file.writeAsBytesSync(pngBytes);
    }

    // Verify all 6 screenshot files were created and are non-empty
    for (final p in progressSteps) {
      final percent = (p * 100).round();
      final file = File('doc/screenshots/baseline/progress_$percent.png');
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    }

    // Now capture experimental liquid renderer screenshots for A/B comparison
    for (final p in progressSteps) {
      final repaintKey = GlobalKey();
      final controller = DynamicNotificationController();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: RepaintBoundary(
              key: repaintKey,
              child: SizedBox(
                width: testSize.width,
                height: testSize.height,
                child: Stack(
                  children: [
                    // Simulated app content
                    Container(
                      color: const Color(0xFFF8F9FA),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE9232E),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'MediaFeed',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.search, size: 22),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  Container(
                                    height: 180,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E0E0),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.video_library, size: 48, color: Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Exploring Japanese Alps in Autumn',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '184K views · 3 days ago',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Hardware camera cutout representation
                    Positioned(
                      left: cutoutBounds.left,
                      top: cutoutBounds.top,
                      width: cutoutBounds.width,
                      height: cutoutBounds.height,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    // Dynamic Notification with experimental liquid renderer at progress p
                    Positioned.fill(
                      child: DynamicNotifications(
                        controller: controller,
                        geometryOverride: testGeometry,
                        progressOverride: p,
                        renderMode: NotificationRenderMode.experimentalLiquid,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final boundary = repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2.0)) as ui.Image;
      final byteData = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
      final pngBytes = byteData!.buffer.asUint8List();

      final percent = (p * 100).round();
      final file = File('doc/screenshots/experimental/progress_$percent.png');
      file.writeAsBytesSync(pngBytes);
    }

    for (final p in progressSteps) {
      final percent = (p * 100).round();
      final file = File('doc/screenshots/experimental/progress_$percent.png');
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(1000));
    }
  });
}
