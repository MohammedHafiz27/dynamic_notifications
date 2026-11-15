import 'dart:io';
import 'dart:ui' as ui;

import 'package:dynamic_notifications/dynamic_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Capture reproducible baseline screenshots for verified renderer',
    (tester) async {
      final progressSteps = [
        0.0,
        0.05,
        0.10,
        0.15,
        0.20,
        0.30,
        0.50,
        0.75,
        1.0,
      ];

      // Android Pixel 7a hardware profile: 412 x 915 logical dp, DPR = 2.625
      const testSize = Size(412, 915);
      tester.view.physicalSize = Size(
        testSize.width * 2.625,
        testSize.height * 2.625,
      );
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE9232E),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'MediaFeed',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
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
                                        child: Icon(
                                          Icons.video_library,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Exploring Japanese Alps in Autumn',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '184K views · 3 days ago',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
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
        final boundary =
            repaintKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final ui.Image image = await tester.runAsync(
          () => boundary.toImage(pixelRatio: 2.0),
        ) as ui.Image;
        final byteData = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        );
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
    },
  );

  testWidgets('Capture reproducible baseline screenshots for Dynamic Island', (
    tester,
  ) async {
    final progressSteps = [0.0, 0.06, 0.12, 0.18, 0.24, 0.30, 0.44, 0.65, 1.0];

    // iPhone 15 Pro hardware profile: 393 x 852 logical dp, DPR = 3.0
    const testSize = Size(393, 852);
    tester.view.physicalSize = Size(
      testSize.width * 3.0,
      testSize.height * 3.0,
    );
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Centered pill cutout at top of screen:
    // Left: 134.5, Top: 11.0, Width: 124.0, Height: 37.0
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

    final islandDir = Directory('doc/screenshots/island');
    if (!islandDir.existsSync()) {
      islandDir.createSync(recursive: true);
    }

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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE9232E),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'MediaFeed',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
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
                                      child: Icon(
                                        Icons.video_library,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Hardware Dynamic Island representation
                    Positioned(
                      left: cutoutBounds.left,
                      top: cutoutBounds.top,
                      width: cutoutBounds.width,
                      height: cutoutBounds.height,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(
                            cutoutBounds.height / 2,
                          ),
                        ),
                      ),
                    ),

                    // Dynamic Notification with verified renderer at progress p
                    Positioned.fill(
                      child: DynamicNotifications(
                        controller: controller,
                        geometryOverride: testGeometry,
                        progressOverride: p,
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

      final boundary =
          repaintKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final ui.Image image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: 2.0),
      ) as ui.Image;
      final byteData = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      final pngBytes = byteData!.buffer.asUint8List();

      final percent = (p * 100).round();
      final file = File('doc/screenshots/island/progress_$percent.png');
      file.writeAsBytesSync(pngBytes);
    }
  });
}
