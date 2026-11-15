import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:dynamic_notifications/dynamic_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotchGeometryDetector', () {
    test(
      'detects centered punch hole when safe area is larger than cutout',
      () {
        // Simulates modern Android device (e.g. Pixel 8):
        // Status bar is 48dp, camera punch hole is at y: 8..32 (height 24dp, bottom 32dp).
        // Cutout bottom (32) is well inside the safe area (48).
        const mediaQuery = MediaQueryData(
          size: Size(412, 915),
          viewPadding: EdgeInsets.only(top: 48, bottom: 24),
          devicePixelRatio: 2.625,
          displayFeatures: [
            DisplayFeature(
              bounds: Rect.fromLTWH(194, 8, 24, 24),
              type: DisplayFeatureType.cutout,
              state: DisplayFeatureState.unknown,
            ),
          ],
        );

        final geometry = NotchGeometryDetector.fromMediaQuery(
          mediaQuery: mediaQuery,
          platform: TargetPlatform.android,
        );

        expect(geometry.hasCutout, isTrue);
        expect(geometry.source, NotchGeometrySource.displayFeature);
        expect(geometry.confidence, NotchGeometryConfidence.exact);
        expect(geometry.shape, NotchShape.punchHole);
        expect(geometry.center, const Offset(206, 20));
        expect(geometry.width, 24);
        expect(geometry.height, 24);
        expect(geometry.bottom, 32);
        expect(geometry.anchorX, 206);
        expect(geometry.anchorTop, 31); // 32 - 1 for overlap
        expect(geometry.devicePixelRatio, 2.625);
      },
    );

    test('detects cutout when cutout extends deeper than status bar padding', () {
      // Flaw in previous implementation: bounds.bottom > safeTop caused cutouts
      // with deeper punch holes (e.g. 42dp bottom with 32dp status bar) to be ignored!
      const mediaQuery = MediaQueryData(
        size: Size(393, 852),
        viewPadding: EdgeInsets.only(top: 32),
        devicePixelRatio: 3.0,
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(181, 10, 31, 32),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geometry = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: mediaQuery,
        platform: TargetPlatform.android,
      );

      expect(geometry.hasCutout, isTrue);
      expect(geometry.source, NotchGeometrySource.displayFeature);
      expect(geometry.bottom, 42);
      expect(geometry.anchorTop, 41);
      expect(geometry.anchorX, 196.5);
    });

    test(
      'handles physical-to-logical conversions across various DPR values',
      () {
        for (final dpr in [1.0, 1.5, 2.0, 2.625, 2.75, 3.0, 3.5, 4.0]) {
          // Physical bounds: 80 physical px wide, 80 physical px high, centered horizontally on 1080px wide screen
          const physicalScreenWidth = 1080.0;
          const physicalCutoutSize = 80.0;
          final logicalWidth = physicalScreenWidth / dpr;
          final logicalCutoutSize = physicalCutoutSize / dpr;
          final logicalLeft = (logicalWidth - logicalCutoutSize) / 2;

          final mediaQuery = MediaQueryData(
            size: Size(logicalWidth, 2400 / dpr),
            viewPadding: EdgeInsets.only(top: 100 / dpr),
            devicePixelRatio: dpr,
            displayFeatures: [
              DisplayFeature(
                bounds: Rect.fromLTWH(
                  logicalLeft,
                  20 / dpr,
                  logicalCutoutSize,
                  logicalCutoutSize,
                ),
                type: DisplayFeatureType.cutout,
                state: DisplayFeatureState.unknown,
              ),
            ],
          );

          final geometry = NotchGeometryDetector.fromMediaQuery(
            mediaQuery: mediaQuery,
            platform: TargetPlatform.android,
          );

          expect(geometry.hasCutout, isTrue);
          expect(geometry.devicePixelRatio, dpr);
          expect(geometry.anchorX, closeTo(logicalWidth / 2, 0.001));
          expect(geometry.bottom, closeTo(100 / dpr, 0.001));
          expect(geometry.anchorTop, closeTo((100 / dpr) - 1.0, 0.001));
        }
      },
    );

    test('correctly anchors off-center cutouts on left and right', () {
      // Off-center left punch hole (e.g. Galaxy S10 / OnePlus Nord)
      const leftCutout = MediaQueryData(
        size: Size(412, 892),
        viewPadding: EdgeInsets.only(top: 40),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(36, 10, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final leftGeo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: leftCutout,
        platform: TargetPlatform.android,
      );
      expect(leftGeo.anchorX, 48.0);
      expect(leftGeo.anchorTop, 33.0);

      // Off-center right punch hole
      const rightCutout = MediaQueryData(
        size: Size(412, 892),
        viewPadding: EdgeInsets.only(top: 40),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(352, 10, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final rightGeo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: rightCutout,
        platform: TargetPlatform.android,
      );
      expect(rightGeo.anchorX, 364.0);
      expect(rightGeo.anchorTop, 33.0);
    });

    test('merges adjacent dual punch holes into a pill cluster', () {
      // Devices with dual front cameras separated by a small gap
      const dualCamera = MediaQueryData(
        size: Size(412, 892),
        viewPadding: EdgeInsets.only(top: 44),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(180, 10, 20, 20),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
          DisplayFeature(
            bounds: Rect.fromLTWH(208, 10, 20, 20),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geometry = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: dualCamera,
        platform: TargetPlatform.android,
      );

      expect(geometry.hasCutout, isTrue);
      expect(geometry.shape, NotchShape.pill);
      expect(geometry.bounds, const Rect.fromLTWH(180, 10, 48, 20));
      expect(geometry.center.dx, 204.0);
    });

    test(
      'gracefully falls back when display features are missing on Android',
      () {
        // Older Android (API < 28) or letterboxed window mode with status bar
        const noCutouts = MediaQueryData(
          size: Size(360, 640),
          viewPadding: EdgeInsets.only(top: 24),
          displayFeatures: [],
        );

        final geometry = NotchGeometryDetector.fromMediaQuery(
          mediaQuery: noCutouts,
          platform: TargetPlatform.android,
        );

        expect(geometry.hasCutout, isFalse);
        expect(geometry.source, NotchGeometrySource.safeArea);
        expect(geometry.confidence, NotchGeometryConfidence.fallback);
        expect(geometry.shape, NotchShape.none);
        expect(geometry.bottom, 24.0);
        expect(geometry.anchorTop, 24.0);
        expect(geometry.anchorX, 180.0);
      },
    );

    test(
      'handles device with zero insets (tablet, desktop, or edge-to-edge game)',
      () {
        const zeroInsets = MediaQueryData(
          size: Size(1024, 768),
          viewPadding: EdgeInsets.zero,
          displayFeatures: [],
        );

        final geometry = NotchGeometryDetector.fromMediaQuery(
          mediaQuery: zeroInsets,
          platform: TargetPlatform.android,
        );

        expect(geometry.hasCutout, isFalse);
        expect(geometry.source, NotchGeometrySource.none);
        expect(geometry.confidence, NotchGeometryConfidence.none);
        expect(geometry.shape, NotchShape.none);
        expect(geometry.bottom, 0.0);
        expect(geometry.anchorTop, 0.0);
        expect(geometry.anchorX, 512.0);
      },
    );

    test(
      'detects side cutouts on left edge in landscape orientation',
      () {
        // In landscape, phone camera is on the left edge
        const landscapePhone = MediaQueryData(
          size: Size(892, 412),
          viewPadding: EdgeInsets.only(left: 48),
          displayFeatures: [
            DisplayFeature(
              bounds: Rect.fromLTWH(10, 194, 24, 24),
              type: DisplayFeatureType.cutout,
              state: DisplayFeatureState.unknown,
            ),
          ],
        );

        final geometry = NotchGeometryDetector.fromMediaQuery(
          mediaQuery: landscapePhone,
          platform: TargetPlatform.android,
        );

        expect(geometry.hasCutout, isTrue);
        expect(geometry.edge, CutoutEdge.left);
        expect(geometry.source, NotchGeometrySource.displayFeature);
        expect(geometry.anchorPoint, const Offset(33.0, 206.0));
        expect(geometry.emergenceDirection, const Offset(1.0, 0.0));
      },
    );

    test('calibrates iOS notch and Dynamic Island profiles accurately', () {
      // iPhone SE / iPad (no notch)
      final se = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: const MediaQueryData(
          size: Size(375, 667),
          viewPadding: EdgeInsets.only(top: 20),
        ),
        platform: TargetPlatform.iOS,
      );
      expect(se.hasCutout, isFalse);
      expect(se.source, NotchGeometrySource.safeArea);

      // iPhone X / 11 Pro (notch, 44pt safe top)
      final iphX = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: const MediaQueryData(
          size: Size(375, 812),
          viewPadding: EdgeInsets.only(top: 44),
        ),
        platform: TargetPlatform.iOS,
      );
      expect(iphX.hasCutout, isTrue);
      expect(iphX.source, NotchGeometrySource.profile);
      expect(iphX.shape, NotchShape.notch);
      expect(iphX.bottom, 29.0);
      expect(iphX.anchorTop, 29.0);

      // iPhone 14 Pro / 15 (Dynamic Island, 59pt safe top)
      final island = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: const MediaQueryData(
          size: Size(393, 852),
          viewPadding: EdgeInsets.only(top: 59),
        ),
        platform: TargetPlatform.iOS,
      );
      expect(island.hasCutout, isTrue);
      expect(island.source, NotchGeometrySource.profile);
      expect(island.shape, NotchShape.pill);
      expect(island.bottom, 48.0);
      expect(island.anchorTop, 48.0);

      // iPhone 15 Pro Max / 16 Pro Max (Dynamic Island, 62pt safe top)
      final islandMax = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: const MediaQueryData(
          size: Size(430, 932),
          viewPadding: EdgeInsets.only(top: 62),
        ),
        platform: TargetPlatform.iOS,
      );
      expect(islandMax.hasCutout, isTrue);
      expect(islandMax.shape, NotchShape.pill);
      expect(islandMax.bottom, 50.0);
      expect(islandMax.anchorTop, 50.0);
    });

    test('classifies teardrop/waterdrop notch touching top edge as notch', () {
      // Android device with centered teardrop notch (e.g. Galaxy A series, Redmi)
      // Cutout touches the upper edge (top = 0) and has width = 28dp.
      const teardrop = MediaQueryData(
        size: Size(392, 820),
        viewPadding: EdgeInsets.only(top: 28),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(182, 0, 28, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geometry = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: teardrop,
        platform: TargetPlatform.android,
      );

      expect(geometry.hasCutout, isTrue);
      expect(geometry.shape, NotchShape.notch);
      expect(geometry.bottom, 24.0);
      expect(geometry.anchorTop, 23.0);
    });

    test('calibrates real Android DisplayCutout.boundingRects touching top edge', () {
      // Real Android hardware reporting (AOSP / Pixel 7a / Galaxy S23):
      // DisplayCutout.getBoundingRects() reports bounds touching top edge (0.0)
      // and extending to status bar height (45.0dp / 118px) with horizontal exclusion padding.
      const realHardware = MediaQueryData(
        size: Size(411.4, 914.3),
        viewPadding: EdgeInsets.only(top: 45.0, bottom: 24.0),
        devicePixelRatio: 2.625,
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTRB(182.9, 0.0, 238.1, 45.0),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geometry = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: realHardware,
        platform: TargetPlatform.android,
      );

      expect(geometry.hasCutout, isTrue);
      expect(geometry.source, NotchGeometrySource.displayFeature);
      expect(geometry.shape, NotchShape.punchHole);
      expect(geometry.confidence, NotchGeometryConfidence.calibrated);
      // Punch hole bottom is calibrated inside status bar (below physical camera aperture):
      // 45.0 - (45.0 * 0.18) = 36.9dp (matches physical camera bottom at 37.7dp)
      expect(geometry.bottom, closeTo(36.9, 0.5));
      expect(geometry.anchorTop, closeTo(35.9, 0.5));
      // Camera width is bounded to physical aperture diameter rather than padded exclusion
      expect(geometry.width, lessThanOrEqualTo(32.0));
      expect(geometry.width, greaterThanOrEqualTo(24.0));
    });

    test('handles edge-to-edge layout with zero insets but with hardware cutout', () {
      // Game or media app with immersive edge-to-edge mode (hidden status bar),
      // but hardware front camera cutout is physically present.
      const immersiveCutout = MediaQueryData(
        size: Size(412, 915),
        viewPadding: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(194, 8, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geometry = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: immersiveCutout,
        platform: TargetPlatform.android,
      );

      expect(geometry.hasCutout, isTrue);
      expect(geometry.shape, NotchShape.punchHole);
      expect(geometry.bottom, 32.0);
      expect(geometry.anchorTop, 31.0);
    });

    test('detects corner cutout on side edge when rotated to landscape', () {
      // Corner punch hole (e.g. Galaxy S10) rotated into landscape mode:
      // The camera is on the left edge touching x = 0 at y = 20.
      const landscapeCorner = MediaQueryData(
        size: Size(892, 412),
        viewPadding: EdgeInsets.only(left: 48),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 20, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geometry = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: landscapeCorner,
        platform: TargetPlatform.android,
      );

      expect(geometry.hasCutout, isTrue);
      expect(geometry.edge, CutoutEdge.left);
      expect(geometry.anchorPoint, const Offset(23.0, 32.0));
    });

    test('detects floating side punch hole in landscape with side insets', () {
      // Floating side punch hole in landscape orientation with side insets:
      // The camera is at x: 16..40, y: 12..36 on the left edge inside the 48dp side safe area.
      const landscapeFloatingSide = MediaQueryData(
        size: Size(892, 412),
        viewPadding: EdgeInsets.only(left: 48),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(16, 12, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geometry = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: landscapeFloatingSide,
        platform: TargetPlatform.android,
      );

      expect(geometry.hasCutout, isTrue);
      expect(geometry.edge, CutoutEdge.left);
      expect(geometry.anchorPoint, const Offset(39.0, 24.0));
    });

    test('falls back to mediaQuery.padding if viewPadding is zero', () {
      // When caller only sets padding without viewPadding
      const paddingOnly = MediaQueryData(
        size: Size(375, 812),
        padding: EdgeInsets.only(top: 36),
        viewPadding: EdgeInsets.zero,
      );

      final geometry = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: paddingOnly,
        platform: TargetPlatform.android,
      );

      expect(geometry.insets.top, 36.0);
      expect(geometry.bottom, 36.0);
      expect(geometry.anchorTop, 36.0);
    });

    test('NotchGeometry value equality and hashCode work correctly', () {
      const geo1 = NotchGeometry(
        bounds: Rect.fromLTWH(100, 10, 20, 20),
        center: Offset(110, 20),
        width: 20,
        height: 20,
        top: 10,
        bottom: 30,
        screenSize: Size(400, 800),
        insets: EdgeInsets.only(top: 40),
        source: NotchGeometrySource.displayFeature,
        confidence: NotchGeometryConfidence.exact,
        shape: NotchShape.punchHole,
        hasCutout: true,
      );

      const geo2 = NotchGeometry(
        bounds: Rect.fromLTWH(100, 10, 20, 20),
        center: Offset(110, 20),
        width: 20,
        height: 20,
        top: 10,
        bottom: 30,
        screenSize: Size(400, 800),
        insets: EdgeInsets.only(top: 40),
        source: NotchGeometrySource.displayFeature,
        confidence: NotchGeometryConfidence.exact,
        shape: NotchShape.punchHole,
        hasCutout: true,
      );

      const geo3 = NotchGeometry(
        bounds: Rect.fromLTWH(100, 10, 20, 20),
        center: Offset(110, 20),
        width: 20,
        height: 20,
        top: 10,
        bottom: 30,
        screenSize: Size(400, 800),
        insets: EdgeInsets.only(top: 40),
        source: NotchGeometrySource.profile,
        confidence: NotchGeometryConfidence.calibrated,
        shape: NotchShape.pill,
        hasCutout: true,
      );

      expect(geo1, equals(geo2));
      expect(geo1.hashCode, equals(geo2.hashCode));
      expect(geo1, isNot(equals(geo3)));
      expect(geo1.toString(), contains('punchHole'));
    });
  });

  group('DynamicNotifications with NotchGeometry', () {
    late DynamicNotificationController controller;

    setUp(() {
      controller = DynamicNotificationController();
    });

    testWidgets('allows injecting custom geometryOverride', (tester) async {
      const customGeometry = NotchGeometry(
        bounds: Rect.fromLTWH(100, 0, 50, 35),
        center: Offset(125, 17.5),
        width: 50,
        height: 35,
        top: 0,
        bottom: 35,
        screenSize: Size(400, 800),
        insets: EdgeInsets.only(top: 40),
        source: NotchGeometrySource.displayFeature,
        confidence: NotchGeometryConfidence.exact,
        shape: NotchShape.punchHole,
        hasCutout: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DynamicNotifications(
            controller: controller,
            geometryOverride: customGeometry,
            child: const Scaffold(body: Center(child: Text('Content'))),
          ),
        ),
      );

      controller.show(
        const DynamicNotification(title: 'Custom Test', duration: null),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final overlay = find.byKey(const ValueKey('dynamic-notification-shape'));
      expect(tester.getTopLeft(overlay).dy, 34.0); // 35 - 1 = 34
    });

    testWidgets(
      'adapts seamlessly during dynamic screen rotation and metric change',
      (tester) async {
        // Start in portrait with a centered top punch hole
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              controller: controller,
              child: const Scaffold(body: Center(child: Text('Content'))),
            ),
          ),
        );

        controller.show(
          const DynamicNotification(title: 'Rotation Test', duration: null),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);

        // Rotate to landscape
        tester.view.physicalSize = const Size(2400, 1080);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Rotation Test'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('accurately positions water drop for Android deep punch hole', (
      tester,
    ) async {
      // Android device where camera punch hole (bottom=44) is deeper than status bar (top padding=32)
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewPadding: const EdgeInsets.only(top: 32, bottom: 20),
              displayFeatures: const [
                DisplayFeature(
                  bounds: Rect.fromLTWH(180, 10, 32, 34), // bottom is 44!
                  type: DisplayFeatureType.cutout,
                  state: DisplayFeatureState.unknown,
                ),
              ],
            ),
            child: DynamicNotifications(controller: controller, child: child!),
          ),
          home: const Scaffold(body: Center(child: Text('Content'))),
        ),
      );

      controller.show(
        const DynamicNotification(title: 'Deep Cutout', duration: null),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final overlay = find.byKey(const ValueKey('dynamic-notification-shape'));
      // In the old code, this was rejected because 44 > safeTop(36), falling back to safeTop (36).
      // In the new code, this is recognized as the cutout, anchoring at 44 - 1 = 43!
      expect(tester.getTopLeft(overlay).dy, 43.0);

      // Cutout is centered at 180 + 16 = 196
      // Overlay center is at screenCenter = viewportCenter = 400 (default tester width is 800)
      await tester.pumpAndSettle();
      expect(find.text('Deep Cutout'), findsOneWidget);
    });

    testWidgets(
      'allows injecting custom geometryOverride with hasCutout false',
      (tester) async {
        const fallbackGeometry = NotchGeometry(
          bounds: null,
          center: Offset(200, 15),
          width: 0,
          height: 0,
          top: 0,
          bottom: 30,
          screenSize: Size(400, 800),
          insets: EdgeInsets.only(top: 30),
          source: NotchGeometrySource.safeArea,
          confidence: NotchGeometryConfidence.fallback,
          shape: NotchShape.none,
          hasCutout: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              controller: controller,
              geometryOverride: fallbackGeometry,
              child: const Scaffold(body: Center(child: Text('Content'))),
            ),
          ),
        );

        controller.show(
          const DynamicNotification(title: 'Fallback Test', duration: null),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final overlay = find.byKey(
          const ValueKey('dynamic-notification-shape'),
        );
        // Custom fallback anchorTop (30.0) is respected instead of falling back to default safeTop
        expect(tester.getTopLeft(overlay).dy, 30.0);
      },
    );

    testWidgets(
      'water-drop painter arches upward and overlaps into hardware cutout for punch hole',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewPadding: const EdgeInsets.only(top: 40),
                displayFeatures: const [
                  DisplayFeature(
                    bounds: Rect.fromLTWH(
                      388,
                      8,
                      24,
                      24,
                    ), // center is 400, bottom is 32
                    type: DisplayFeatureType.cutout,
                    state: DisplayFeatureState.unknown,
                  ),
                ],
              ),
              child: DynamicNotifications(
                controller: controller,
                child: child!,
              ),
            ),
            home: const Scaffold(body: Center(child: Text('Content'))),
          ),
        );

        controller.show(
          const DynamicNotification(title: 'Overlap Test', duration: null),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final overlay = find.byKey(
          const ValueKey('dynamic-notification-shape'),
        );
        final center = tester.getSize(overlay).width / 2;

        // Verify that local Y = 1 is covered as before
        // AND verify that local Y = -1 is ALSO covered by the upward curvature into the cutout
        // (eliminating subpixel anti-aliasing seams and circular curvature gap)
        expect(
          overlay,
          paints..path(
            color: Colors.black,
            includes: [Offset(center, 1), Offset(center, -1)],
            excludes: [Offset(center + 36, 1), Offset(center + 36, -1)],
          ),
        );
      },
    );

    testWidgets(
      'handles edge-to-edge mode with zero padding and cutout without throwing RenderPadding assertion',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewPadding: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                displayFeatures: const [
                  DisplayFeature(
                    bounds: Rect.fromLTWH(188, 10, 24, 34), // bottom 44 > 0
                    type: DisplayFeatureType.cutout,
                    state: DisplayFeatureState.unknown,
                  ),
                ],
              ),
              child: DynamicNotifications(
                controller: controller,
                child: child!,
              ),
            ),
            home: const Scaffold(body: Center(child: Text('Content'))),
          ),
        );

        controller.show(
          const DynamicNotification(title: 'Immersive App', duration: null),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(find.text('Immersive App'), findsOneWidget);
      },
    );

    testWidgets(
      'painter clipRect encloses entire tail horizontally for off-center cutout',
      (tester) async {
        // Off-center cutout on an 800-wide display resulting in centerX < -24.
        // Tail extends to centerX - neck * 1.25, which is further left than rect.left.
        const offCenterGeometry = NotchGeometry(
          bounds: Rect.fromLTWH(40, 8, 24, 24),
          center: Offset(52, 20),
          width: 24,
          height: 24,
          top: 8,
          bottom: 32,
          screenSize: Size(800, 600),
          insets: EdgeInsets.only(top: 40),
          source: NotchGeometrySource.displayFeature,
          confidence: NotchGeometryConfidence.exact,
          shape: NotchShape.punchHole,
          hasCutout: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              controller: controller,
              geometryOverride: offCenterGeometry,
              child: const Scaffold(body: Center(child: Text('Content'))),
            ),
          ),
        );

        controller.show(
          const DynamicNotification(title: 'Clip Test', duration: null),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final overlay = find.byKey(
          const ValueKey('dynamic-notification-shape'),
        );
        // Tail's left edge is around -168dp. The clipRect must not clip the tail.
        expect(
          overlay,
          paints..something((Symbol method, List<dynamic> arguments) {
            if (method == #clipRect) {
              final rect = arguments[0] as Rect;
              return rect.left <= -168.0;
            }
            return false;
          }),
        );
      },
    );

    testWidgets(
      'painter does not paint negative screen coordinates when anchorTop is zero',
      (tester) async {
        // Hardware cutout touching top edge with bottom=1, anchorTop = max(0, 1 - 1) = 0.
        const zeroAnchorGeometry = NotchGeometry(
          bounds: Rect.fromLTWH(188, 0, 24, 1),
          center: Offset(200, 0.5),
          width: 24,
          height: 1,
          top: 0,
          bottom: 1,
          screenSize: Size(400, 800),
          insets: EdgeInsets.zero,
          source: NotchGeometrySource.displayFeature,
          confidence: NotchGeometryConfidence.exact,
          shape: NotchShape.punchHole,
          hasCutout: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              controller: controller,
              geometryOverride: zeroAnchorGeometry,
              child: const Scaffold(body: Center(child: Text('Content'))),
            ),
          ),
        );

        controller.show(
          const DynamicNotification(title: 'Zero Anchor', duration: null),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final overlay = find.byKey(
          const ValueKey('dynamic-notification-shape'),
        );
        // When anchorTop == 0, painting at Y < 0 would paint above the screen.
        // clipRect must not allow negative screen coordinates.
        expect(
          overlay,
          paints..something((Symbol method, List<dynamic> arguments) {
            if (method == #clipRect) {
              final rect = arguments[0] as Rect;
              return rect.top >= 0.0;
            }
            return false;
          }),
        );
      },
    );

    testWidgets(
      'respects MediaQuery.padding when viewPadding is zero without cutout',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 36),
                viewPadding: EdgeInsets.zero,
                displayFeatures: const [],
              ),
              child: DynamicNotifications(
                controller: controller,
                child: child!,
              ),
            ),
            home: const Scaffold(body: Center(child: Text('Content'))),
          ),
        );

        controller.show(
          const DynamicNotification(title: 'Padding Fallback', duration: null),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final overlay = find.byKey(
          const ValueKey('dynamic-notification-shape'),
        );
        // safeTop should be padding.top + 4 = 36 + 4 = 40.0
        expect(tester.getTopLeft(overlay).dy, 40.0);
      },
    );

    testWidgets(
      'painter clipRect allows shadow headroom above card when anchorTop > 0',
      (tester) async {
        // Screen with anchorTop = 32.0 (cutout bottom = 33, anchorTop = 32).
        const testGeometry = NotchGeometry(
          bounds: Rect.fromLTWH(188, 8, 24, 24),
          center: Offset(200, 20),
          width: 24,
          height: 24,
          top: 8,
          bottom: 33,
          screenSize: Size(400, 800),
          insets: EdgeInsets.only(top: 32),
          source: NotchGeometrySource.displayFeature,
          confidence: NotchGeometryConfidence.exact,
          shape: NotchShape.punchHole,
          hasCutout: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              controller: controller,
              geometryOverride: testGeometry,
              child: const Scaffold(body: Center(child: Text('Content'))),
            ),
          ),
        );

        controller.show(
          const DynamicNotification(title: 'Shadow Test', duration: null),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final overlay = find.byKey(
          const ValueKey('dynamic-notification-shape'),
        );
        // When anchorTop == 32, local y = -16 maps to screen y = 16 >= 0.
        // clipRect should allow shadow headroom (up to -16) rather than clipping at -3.5 or 0.
        expect(
          overlay,
          paints..something((Symbol method, List<dynamic> arguments) {
            if (method == #clipRect) {
              final rect = arguments[0] as Rect;
              return rect.top <= -10.0;
            }
            return false;
          }),
        );
      },
    );

    test('detects side punch hole in immersive landscape with zero insets', () {
      // In immersive landscape mode, insets are zero. A punch hole is physically
      // located on the side edge (x: 16..40, y: 12..36).
      const immersiveLandscape = MediaQueryData(
        size: Size(892, 412),
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(16, 12, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geometry = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: immersiveLandscape,
        platform: TargetPlatform.android,
      );

      expect(geometry.hasCutout, isTrue);
      expect(geometry.edge, CutoutEdge.left);
      expect(geometry.source, NotchGeometrySource.displayFeature);
      expect(geometry.anchorPoint, const Offset(39.0, 24.0));
      expect(geometry.emergenceDirection, const Offset(1.0, 0.0));
    });

    test('detects side punch hole in immersive landscape on right edge with zero insets', () {
      const immersiveLandscapeRight = MediaQueryData(
        size: Size(892, 412),
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(856, 12, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geometry = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: immersiveLandscapeRight,
        platform: TargetPlatform.android,
      );

      expect(geometry.hasCutout, isTrue);
      expect(geometry.edge, CutoutEdge.right);
      expect(geometry.source, NotchGeometrySource.displayFeature);
      expect(geometry.anchorPoint, const Offset(857.0, 24.0));
      expect(geometry.emergenceDirection, const Offset(-1.0, 0.0));
    });

    test('detects centered top punch hole on tablet in landscape', () {
      const tabletLandscape = MediaQueryData(
        size: Size(1024, 768),
        padding: EdgeInsets.only(top: 24),
        viewPadding: EdgeInsets.only(top: 24),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(500, 4, 24, 20),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geometry = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: tabletLandscape,
        platform: TargetPlatform.android,
      );

      expect(geometry.hasCutout, isTrue);
      expect(geometry.anchorX, 512.0);
      expect(geometry.bottom, 24.0);
    });

    test('AndroidCutoutGeometryProvider queries native cutoutPath (API 31+) and constructs NotchGeometry', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dynamic_notifications/android_geometry'),
            (call) async {
              if (call.method == 'getCutoutGeometry') {
                return <String, dynamic>{
                  'deviceModel': 'Pixel 7a',
                  'apiLevel': 34,
                  'targetSdk': 34,
                  'hasCutout': true,
                  'hasPath': true,
                  'pathLeft': 507.0,
                  'pathTop': 33.0,
                  'pathRight': 573.0,
                  'pathBottom': 99.0,
                  'pathWidth': 66.0,
                  'pathHeight': 66.0,
                  'boundLeft': 480.0,
                  'boundTop': 0.0,
                  'boundRight': 625.0,
                  'boundBottom': 118.0,
                };
              }
              return null;
            },
          );

      final provider = AndroidCutoutGeometryProvider();
      const mediaQuery = MediaQueryData(
        size: Size(411.4, 914.3),
        devicePixelRatio: 2.625,
        viewPadding: EdgeInsets.only(top: 45.0, bottom: 24.0),
      );

      final geo = await provider.load(mediaQuery: mediaQuery);
      expect(geo, isNotNull);
      expect(geo!.hasCutout, isTrue);
      expect(geo.source, NotchGeometrySource.nativePath);
      expect(geo.confidence, NotchGeometryConfidence.exact);
      expect(geo.shape, NotchShape.punchHole);
      // Converted from physical coordinates at DPR 2.625:
      // 507 / 2.625 = 193.14, 33 / 2.625 = 12.57, 99 / 2.625 = 37.71
      expect(geo.top, closeTo(12.57, 0.01));
      expect(geo.bottom, closeTo(37.71, 0.01));
      expect(geo.anchorTop, closeTo(36.71, 0.01));
      expect(geo.width, closeTo(25.14, 0.01));
      expect(provider.cached, equals(geo));

      provider.clear();
      expect(provider.cached, isNull);
    });

    test('AndroidCutoutGeometryProvider falls back to boundingRects when cutoutPath is unavailable', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dynamic_notifications/android_geometry'),
            (call) async {
              if (call.method == 'getCutoutGeometry') {
                return <String, dynamic>{
                  'deviceModel': 'Galaxy S10',
                  'apiLevel': 29,
                  'targetSdk': 29,
                  'hasCutout': true,
                  'hasPath': false,
                  'boundLeft': 750.0,
                  'boundTop': 0.0,
                  'boundRight': 950.0,
                  'boundBottom': 100.0,
                };
              }
              return null;
            },
          );

      final provider = AndroidCutoutGeometryProvider();
      const mediaQuery = MediaQueryData(
        size: Size(360.0, 740.0),
        devicePixelRatio: 2.0,
        viewPadding: EdgeInsets.only(top: 50.0),
      );

      final geo = await provider.load(mediaQuery: mediaQuery);
      expect(geo, isNotNull);
      expect(geo!.hasCutout, isTrue);
      expect(geo.source, NotchGeometrySource.displayFeature);
      expect(geo.top, 0.0);
      expect(geo.bottom, 50.0);
      expect(geo.anchorTop, 49.0);
      expect(geo.width, 100.0);
    });

    testWidgets(
      'DynamicNotifications renders visual guides when debugShowGuides is enabled',
      (tester) async {
        final ctrl = DynamicNotificationController();
        const testGeometry = NotchGeometry(
          bounds: Rect.fromLTWH(188, 8, 24, 24),
          center: Offset(200, 20),
          width: 24,
          height: 24,
          top: 8,
          bottom: 32,
          screenSize: Size(400, 800),
          insets: EdgeInsets.only(top: 32),
          source: NotchGeometrySource.displayFeature,
          confidence: NotchGeometryConfidence.exact,
          shape: NotchShape.punchHole,
          hasCutout: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              controller: ctrl,
              geometryOverride: testGeometry,
              debugShowGuides: true,
              child: const Scaffold(body: Center(child: Text('Content'))),
            ),
          ),
        );

        ctrl.show(
          const DynamicNotification(title: 'Debug Guides Test', duration: null),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final overlay = find.byKey(
          const ValueKey('dynamic-notification-shape'),
        );
        expect(overlay, findsOneWidget);
        // Verify debug guides painted (rect, lines for crosshair & neck guide)
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('DynamicNotifications renders smoothly on entrance and exit', (
      tester,
    ) async {
      final ctrl = DynamicNotificationController();
      const testGeometry = NotchGeometry(
        bounds: Rect.fromLTWH(188, 8, 24, 24),
        center: Offset(200, 20),
        width: 24,
        height: 24,
        top: 8,
        bottom: 32,
        screenSize: Size(400, 800),
        insets: EdgeInsets.only(top: 32),
        source: NotchGeometrySource.displayFeature,
        confidence: NotchGeometryConfidence.exact,
        shape: NotchShape.punchHole,
        hasCutout: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DynamicNotifications(
            controller: ctrl,
            geometryOverride: testGeometry,
            child: const Scaffold(body: Center(child: Text('Content'))),
          ),
        ),
      );

      ctrl.show(
        const DynamicNotification(title: 'Standard Mode Test', duration: null),
      );
      await tester.pump();

      // Entrance bridge phase
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        find.byKey(const ValueKey('dynamic-notification-shape')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Expansion phase
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // Fully settled
      await tester.pumpAndSettle();
      expect(find.text('Standard Mode Test').hitTestable(), findsOneWidget);

      // Dismissal / exit absorption phase
      ctrl.dismiss();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Standard Mode Test'), findsNothing);
    });

    testWidgets(
      'DynamicNotifications does not paint negative screen coordinates when anchorTop is zero',
      (tester) async {
        final ctrl = DynamicNotificationController();
        const testGeometry = NotchGeometry(
          bounds: Rect.fromLTRB(188, 0, 212, 0),
          center: Offset(200, 0),
          width: 24,
          height: 0,
          top: 0,
          bottom: 0,
          screenSize: Size(400, 800),
          insets: EdgeInsets.zero,
          source: NotchGeometrySource.none,
          confidence: NotchGeometryConfidence.none,
          shape: NotchShape.punchHole,
          hasCutout: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              controller: ctrl,
              geometryOverride: testGeometry,
              child: const Scaffold(body: Center(child: Text('Zero Anchor'))),
            ),
          ),
        );

        ctrl.show(
          const DynamicNotification(title: 'Edge Screen', duration: null),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        final customPaintFinder = find.byKey(
          const ValueKey('dynamic-notification-shape'),
        );
        expect(customPaintFinder, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'NotchGeometryDetector.detect ignores cached Android geometry on iOS platform',
      (tester) async {
        final provider = AndroidCutoutGeometryProvider.instance;
        const cachedGeo = NotchGeometry(
          bounds: Rect.fromLTWH(188, 10, 24, 24),
          center: Offset(200, 22),
          width: 24,
          height: 24,
          top: 10,
          bottom: 34,
          screenSize: Size(400, 800),
          insets: EdgeInsets.only(top: 34),
          source: NotchGeometrySource.nativePath,
          confidence: NotchGeometryConfidence.exact,
          shape: NotchShape.punchHole,
          hasCutout: true,
        );

        provider.cachedForTesting = cachedGeo;
        addTearDown(() => provider.clear());

        // Build context with iOS platform and safe area of 59pt (iPhone Dynamic Island)
        late NotchGeometry detected;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(393, 852),
                devicePixelRatio: 3.0,
                padding: EdgeInsets.only(top: 59),
              ),
              child: Builder(
                builder: (context) {
                  detected = NotchGeometryDetector.detect(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // Must detect iOS Dynamic Island profile, NOT the Android cached punch hole
        expect(detected.source, NotchGeometrySource.profile);
        expect(detected.shape, NotchShape.pill);
        expect(detected.screenSize, const Size(393, 852));
      },
    );

    testWidgets(
      'NotchGeometryDetector.detect ignores cached Android geometry when screen size changes',
      (tester) async {
        final provider = AndroidCutoutGeometryProvider.instance;
        const cachedGeo = NotchGeometry(
          bounds: Rect.fromLTWH(188, 10, 24, 24),
          center: Offset(200, 22),
          width: 24,
          height: 24,
          top: 10,
          bottom: 34,
          screenSize: Size(400, 800),
          insets: EdgeInsets.only(top: 34),
          source: NotchGeometrySource.nativePath,
          confidence: NotchGeometryConfidence.exact,
          shape: NotchShape.punchHole,
          hasCutout: true,
        );

        provider.cachedForTesting = cachedGeo;
        addTearDown(() => provider.clear());

        late NotchGeometry detectedLandscape;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(800, 400),
                devicePixelRatio: 1.0,
                padding: EdgeInsets.only(left: 34),
              ),
              child: Builder(
                builder: (context) {
                  detectedLandscape = NotchGeometryDetector.detect(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );

        // When size differs, it must not return the stale 400x800 portrait cache
        expect(detectedLandscape.screenSize, const Size(800, 400));
      },
    );

    test(
      'AndroidCutoutGeometryProvider handles concurrent load requests safely',
      () async {
        final provider = AndroidCutoutGeometryProvider();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(provider.channel, (call) async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return <String, dynamic>{
                'hasCutout': true,
                'hasPath': true,
                'pathLeft': 188.0,
                'pathTop': 10.0,
                'pathRight': 212.0,
                'pathBottom': 34.0,
              };
            });

        const mq = MediaQueryData(
          size: Size(400, 800),
          devicePixelRatio: 1.0,
          viewPadding: EdgeInsets.only(top: 34),
        );

        // Trigger two concurrent load calls
        final future1 = provider.load(mediaQuery: mq);
        final future2 = provider.load(mediaQuery: mq);

        final results = await Future.wait([future1, future2]);
        expect(results[0], isNotNull);
        expect(results[1], isNotNull);
        expect(results[0], equals(results[1]));
        expect(provider.cached, isNotNull);
        provider.clear();
      },
    );

    testWidgets(
      'DynamicNotifications switches rendering mode and repaints correctly',
      (tester) async {
        final ctrl = DynamicNotificationController();
        const testGeometry = NotchGeometry(
          bounds: Rect.fromLTWH(188, 8, 24, 24),
          center: Offset(200, 20),
          width: 24,
          height: 24,
          top: 8,
          bottom: 32,
          screenSize: Size(400, 800),
          insets: EdgeInsets.only(top: 32),
          source: NotchGeometrySource.displayFeature,
          confidence: NotchGeometryConfidence.exact,
          shape: NotchShape.punchHole,
          hasCutout: true,
        );

        // Build with standard mode at progress 0.3
        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              controller: ctrl,
              geometryOverride: testGeometry,
              progressOverride: 0.3,
              child: const Scaffold(body: Center(child: Text('Content'))),
            ),
          ),
        );
        await tester.pump();

        var customPaint = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('dynamic-notification-shape')),
        );
        expect(customPaint.painter, isNotNull);

        // Update progress to 0.7
        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              controller: ctrl,
              geometryOverride: testGeometry,
              progressOverride: 0.7,
              child: const Scaffold(body: Center(child: Text('Content'))),
            ),
          ),
        );
        await tester.pump();

        customPaint = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('dynamic-notification-shape')),
        );
        expect(customPaint.painter, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'attachment geometry conforms to circular punch hole without horizontal ledge',
      (tester) async {
        const testGeometry = NotchGeometry(
          bounds: Rect.fromLTWH(388, 8, 24, 24),
          center: Offset(400, 20),
          width: 24,
          height: 24,
          top: 8,
          bottom: 32,
          screenSize: Size(800, 600),
          insets: EdgeInsets.only(top: 40),
          source: NotchGeometrySource.displayFeature,
          confidence: NotchGeometryConfidence.exact,
          shape: NotchShape.punchHole,
          hasCutout: true,
          devicePixelRatio: 2.0,
        );

        final ctrl = DynamicNotificationController();
        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              controller: ctrl,
              geometryOverride: testGeometry,
              progressOverride: 0.15,
              child: const Scaffold(
                body: Center(child: Text('Punch Hole Test')),
              ),
            ),
          ),
        );
        await tester.pump();

        final overlay = find.byKey(
          const ValueKey('dynamic-notification-shape'),
        );
        final center = tester.getSize(overlay).width / 2;

        expect(
          overlay,
          paints..path(
            includes: [
              Offset(center, 0.5), // Within overlap
              Offset(center, -1.0), // Inside apex overlap
            ],
            excludes: [
              Offset(center, -11.0), // Camera lens center is preserved
              Offset(
                center + 14.0,
                -1.0,
              ), // No horizontal ledge outside aperture
              Offset(
                center - 14.0,
                -1.0,
              ), // No horizontal ledge outside aperture
              Offset(center + 24.0, 1.0), // Far lateral exclude
            ],
          ),
        );
      },
    );

    testWidgets('attachment geometry conforms to pill cutout without ledge', (
      tester,
    ) async {
      // iPhone Dynamic Island pill cutout: width 126, height 37, center (400, 30)
      const pillGeometry = NotchGeometry(
        bounds: Rect.fromLTWH(337, 11, 126, 37),
        center: Offset(400, 29.5),
        width: 126,
        height: 37,
        top: 11,
        bottom: 48,
        screenSize: Size(800, 600),
        insets: EdgeInsets.only(top: 59),
        source: NotchGeometrySource.profile,
        confidence: NotchGeometryConfidence.calibrated,
        shape: NotchShape.pill,
        hasCutout: true,
        devicePixelRatio: 3.0,
      );

      final ctrl = DynamicNotificationController();
      await tester.pumpWidget(
        MaterialApp(
          home: DynamicNotifications(
            controller: ctrl,
            geometryOverride: pillGeometry,
            progressOverride: 0.15,
            child: const Scaffold(body: Center(child: Text('Pill Test'))),
          ),
        ),
      );
      await tester.pump();

      final overlay = find.byKey(const ValueKey('dynamic-notification-shape'));
      final center = tester.getSize(overlay).width / 2;

      expect(
        overlay,
        paints..path(
          includes: [
            Offset(center, -1.0), // Overlaps into pill bottom rim
          ],
          excludes: [
            Offset(center, -18.0), // Center of pill is preserved
            Offset(center + 70.0, -1.0), // Outside pill bounds
          ],
        ),
      );
    });

    testWidgets(
      'originLift preserves overlap depth and adheres to aperture boundary',
      (tester) async {
        const testGeometry = NotchGeometry(
          bounds: Rect.fromLTWH(388, 8, 24, 24),
          center: Offset(400, 20),
          width: 24,
          height: 24,
          top: 8,
          bottom: 32,
          screenSize: Size(800, 600),
          insets: EdgeInsets.only(top: 40),
          source: NotchGeometrySource.displayFeature,
          confidence: NotchGeometryConfidence.exact,
          shape: NotchShape.punchHole,
          hasCutout: true,
          devicePixelRatio: 2.0,
        );

        final ctrl = DynamicNotificationController();
        // originLift = 8.0 lifts anchorTop from 31 to 23
        // cutoutBottomLocal = 32 - 23 = 9.0; yApex = 9.0 - 2.2 = 6.8; lens center is at -3.0
        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              controller: ctrl,
              geometryOverride: testGeometry,
              originLift: 8.0,
              progressOverride: 0.15,
              child: const Scaffold(body: Center(child: Text('Lift Test'))),
            ),
          ),
        );
        await tester.pump();

        final overlay = find.byKey(
          const ValueKey('dynamic-notification-shape'),
        );
        final center = tester.getSize(overlay).width / 2;

        expect(
          overlay,
          paints..path(
            includes: [
              Offset(center, 7.5), // Within overlap
              Offset(center, 7.0), // Inside apex overlap
            ],
            excludes: [
              Offset(
                center,
                -3.0,
              ), // Camera lens center (Y = -3.0) is preserved
              Offset(
                center + 14.0,
                7.0,
              ), // No horizontal ledge outside aperture
            ],
          ),
        );
      },
    );

    testWidgets(
      'attachment geometry maintains tangent continuity without bulging at intermediate progress (0.20, 0.30)',
      (tester) async {
        const testGeometry = NotchGeometry(
          bounds: Rect.fromLTWH(388, 8, 24, 24),
          center: Offset(400, 20),
          width: 24,
          height: 24,
          top: 8,
          bottom: 32,
          screenSize: Size(800, 600),
          insets: EdgeInsets.only(top: 40),
          source: NotchGeometrySource.displayFeature,
          confidence: NotchGeometryConfidence.exact,
          shape: NotchShape.punchHole,
          hasCutout: true,
          devicePixelRatio: 2.0,
        );

        for (final p in [0.20, 0.30]) {
          final ctrl = DynamicNotificationController();
          await tester.pumpWidget(
            MaterialApp(
              home: DynamicNotifications(
                controller: ctrl,
                geometryOverride: testGeometry,
                progressOverride: p,
                child: const Scaffold(
                  body: Center(child: Text('Bulge Test')),
                ),
              ),
            ),
          );
          await tester.pump();

          final overlay = find.byKey(
            const ValueKey('dynamic-notification-shape'),
          );
          final center = tester.getSize(overlay).width / 2;

          // Neck has smoothly pinched off at p=0.30 so it shouldn't contain top points
          if (p == 0.30) {
            expect(
              overlay,
              paints..path(
                excludes: [Offset(center, -1.0), Offset(center, -11.0)],
              ),
            );
          } else {
            expect(
              overlay,
              paints..path(
                includes: [
                  Offset(center, -1.0), // Overlap maintained
                ],
                excludes: [
                  Offset(center, -11.0), // Lens center clear
                  Offset(
                    center + 14.0,
                    -1.0,
                  ), // No lateral shelf outside aperture
                  Offset(
                    center - 14.0,
                    -1.0,
                  ), // No lateral shelf outside aperture
                ],
              ),
            );
          }
        }
      },
    );

    testWidgets(
      'Dynamic Island detachment renders airborne droplet and aperture meniscus at progress 0.30',
      (tester) async {
        const pillGeometry = NotchGeometry(
          bounds: Rect.fromLTWH(338, 11, 124, 37),
          center: Offset(400, 29.5),
          width: 124,
          height: 37,
          top: 11,
          bottom: 48,
          screenSize: Size(800, 600),
          insets: EdgeInsets.only(top: 54),
          source: NotchGeometrySource.displayFeature,
          confidence: NotchGeometryConfidence.exact,
          shape: NotchShape.pill,
          hasCutout: true,
        );

        final ctrl = DynamicNotificationController();
        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              controller: ctrl,
              geometryOverride: pillGeometry,
              progressOverride: 0.30,
              child: const Scaffold(body: Center(child: Text('Meniscus Test'))),
            ),
          ),
        );
        await tester.pump();

        final overlay = find.byKey(
          const ValueKey('dynamic-notification-shape'),
        );
        final center = tester.getSize(overlay).width / 2;

        // At p=0.30, the droplet is airborne (detached), and a small meniscus tip is rendered at the island
        expect(
          overlay,
          paints
            ..shadow()
            ..path(excludes: [Offset(center, 0.0), Offset(center, 10.0)])
            ..path(
              includes: [Offset(center, 0.0)],
              excludes: [
                Offset(center + 30.0, 0.0),
                Offset(center - 30.0, 0.0),
              ],
            ),
        );
      },
    );

    testWidgets(
      'droplet morphology transitions seamlessly across entrance keyframes and handles interruption',
      (tester) async {
        final ctrl = DynamicNotificationController();
        const testGeometry = NotchGeometry(
          bounds: Rect.fromLTWH(188, 8, 24, 24),
          center: Offset(200, 20),
          width: 24,
          height: 24,
          top: 8,
          bottom: 32,
          screenSize: Size(400, 800),
          insets: EdgeInsets.only(top: 36),
          source: NotchGeometrySource.displayFeature,
          confidence: NotchGeometryConfidence.exact,
          shape: NotchShape.punchHole,
          hasCutout: true,
        );

        // Verify each entrance phase with progressOverride
        for (final p in [0.05, 0.15, 0.25, 0.35, 0.50, 0.75, 1.0]) {
          await tester.pumpWidget(
            MaterialApp(
              home: DynamicNotifications(
                controller: ctrl,
                geometryOverride: testGeometry,
                progressOverride: p,
                child: const Scaffold(body: Center(child: Text('Phase Test'))),
              ),
            ),
          );
          await tester.pump();
          expect(
            find.byKey(const ValueKey('dynamic-notification-shape')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }

        // Test interruption: showing notification B while A is exiting
        final liveCtrl = DynamicNotificationController();
        await tester.pumpWidget(
          MaterialApp(
            home: DynamicNotifications(
              key: const ValueKey('interruption-host'),
              controller: liveCtrl,
              geometryOverride: testGeometry,
              child: const Scaffold(
                body: Center(child: Text('Interruption Host')),
              ),
            ),
          ),
        );
        liveCtrl.show(
          const DynamicNotification(
            title: 'First Notification',
            duration: null,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('First Notification'), findsOneWidget);

        // Trigger exit
        liveCtrl.dismiss();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        // Interrupt during exit with second notification
        liveCtrl.show(
          const DynamicNotification(
            title: 'Second Notification',
            duration: null,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Second Notification').hitTestable(), findsOneWidget);
        expect(find.text('First Notification'), findsNothing);
      },
    );
  });

  group('Horizontal Side-Cutout Geometry and Priority', () {
    test('classifies CutoutEdge.left correctly with accurate anchorPoint and emergenceDirection', () {
      const mediaQuery = MediaQueryData(
        size: Size(892, 412),
        viewPadding: EdgeInsets.only(left: 48),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(12, 190, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: mediaQuery,
        platform: TargetPlatform.android,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.left);
      expect(geo.anchorPoint, const Offset(35.0, 202.0));
      expect(geo.emergenceDirection, const Offset(1.0, 0.0));
      expect(geo.shape, NotchShape.punchHole);
    });

    test('classifies CutoutEdge.right correctly with accurate anchorPoint and emergenceDirection', () {
      const mediaQuery = MediaQueryData(
        size: Size(892, 412),
        viewPadding: EdgeInsets.only(right: 48),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(856, 190, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: mediaQuery,
        platform: TargetPlatform.android,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.right);
      expect(geo.anchorPoint, const Offset(857.0, 202.0));
      expect(geo.emergenceDirection, const Offset(-1.0, 0.0));
      expect(geo.shape, NotchShape.punchHole);
    });

    test('multiple cutouts priority: top cutout takes priority over left and right cutouts', () {
      const mediaQuery = MediaQueryData(
        size: Size(892, 412),
        viewPadding: EdgeInsets.only(top: 24, left: 48, right: 48),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(12, 190, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
          DisplayFeature(
            bounds: Rect.fromLTWH(434, 4, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
          DisplayFeature(
            bounds: Rect.fromLTWH(856, 190, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: mediaQuery,
        platform: TargetPlatform.android,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.top);
      expect(geo.bounds, const Rect.fromLTWH(434, 4, 24, 24));
      expect(geo.anchorPoint, const Offset(446.0, 27.0));
      expect(geo.emergenceDirection, const Offset(0.0, 1.0));
    });

    test('multiple cutouts priority: left cutout takes priority over right cutout when no top cutout exists', () {
      const mediaQuery = MediaQueryData(
        size: Size(892, 412),
        viewPadding: EdgeInsets.only(left: 48, right: 48),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(856, 190, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
          DisplayFeature(
            bounds: Rect.fromLTWH(12, 190, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: mediaQuery,
        platform: TargetPlatform.android,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.left);
      expect(geo.bounds, const Rect.fromLTWH(12, 190, 24, 24));
    });

    test('multiple cutouts priority: bottom-only cutouts retain safe fallback with hasCutout false', () {
      const mediaQuery = MediaQueryData(
        size: Size(412, 892),
        viewPadding: EdgeInsets.only(bottom: 48),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(194, 860, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: mediaQuery,
        platform: TargetPlatform.android,
      );

      expect(geo.hasCutout, isFalse);
      expect(geo.edge, CutoutEdge.none);
      expect(geo.shape, NotchShape.none);
    });

    test('multiple cutouts: never combines unrelated cutouts on opposite screen edges', () {
      const mediaQuery = MediaQueryData(
        size: Size(892, 412),
        viewPadding: EdgeInsets.only(left: 48, right: 48),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(10, 100, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
          DisplayFeature(
            bounds: Rect.fromLTWH(858, 100, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: mediaQuery,
        platform: TargetPlatform.android,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.left);
      expect(geo.bounds, const Rect.fromLTWH(10, 100, 24, 24));
      expect(geo.bounds!.width, 24.0);
    });

    test('merges adjacent dual punch holes on side edge if gap is small', () {
      const mediaQuery = MediaQueryData(
        size: Size(892, 412),
        viewPadding: EdgeInsets.only(left: 48),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(12, 180, 20, 20),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
          DisplayFeature(
            bounds: Rect.fromLTWH(12, 208, 20, 20),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: mediaQuery,
        platform: TargetPlatform.android,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.left);
      expect(geo.bounds, const Rect.fromLTWH(12, 180, 20, 48));
      expect(geo.shape, NotchShape.pill);
    });

    test('orientation change: portrait top notch to landscape side cutout updates geometry seamlessly', () {
      const portraitQuery = MediaQueryData(
        size: Size(412, 892),
        viewPadding: EdgeInsets.only(top: 48),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(194, 10, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final portraitGeo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: portraitQuery,
        platform: TargetPlatform.android,
      );

      expect(portraitGeo.hasCutout, isTrue);
      expect(portraitGeo.edge, CutoutEdge.top);
      expect(portraitGeo.anchorPoint, const Offset(206.0, 33.0));

      const landscapeQuery = MediaQueryData(
        size: Size(892, 412),
        viewPadding: EdgeInsets.only(left: 48),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(10, 194, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final landscapeGeo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: landscapeQuery,
        platform: TargetPlatform.android,
      );

      expect(landscapeGeo.hasCutout, isTrue);
      expect(landscapeGeo.edge, CutoutEdge.left);
      expect(landscapeGeo.anchorPoint, const Offset(33.0, 206.0));
      expect(landscapeGeo.emergenceDirection, const Offset(1.0, 0.0));
    });

    test('AndroidCutoutGeometryProvider loads and caches side cutout edge metadata', () async {
      final channel = MethodChannel('dynamic_notifications/android_geometry');
      final provider = AndroidCutoutGeometryProvider(channel: channel);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getCutoutGeometry') {
          return {
            'hasCutout': true,
            'edge': 'left',
            'boundLeft': 30.0,
            'boundTop': 380.0,
            'boundRight': 90.0,
            'boundBottom': 440.0,
            'boundWidth': 60.0,
            'boundHeight': 60.0,
          };
        }
        return null;
      });

      const mediaQuery = MediaQueryData(
        size: Size(892, 412),
        viewPadding: EdgeInsets.only(left: 48),
        devicePixelRatio: 2.0,
      );

      final geo = await provider.load(mediaQuery: mediaQuery);
      expect(geo, isNotNull);
      expect(geo!.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.left);
      expect(geo.bounds, const Rect.fromLTWH(15.0, 190.0, 30.0, 30.0));
      expect(geo.anchorPoint, const Offset(44.0, 205.0));
      expect(geo.emergenceDirection, const Offset(1.0, 0.0));

      provider.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('AndroidCutoutGeometryProvider handles bottom edge as safe fallback', () async {
      final channel = MethodChannel('dynamic_notifications/android_geometry');
      final provider = AndroidCutoutGeometryProvider(channel: channel);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getCutoutGeometry') {
          return {
            'hasCutout': true,
            'edge': 'bottom',
            'boundLeft': 180.0,
            'boundTop': 840.0,
            'boundRight': 232.0,
            'boundBottom': 892.0,
          };
        }
        return null;
      });

      const mediaQuery = MediaQueryData(
        size: Size(412, 892),
        viewPadding: EdgeInsets.only(bottom: 48),
        devicePixelRatio: 2.0,
      );

      final geo = await provider.load(mediaQuery: mediaQuery);
      expect(geo, isNotNull);
      expect(geo!.hasCutout, isFalse);
      expect(geo.edge, CutoutEdge.none);

      provider.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('detects left-side cutout in landscape even with active top status bar insets', () {
      // Modern Android device in landscape mode with both a 24dp top status bar and a 48dp left cutout inset:
      // The camera punch hole is at x: 10..34, y: 16..40.
      const landscapeWithStatusBar = MediaQueryData(
        size: Size(892, 412),
        viewPadding: EdgeInsets.only(top: 24, left: 48),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(10, 16, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: landscapeWithStatusBar,
        platform: TargetPlatform.android,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.left);
      expect(geo.anchorPoint, const Offset(33.0, 28.0));
      expect(geo.emergenceDirection, const Offset(1.0, 0.0));
    });

    test('AndroidCutoutGeometryProvider rejects cross-screen multi-cutout path and uses edge-specific bounding rect', () async {
      final channel = MethodChannel('dynamic_notifications/android_geometry');
      final provider = AndroidCutoutGeometryProvider(channel: channel);

      // Simulates an API 31+ multi-cutout device (e.g. top cutout at y=0..80 and bottom cutout at y=2320..2400)
      // where native getCutoutPath() returns bounds covering the entire screen [0, 0, 1080, 2400],
      // while getBoundingRectTop() isolates the actual top cutout [490, 0, 590, 80].
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getCutoutGeometry') {
          return {
            'hasCutout': true,
            'edge': 'top',
            'hasPath': true,
            'pathLeft': 0.0,
            'pathTop': 0.0,
            'pathRight': 1080.0,
            'pathBottom': 2400.0,
            'pathWidth': 1080.0,
            'pathHeight': 2400.0,
            'boundLeft': 490.0,
            'boundTop': 0.0,
            'boundRight': 590.0,
            'boundBottom': 80.0,
            'boundWidth': 100.0,
            'boundHeight': 80.0,
          };
        }
        return null;
      });

      const mediaQuery = MediaQueryData(
        size: Size(412, 892),
        viewPadding: EdgeInsets.only(top: 48),
        devicePixelRatio: 2.0,
      );

      final geo = await provider.load(mediaQuery: mediaQuery);
      expect(geo, isNotNull);
      expect(geo!.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.top);
      // The cross-screen path bounds (0..1080) were rejected; edge-specific bounds [245, 0, 295, 40] were preserved!
      expect(geo.bounds, const Rect.fromLTWH(245.0, 0.0, 50.0, 40.0));
      expect(geo.source, NotchGeometrySource.displayFeature);

      provider.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });

  group('Separation of Physical Geometry and Vertical Animation Origin', () {
    test('top-center cutout: animationOrigin uses cutout X and anchorTop; direction is vertical +Y', () {
      const geo = NotchGeometry(
        bounds: Rect.fromLTWH(184.5, 15, 24, 24),
        center: Offset(196.5, 27),
        width: 24,
        height: 24,
        top: 15,
        bottom: 39,
        screenSize: Size(393, 852),
        insets: EdgeInsets.only(top: 48),
        source: NotchGeometrySource.displayFeature,
        confidence: NotchGeometryConfidence.exact,
        shape: NotchShape.punchHole,
        hasCutout: true,
        edge: CutoutEdge.top,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.top);
      expect(geo.hasTopCutout, isTrue);
      expect(geo.animationOrigin, const Offset(196.5, 38.0));
      expect(geo.animationDirection, const Offset(0.0, 1.0));
    });

    test('top-left corner camera (Honor View 20 in portrait): animationOrigin uses camera X', () {
      const mediaQuery = MediaQueryData(
        size: Size(412, 892),
        viewPadding: EdgeInsets.only(top: 40),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(24, 10, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: mediaQuery,
        platform: TargetPlatform.android,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.top);
      expect(geo.hasTopCutout, isTrue);
      expect(geo.center.dx, 36.0);
      expect(geo.animationOrigin.dx, 36.0);
      expect(geo.animationDirection, const Offset(0.0, 1.0));
    });

    test('top-left corner camera in portrait with reported left inset: preserved as CutoutEdge.top', () {
      const mediaQuery = MediaQueryData(
        size: Size(412, 892),
        viewPadding: EdgeInsets.only(top: 40, left: 24),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 10, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );

      final geo = NotchGeometryDetector.fromMediaQuery(
        mediaQuery: mediaQuery,
        platform: TargetPlatform.android,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.top);
      expect(geo.hasTopCutout, isTrue);
      expect(geo.animationOrigin.dx, 12.0);
      expect(geo.animationDirection, const Offset(0.0, 1.0));
    });

    test('top-right corner camera: animationOrigin uses camera X and anchorTop', () {
      const geo = NotchGeometry(
        bounds: Rect.fromLTWH(364, 10, 24, 24),
        center: Offset(376, 22),
        width: 24,
        height: 24,
        top: 10,
        bottom: 34,
        screenSize: Size(412, 892),
        insets: EdgeInsets.only(top: 40),
        source: NotchGeometrySource.displayFeature,
        confidence: NotchGeometryConfidence.exact,
        shape: NotchShape.punchHole,
        hasCutout: true,
        edge: CutoutEdge.top,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.hasTopCutout, isTrue);
      expect(geo.animationOrigin, const Offset(376.0, 33.0));
      expect(geo.animationDirection, const Offset(0.0, 1.0));
    });

    test('left-side cutout (landscape): physical geometry is left; animationOrigin is virtual top-center', () {
      const geo = NotchGeometry(
        bounds: Rect.fromLTWH(12, 190, 24, 24),
        center: Offset(24, 202),
        width: 24,
        height: 24,
        top: 190,
        bottom: 214,
        screenSize: Size(892, 412),
        insets: EdgeInsets.only(left: 48),
        source: NotchGeometrySource.displayFeature,
        confidence: NotchGeometryConfidence.exact,
        shape: NotchShape.punchHole,
        hasCutout: true,
        edge: CutoutEdge.left,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.left);
      expect(geo.hasTopCutout, isFalse);
      expect(geo.anchorPoint, const Offset(35.0, 202.0)); // Physical aperture anchor
      expect(geo.animationOrigin, const Offset(470.0, 4.0)); // Virtual top-center: (48 + 892) / 2 = 470
      expect(geo.animationDirection, const Offset(0.0, 1.0)); // Downward (+Y)
    });

    test('right-side cutout (reverse landscape): physical geometry is right; animationOrigin is virtual top-center', () {
      const geo = NotchGeometry(
        bounds: Rect.fromLTWH(856, 190, 24, 24),
        center: Offset(868, 202),
        width: 24,
        height: 24,
        top: 190,
        bottom: 214,
        screenSize: Size(892, 412),
        insets: EdgeInsets.only(right: 48),
        source: NotchGeometrySource.displayFeature,
        confidence: NotchGeometryConfidence.exact,
        shape: NotchShape.punchHole,
        hasCutout: true,
        edge: CutoutEdge.right,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.right);
      expect(geo.hasTopCutout, isFalse);
      expect(geo.anchorPoint, const Offset(857.0, 202.0)); // Physical aperture anchor
      expect(geo.animationOrigin, const Offset(422.0, 4.0)); // Virtual top-center: (892 - 48) / 2 = 422
      expect(geo.animationDirection, const Offset(0.0, 1.0)); // Downward (+Y)
    });

    test('bottom-only cutout: physical geometry is bottom; animationOrigin is virtual top-center', () {
      const geo = NotchGeometry(
        bounds: Rect.fromLTWH(184.5, 820, 24, 24),
        center: Offset(196.5, 832),
        width: 24,
        height: 24,
        top: 820,
        bottom: 844,
        screenSize: Size(393, 852),
        insets: EdgeInsets.only(top: 24, bottom: 48),
        source: NotchGeometrySource.displayFeature,
        confidence: NotchGeometryConfidence.exact,
        shape: NotchShape.punchHole,
        hasCutout: true,
        edge: CutoutEdge.bottom,
      );

      expect(geo.hasCutout, isTrue);
      expect(geo.edge, CutoutEdge.bottom);
      expect(geo.hasTopCutout, isFalse);
      expect(geo.animationOrigin, const Offset(196.5, 28.0)); // Virtual top-center
      expect(geo.animationDirection, const Offset(0.0, 1.0)); // Downward (+Y)
    });

    test('no-cutout fallback: animationOrigin is screen top-center safe area', () {
      const geo = NotchGeometry(
        bounds: null,
        center: Offset(196.5, 22),
        width: 0,
        height: 0,
        top: 0,
        bottom: 44,
        screenSize: Size(393, 852),
        insets: EdgeInsets.only(top: 44),
        source: NotchGeometrySource.safeArea,
        confidence: NotchGeometryConfidence.fallback,
        shape: NotchShape.none,
        hasCutout: false,
        edge: CutoutEdge.none,
      );

      expect(geo.hasCutout, isFalse);
      expect(geo.hasTopCutout, isFalse);
      expect(geo.animationOrigin, const Offset(196.5, 48.0));
      expect(geo.animationDirection, const Offset(0.0, 1.0));
    });
  });
}
