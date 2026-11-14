import 'dart:ui'
    show
        DisplayFeature,
        DisplayFeatureState,
        DisplayFeatureType;

import 'package:dynamic_notifications/dynamic_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotchGeometryDetector', () {
    test('detects centered punch hole when safe area is larger than cutout', () {
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
    });

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

    test('handles physical-to-logical conversions across various DPR values', () {
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
    });

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

    test('gracefully falls back when display features are missing on Android', () {
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
    });

    test('handles device with zero insets (tablet, desktop, or edge-to-edge game)', () {
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
    });

    test('ignores side cutouts in landscape orientation for top drop origin', () {
      // In landscape, phone camera is on the left or right edge
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

      // The side cutout is not on the top edge, so it should not be used as a top drop anchor
      expect(geometry.hasCutout, isFalse);
      expect(geometry.source, NotchGeometrySource.none);
    });

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

    test('ignores corner cutout on side edge when rotated to landscape', () {
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

      expect(geometry.hasCutout, isFalse);
    });

    test('ignores floating side punch hole in landscape with side insets', () {
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

      expect(geometry.hasCutout, isFalse);
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

    testWidgets('adapts seamlessly during dynamic screen rotation and metric change', (
      tester,
    ) async {
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
    });

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
            child: DynamicNotifications(
              controller: controller,
              child: child!,
            ),
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

    testWidgets('allows injecting custom geometryOverride with hasCutout false', (
      tester,
    ) async {
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

      final overlay = find.byKey(const ValueKey('dynamic-notification-shape'));
      // Custom fallback anchorTop (30.0) is respected instead of falling back to default safeTop
      expect(tester.getTopLeft(overlay).dy, 30.0);
    });

    testWidgets('water-drop painter arches upward and overlaps into hardware cutout for punch hole', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewPadding: const EdgeInsets.only(top: 40),
              displayFeatures: const [
                DisplayFeature(
                  bounds: Rect.fromLTWH(388, 8, 24, 24), // center is 400, bottom is 32
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

      final overlay = find.byKey(const ValueKey('dynamic-notification-shape'));
      final center = tester.getSize(overlay).width / 2;

      // Verify that local Y = 1 is covered as before
      // AND verify that local Y = -1 is ALSO covered by the upward curvature into the cutout
      // (eliminating subpixel anti-aliasing seams and circular curvature gap)
      expect(
        overlay,
        paints
          ..path(
            color: Colors.black,
            includes: [
              Offset(center, 1),
              Offset(center, -1),
            ],
            excludes: [
              Offset(center + 36, 1),
              Offset(center + 36, -1),
            ],
          ),
      );
    });

    testWidgets('handles edge-to-edge mode with zero padding and cutout without throwing RenderPadding assertion', (
      tester,
    ) async {
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
    });

    testWidgets('painter clipRect encloses entire tail horizontally for off-center cutout', (
      tester,
    ) async {
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

      final overlay = find.byKey(const ValueKey('dynamic-notification-shape'));
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
    });

    testWidgets('painter does not paint negative screen coordinates when anchorTop is zero', (
      tester,
    ) async {
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

      final overlay = find.byKey(const ValueKey('dynamic-notification-shape'));
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
    });

    testWidgets('respects MediaQuery.padding when viewPadding is zero without cutout', (
      tester,
    ) async {
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

      final overlay = find.byKey(const ValueKey('dynamic-notification-shape'));
      // safeTop should be padding.top + 4 = 36 + 4 = 40.0
      expect(tester.getTopLeft(overlay).dy, 40.0);
    });

    testWidgets('painter clipRect allows shadow headroom above card when anchorTop > 0', (
      tester,
    ) async {
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

      final overlay = find.byKey(const ValueKey('dynamic-notification-shape'));
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
    });

    test('ignores side punch hole in immersive landscape with zero insets', () {
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

      // The cutout is on the side edge (x = 16..40), so it must not be treated as a top drop anchor
      expect(geometry.hasCutout, isFalse);
      expect(geometry.source, NotchGeometrySource.none);
    });

    test('ignores side punch hole in immersive landscape on right edge with zero insets', () {
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

      expect(geometry.hasCutout, isFalse);
      expect(geometry.source, NotchGeometrySource.none);
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
  });
}
