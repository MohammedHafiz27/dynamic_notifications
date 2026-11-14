import 'dart:ui'
    show
        DisplayFeature,
        DisplayFeatureState,
        DisplayFeatureType,
        SemanticsAction;

import 'package:dynamic_notifications/dynamic_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DynamicNotificationController controller;
  late int pageTaps;

  setUp(() {
    controller = DynamicNotificationController();
    pageTaps = 0;
  });

  Future<void> mount(
    WidgetTester tester, {
    EdgeInsets padding = EdgeInsets.zero,
    bool reduceMotion = false,
    double originLift = 0,
    TargetPlatform? platform,
    List<DisplayFeature> displayFeatures = const [],
    TextScaler scaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewPadding: padding,
            displayFeatures: displayFeatures,
            disableAnimations: reduceMotion,
            textScaler: scaler,
          ),
          child: DynamicNotifications(
            controller: controller,
            originLift: originLift,
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => pageTaps++,
              child: const Text('Page action'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('paints a falling drop before expanding into the card', (
    tester,
  ) async {
    await mount(tester, padding: const EdgeInsets.only(top: 40));
    controller.show(const DynamicNotification(title: 'Drop', duration: null));
    await tester.pump();

    final host = tester.widget<DynamicNotifications>(
      find.byType(DynamicNotifications),
    );
    final paint = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter != null &&
          !find
              .ancestor(
                of: find.byWidget(widget),
                matching: find.byWidget(host.child),
              )
              .tryEvaluate(),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final center = tester.getSize(paint).width / 2;
    expect(
      paint,
      paints..path(
        color: Colors.black,
        includes: [Offset(center, 1)],
        excludes: [Offset(center + 36, 1)],
      ),
    );

    await tester.pump(const Duration(milliseconds: 216));
    expect(
      paint,
      paints..path(
        includes: [Offset(center, 48)],
        excludes: [Offset(center, 4), Offset(center + 40, 48)],
      ),
    );
    expect(find.text('Drop').hitTestable(), findsNothing);
    await tester.pumpAndSettle();
    expect(
      paint,
      paints..path(
        color: Colors.white,
        includes: [Offset(center - 100, 48), Offset(center + 100, 48)],
      ),
    );
    expect(find.text('Drop').hitTestable(), findsOneWidget);

    controller.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Drop').hitTestable(), findsNothing);
    expect(
      paint,
      paints..path(
        color: Colors.white,
        includes: [Offset(center, 48)],
        excludes: [Offset(center + 160, 48)],
      ),
    );
    await tester.pump(const Duration(milliseconds: 310));
    expect(
      paint,
      paints..path(
        color: Colors.black,
        includes: [Offset(center, 1)],
        excludes: [Offset(center, 48)],
      ),
    );
    await tester.pumpAndSettle();
    expect(paint, findsNothing);
  });

  testWidgets('joins the iPhone notch and island at their lower edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (safeTop, edge) in [
      (44.0, 29.0),
      (47.0, 31.0),
      (50.0, 36.0),
      (59.0, 48.0),
      (62.0, 50.0),
    ]) {
      await mount(
        tester,
        platform: TargetPlatform.iOS,
        padding: EdgeInsets.only(top: safeTop),
      );
      controller.show(
        const DynamicNotification(title: 'Attached', duration: null),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final overlay = find
          .descendant(
            of: find.byType(DynamicNotifications),
            matching: find.byWidgetPredicate(
              (widget) => widget is CustomPaint && widget.painter != null,
            ),
          )
          .last;
      expect(tester.getTopLeft(overlay).dy, edge);
      final center = tester.getSize(overlay).width / 2;
      expect(
        overlay,
        paints..path(color: Colors.black, includes: [Offset(center, 1)]),
      );

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Attached')).dy, greaterThan(safeTop));
      controller.dismiss();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('starts below an off-center Android camera and lands centered', (
    tester,
  ) async {
    await mount(
      tester,
      platform: TargetPlatform.android,
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      displayFeatures: const [
        DisplayFeature(
          bounds: Rect.fromLTWH(38, 7, 20, 20),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ],
    );
    controller.show(const DynamicNotification(title: 'Camera', duration: null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final overlay = find
        .descendant(
          of: find.byType(DynamicNotifications),
          matching: find.byWidgetPredicate(
            (widget) => widget is CustomPaint && widget.painter != null,
          ),
        )
        .last;
    final position = tester.getTopLeft(overlay);
    expect(position.dy, 26);
    expect(
      overlay,
      paints..path(
        color: Colors.black,
        includes: [Offset(48 - position.dx, 1)],
        excludes: [Offset(tester.getSize(overlay).width / 2, 1)],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Camera')).dy, greaterThan(40));
  });

  testWidgets('manual lift changes only the animation origin', (tester) async {
    Rect? settledCard;
    for (final lift in [0.0, 8.0, 100.0]) {
      await mount(
        tester,
        originLift: lift,
        padding: const EdgeInsets.only(top: 40),
      );
      controller.show(const DynamicNotification(title: 'Lift', duration: null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final paint = find.byKey(const ValueKey('dynamic-notification-shape'));
      expect(tester.getTopLeft(paint).dy, (44 - lift).clamp(0, 44));
      await tester.pumpAndSettle();
      final currentCard = tester.getRect(find.text('Lift'));
      expect(currentCard, settledCard ?? currentCard);
      settledCard = currentCard;
      controller.dismiss();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('starts the default timer after entrance', (tester) async {
    await mount(tester);
    controller.show(const DynamicNotification(title: 'Hello'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 781));
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.text('Hello'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsNothing);
  });

  testWidgets('custom content uses card style and its own duration', (
    tester,
  ) async {
    await mount(tester, reduceMotion: true);
    const background = Color(0xFF23372F);
    var actionTaps = 0;
    controller.show(
      DynamicNotification(
        title: 'Transfer progress',
        duration: const Duration(seconds: 3),
        style: const DynamicNotificationStyle(
          backgroundColor: background,
          borderRadius: 12,
          padding: EdgeInsets.all(8),
        ),
        contentBuilder: (context) => TextButton(
          onPressed: () => actionTaps++,
          child: const Text('View progress'),
        ),
      ),
    );
    await tester.pump();
    final overlay = find.byKey(const ValueKey('dynamic-notification-shape'));
    final size = tester.getSize(overlay);
    expect(
      overlay,
      paints..path(
        color: background,
        includes: [Offset(size.width / 2, size.height / 2)],
        excludes: [const Offset(1, 1)],
      ),
    );
    expect(find.text('Transfer progress'), findsNothing);
    await tester.tap(find.text('View progress'));
    expect(actionTaps, 1);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.text('View progress').hitTestable(), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('View progress'), findsNothing);
  });

  testWidgets('persistent card allows outside touches and taps once', (
    tester,
  ) async {
    await mount(tester);
    var taps = 0;
    controller.show(
      DynamicNotification(
        title: 'Persistent',
        duration: null,
        onTap: () => taps++,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    await tester.tap(find.text('Page action'));
    expect(pageTaps, 1);
    await tester.tap(find.text('Persistent'));
    await tester.tap(find.text('Persistent'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.text('Persistent'), findsNothing);
  });

  testWidgets(
    'upward swipe dismisses and programmatic dismissal clears the queue',
    (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(title: 'Swipe me', duration: null),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('Swipe me'), const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(find.text('Swipe me'), findsNothing);

      controller.show(
        const DynamicNotification(title: 'Active', duration: null),
      );
      await tester.pumpAndSettle();
      controller.show(
        const DynamicNotification(title: 'Pending', duration: null),
      );
      controller.dismiss();
      await tester.pumpAndSettle();
      expect(find.text('Active'), findsNothing);
      expect(find.text('Pending'), findsNothing);
    },
  );

  testWidgets('displays only the latest pending notification', (tester) async {
    await mount(tester);
    controller.show(const DynamicNotification(title: 'First', duration: null));
    await tester.pumpAndSettle();
    controller.show(const DynamicNotification(title: 'Second', duration: null));
    controller.show(const DynamicNotification(title: 'Third', duration: null));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsNothing);
    expect(find.text('Third'), findsOneWidget);
  });

  testWidgets('handles replacement and dismissal before the first frame', (
    tester,
  ) async {
    await mount(tester);
    controller.show(const DynamicNotification(title: 'First'));
    controller.show(const DynamicNotification(title: 'Second', duration: null));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    controller.dismiss();
    await tester.pumpAndSettle();
    controller.show(const DynamicNotification(title: 'Cancelled'));
    controller.dismiss();
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsNothing);
  });

  testWidgets('reduced motion reveals immediately with a dismiss action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await mount(tester, reduceMotion: true);
    controller.show(
      const DynamicNotification(title: 'Accessible', duration: null),
    );
    await tester.pump();
    final node = tester.getSemantics(find.bySemanticsLabel('Accessible'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.dismiss), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.dismiss);
    await tester.pump();
    expect(find.text('Accessible'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'fits safe insets on narrow and rotated screens with larger text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(280, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(
        tester,
        padding: const EdgeInsets.only(top: 62),
        scaler: TextScaler.linear(2),
      );
      const title = 'A longer notification title';
      controller.show(
        const DynamicNotification(
          title: title,
          message: 'A longer message wraps to fit the card.',
          icon: Icons.notifications,
          duration: null,
        ),
      );
      await tester.pumpAndSettle();
      final portrait = tester.getRect(find.text(title));
      expect(portrait.top - 62, inInclusiveRange(26, 54));
      expect(portrait.right, lessThanOrEqualTo(264));

      tester.view.physicalSize = const Size(640, 280);
      await mount(
        tester,
        padding: const EdgeInsets.only(left: 55),
        scaler: TextScaler.linear(2),
      );
      await tester.pumpAndSettle();
      final landscape = tester.getRect(find.text(title));
      expect(landscape.top, lessThan(portrait.top));
      expect(landscape.left, greaterThan(55));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detaches and cancels the timer on unmount', (tester) async {
    await mount(tester);
    controller.show(const DynamicNotification(title: 'Unmount'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
    controller.dismiss();
    expect(tester.takeException(), isNull);
  });
}
