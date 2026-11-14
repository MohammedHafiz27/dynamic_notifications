import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui'
    show
        DisplayFeature,
        DisplayFeatureState,
        DisplayFeatureType,
        SemanticsAction;

import 'package:dynamic_notifications/dynamic_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
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
    GlobalKey? repaintKey,
    Color? scaffoldBackgroundColor,
  }) async {
    final app = MaterialApp(
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
        backgroundColor: scaffoldBackgroundColor,
        body: Center(
          child: TextButton(
            onPressed: () => pageTaps++,
            child: const Text('Page action'),
          ),
        ),
      ),
    );

    if (repaintKey != null) {
      await tester.pumpWidget(RepaintBoundary(key: repaintKey, child: app));
    } else {
      await tester.pumpWidget(app);
    }
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

  testWidgets('normal tap triggers open action and dismisses', (tester) async {
    await mount(tester);
    var opened = 0;
    controller.show(
      DynamicNotification(
        title: 'Tap to Open',
        duration: null,
        onTap: () => opened++,
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.interactionState, NotificationInteractionState.idle);

    await tester.tap(find.text('Tap to Open'));
    expect(controller.interactionState, NotificationInteractionState.opening);
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.text('Tap to Open'), findsNothing);
    expect(controller.interactionState, NotificationInteractionState.idle);
  });

  testWidgets('swipe up beyond threshold dismisses notification without open', (
    tester,
  ) async {
    await mount(tester);
    var opened = 0;
    controller.show(
      DynamicNotification(
        title: 'Swipe Up',
        duration: null,
        onTap: () => opened++,
      ),
    );
    await tester.pumpAndSettle();

    // Drag upward by -50 logical px (threshold is -32)
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Swipe Up')),
    );
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump();
    expect(controller.interactionState, NotificationInteractionState.dragging);
    expect(controller.dragOffset, lessThanOrEqualTo(-32));

    await gesture.up();
    expect(
      controller.interactionState,
      NotificationInteractionState.dismissing,
    );
    await tester.pumpAndSettle();

    expect(opened, 0); // Not opened
    expect(find.text('Swipe Up'), findsNothing); // Dismissed
  });

  testWidgets(
    'fast upward fling dismisses notification even with small distance',
    (tester) async {
      await mount(tester);
      var opened = 0;
      controller.show(
        DynamicNotification(
          title: 'Fling Up',
          duration: null,
          onTap: () => opened++,
        ),
      );
      await tester.pumpAndSettle();

      // Small distance (-15px, below -32 threshold) but fast upward fling
      await tester.fling(find.text('Fling Up'), const Offset(0, -15), 1000.0);
      await tester.pumpAndSettle();

      expect(opened, 0);
      expect(find.text('Fling Up'), findsNothing);
    },
  );

  testWidgets('swipe down beyond opening threshold triggers open action', (
    tester,
  ) async {
    await mount(tester);
    var opened = 0;
    controller.show(
      DynamicNotification(
        title: 'Swipe Down',
        duration: null,
        onTap: () => opened++,
      ),
    );
    await tester.pumpAndSettle();

    // Drag downward by +60 logical px (threshold is 44)
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Swipe Down')),
    );
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(controller.interactionState, NotificationInteractionState.dragging);
    expect(controller.dragOffset, greaterThanOrEqualTo(44));

    await gesture.up();
    expect(controller.interactionState, NotificationInteractionState.opening);
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.text('Swipe Down'), findsNothing);
  });

  testWidgets(
    'drag below dismissal and open thresholds springs back to resting position',
    (tester) async {
      await mount(tester);
      var opened = 0;
      controller.show(
        DynamicNotification(
          title: 'Spring Back',
          duration: null,
          onTap: () => opened++,
        ),
      );
      await tester.pumpAndSettle();
      final initialPos = tester.getTopLeft(find.text('Spring Back'));

      // 1. Drag upward slightly (-12px, below -32 threshold) and release
      final gestureUp = await tester.startGesture(
        tester.getCenter(find.text('Spring Back')),
      );
      await gestureUp.moveBy(const Offset(0, -12));
      await tester.pump();
      expect(controller.dragOffset, -12);

      await gestureUp.up();
      expect(
        controller.interactionState,
        NotificationInteractionState.returning,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130)); // halfway
      expect(controller.dragOffset, greaterThan(-12));
      expect(controller.dragOffset, lessThan(0));

      await tester.pumpAndSettle();
      expect(controller.interactionState, NotificationInteractionState.idle);
      expect(controller.dragOffset, 0);
      expect(tester.getTopLeft(find.text('Spring Back')), initialPos);
      expect(opened, 0);

      // 2. Drag downward slightly (+15px, below +44 threshold) and release
      final gestureDown = await tester.startGesture(
        tester.getCenter(find.text('Spring Back')),
      );
      await gestureDown.moveBy(const Offset(0, 15));
      await tester.pump();
      expect(controller.dragOffset, 15);

      await gestureDown.up();
      expect(
        controller.interactionState,
        NotificationInteractionState.returning,
      );
      await tester.pumpAndSettle();

      expect(controller.interactionState, NotificationInteractionState.idle);
      expect(controller.dragOffset, 0);
      expect(tester.getTopLeft(find.text('Spring Back')), initialPos);
      expect(opened, 0);
      expect(find.text('Spring Back'), findsOneWidget);
    },
  );

  testWidgets(
    'holding notification for extended period does not dismiss and does not trigger tap on release',
    (tester) async {
      await mount(tester);
      var opened = 0;
      controller.show(
        DynamicNotification(
          title: 'Long Hold',
          duration: const Duration(seconds: 2),
          onTap: () => opened++,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Long Hold')),
      );
      // Hold for 4 seconds (longer than duration of 2s and maxTapDuration of 350ms)
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Long Hold'), findsOneWidget);
      expect(opened, 0);

      // Release after long hold
      await gesture.up();
      await tester.pump();
      expect(opened, 0); // Holding must NOT trigger tap!
      expect(find.text('Long Hold'), findsOneWidget); // Still visible

      // Settle and let remaining / grace timer complete
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Long Hold'), findsNothing); // Now cleanly dismissed
    },
  );

  testWidgets(
    'auto-dismiss timer pauses during active drag and resumes after release',
    (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Timer Test',
          duration: Duration(seconds: 2),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 781)); // entrance finishes
      await tester.pump(const Duration(milliseconds: 500)); // 500ms elapsed

      // Start drag at t=500ms
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Timer Test')),
      );
      await gesture.moveBy(const Offset(0, -10)); // small drag
      await tester.pump();
      expect(
        controller.interactionState,
        NotificationInteractionState.dragging,
      );

      // Hold drag for 3000ms (longer than the original 2s timer)
      await tester.pump(const Duration(milliseconds: 3000));
      expect(
        find.text('Timer Test'),
        findsOneWidget,
      ); // MUST NOT DISMISS WHILE DRAGGING!

      // Release below threshold -> springs back
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Timer Test'), findsOneWidget);

      // Timer resumed; check it stays visible for remaining time and then dismisses
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Timer Test'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.text('Timer Test'), findsNothing);
    },
  );

  testWidgets(
    'pointer cancellation returns smoothly to resting position without crash',
    (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(title: 'Cancel Gesture', duration: null),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Cancel Gesture')),
      );
      await gesture.moveBy(const Offset(0, 25));
      await tester.pump();
      expect(controller.dragOffset, 25);

      // Simulate system pointer cancellation
      await gesture.cancel();
      expect(
        controller.interactionState,
        NotificationInteractionState.returning,
      );
      await tester.pumpAndSettle();

      expect(controller.dragOffset, 0);
      expect(controller.interactionState, NotificationInteractionState.idle);
      expect(find.text('Cancel Gesture'), findsOneWidget);
    },
  );

  testWidgets('repeated drag and gestures do not duplicate open callbacks', (
    tester,
  ) async {
    await mount(tester);
    var opened = 0;
    controller.show(
      DynamicNotification(
        title: 'Single Open',
        duration: null,
        onTap: () => opened++,
      ),
    );
    await tester.pumpAndSettle();

    // First downward drag triggers open
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Single Open')),
    );
    await gesture.moveBy(const Offset(0, 60));
    await gesture.up();
    expect(opened, 1);

    // Try tapping or dragging again immediately while exiting
    await tester.tap(find.text('Single Open'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(opened, 1); // Exactly once
    expect(find.text('Single Open'), findsNothing);
  });

  testWidgets(
    'gesture can interrupt spring-back returning animation cleanly without visual jump',
    (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(title: 'Interrupt Return', duration: null),
      );
      await tester.pumpAndSettle();

      // 1. Drag slightly up and release to start spring-back
      final g1 = await tester.startGesture(
        tester.getCenter(find.text('Interrupt Return')),
      );
      await g1.moveBy(const Offset(0, -15));
      await g1.up();
      expect(
        controller.interactionState,
        NotificationInteractionState.returning,
      );

      // Pump partially into the return animation
      await tester.pump(const Duration(milliseconds: 80));
      final interruptedDrag = controller.dragOffset;
      expect(interruptedDrag, lessThan(0));

      // 2. Interrupt spring-back with a new touch and small move
      final g2 = await tester.startGesture(
        tester.getCenter(find.text('Interrupt Return')),
      );
      // Small move upward by 2px
      await g2.moveBy(const Offset(0, -2));
      await tester.pump();

      // Must be contiguous with interrupted position, NOT jump to -2!
      expect(controller.dragOffset, closeTo(interruptedDrag - 2, 0.5));

      await g2.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'multi-pointer interaction does not corrupt drag tracking or cause coordinate jumps',
    (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(title: 'Multi Pointer', duration: null),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.text('Multi Pointer'));
      // Finger 1 touches left side of card
      final g1 = await tester.startGesture(center - const Offset(60, 0));
      await tester.pump();
      expect(controller.interactionState, NotificationInteractionState.holding);

      // Finger 2 touches right side of card (5px lower)
      final g2 = await tester.startGesture(center + const Offset(60, 5));
      await tester.pump();

      // Finger 1 moves down by 10px
      await g1.moveBy(const Offset(0, 10));
      await tester.pump();

      // Drag should track primary pointer (approx 10px), NOT jump due to finger 2's start position!
      expect(controller.dragOffset, closeTo(10, 1.0));

      // Finger 2 lifts
      await g2.up();
      await tester.pump();
      // Primary gesture should still be active
      expect(
        controller.interactionState,
        NotificationInteractionState.dragging,
      );

      // Finger 1 moves further down to 50px (exceeding openThreshold of 44)
      await g1.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(controller.dragOffset, closeTo(50, 1.0));

      await g1.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'releasing towards origin with opposite velocity does not trigger accidental open or dismiss',
    (tester) async {
      await mount(tester);
      var opened = 0;
      controller.show(
        DynamicNotification(
          title: 'Direction Independence',
          duration: null,
          onTap: () => opened++,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Drag upward slightly (-15px) and release with downward velocity (+500 px/s)
      final center = tester.getCenter(find.text('Direction Independence'));
      final g1 = await tester.startGesture(center);
      await g1.moveBy(const Offset(0, -15));
      await tester.pump();
      expect(controller.dragOffset, -15);

      // Move downward towards resting position and release with downward velocity
      await g1.moveBy(
        const Offset(0, 5),
        timeStamp: const Duration(milliseconds: 10),
      );
      await g1.up(timeStamp: const Duration(milliseconds: 20));

      // MUST NOT trigger open action! It should spring back to origin
      expect(opened, 0);
      expect(
        controller.interactionState,
        NotificationInteractionState.returning,
      );
      await tester.pumpAndSettle();
      expect(find.text('Direction Independence'), findsOneWidget);

      // 2. Drag downward slightly (+15px) and release with upward velocity (-500 px/s)
      final g2 = await tester.startGesture(center);
      await g2.moveBy(const Offset(0, 15));
      await tester.pump();
      expect(controller.dragOffset, 15);

      // Move upward towards resting position and release with upward velocity
      await g2.moveBy(
        const Offset(0, -5),
        timeStamp: const Duration(milliseconds: 10),
      );
      await g2.up(timeStamp: const Duration(milliseconds: 20));

      // MUST NOT trigger dismiss! It should spring back to origin
      expect(
        controller.interactionState,
        NotificationInteractionState.returning,
      );
      await tester.pumpAndSettle();
      expect(find.text('Direction Independence'), findsOneWidget);
    },
  );

  testWidgets(
    'holding without moving pauses the auto-dismiss timer immediately on pointer down',
    (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Hold Timer Pause',
          duration: Duration(seconds: 2),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 781)); // entrance finishes
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // 500ms elapsed, 1500ms remaining

      // Touch down and HOLD STILL without any movement
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Hold Timer Pause')),
      );
      await tester.pump();
      expect(controller.interactionState, NotificationInteractionState.holding);

      // Hold still for 3000ms (exceeding initial 2s timer)
      await tester.pump(const Duration(milliseconds: 3000));
      expect(find.text('Hold Timer Pause'), findsOneWidget);

      // Release finger
      await gesture.up();
      await tester.pump();
      expect(controller.interactionState, NotificationInteractionState.idle);

      // Card must still be visible and idle after 600ms (1500ms remaining - 600ms = 900ms remaining)
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.interactionState, NotificationInteractionState.idle);
      expect(find.text('Hold Timer Pause'), findsOneWidget);

      // After another 1000ms (total 1600ms > 1500ms), it should dismiss cleanly
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
      expect(find.text('Hold Timer Pause'), findsNothing);
    },
  );

  // =========================================================================
  // Regression suite: Card background visibility and synchronization during drag
  // =========================================================================

  testWidgets(
    '1. Initial notification rendering: card background and content are fully visible and resting',
    (tester) async {
      await mount(tester, padding: const EdgeInsets.only(top: 40));
      controller.show(
        const DynamicNotification(
          title: 'Initial Rendering',
          message: 'Resting state check',
          duration: null,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.interactionState, NotificationInteractionState.idle);
      expect(controller.dragOffset, 0.0);

      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      expect(shape, findsOneWidget);

      final shapeSize = tester.getSize(shape);
      final center = shapeSize.width / 2;

      // clipRect encloses the card and its bottom shadow (at least size.height + 24)
      expect(
        shape,
        paints..something((Symbol method, List<dynamic> args) {
          if (method == #clipRect) {
            final rect = args[0] as Rect;
            return rect.bottom >= shapeSize.height + 24.0;
          }
          return false;
        }),
      );

      // Painter draws white card path that includes the vertical center of the card
      expect(
        shape,
        paints..path(
          color: Colors.white,
          includes: [Offset(center, shapeSize.height / 2)],
        ),
      );

      // Text is rendered and completely on screen
      expect(find.text('Initial Rendering'), findsOneWidget);
      expect(find.text('Resting state check'), findsOneWidget);
    },
  );

  testWidgets(
    '2. Partial downward drag: card background remains fully visible and moves with content',
    (tester) async {
      await mount(tester, padding: const EdgeInsets.only(top: 40));
      controller.show(
        const DynamicNotification(
          title: 'Partial Drag',
          message: 'Drag down 25px',
          duration: null,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final initialTextPos = tester.getTopLeft(find.text('Partial Drag'));
      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      final shapeSize = tester.getSize(shape);
      final center = shapeSize.width / 2;

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Partial Drag')),
      );
      await gesture.moveBy(const Offset(0, 25));
      await tester.pump();

      expect(
        controller.interactionState,
        NotificationInteractionState.dragging,
      );
      expect(controller.dragOffset, 25.0);

      // Content text moved down by exactly 25px
      final draggedTextPos = tester.getTopLeft(find.text('Partial Drag'));
      expect(draggedTextPos.dy, closeTo(initialTextPos.dy + 25.0, 0.5));

      // clipRect bottom expanded to at least shapeSize.height + 25 + 24
      expect(
        shape,
        paints..something((Symbol method, List<dynamic> args) {
          if (method == #clipRect) {
            final rect = args[0] as Rect;
            return rect.bottom >= shapeSize.height + 25.0 + 24.0;
          }
          return false;
        }),
      );

      // The card background path includes the dragged center point (shapeSize.height / 2 + 25)
      expect(
        shape,
        paints..path(
          color: Colors.white,
          includes: [Offset(center, shapeSize.height / 2 + 25.0)],
        ),
      );

      // Release gesture: below threshold (44), so springs back
      await gesture.up();
      expect(
        controller.interactionState,
        NotificationInteractionState.returning,
      );
      await tester.pumpAndSettle();
      expect(controller.interactionState, NotificationInteractionState.idle);
      expect(controller.dragOffset, 0.0);
    },
  );

  testWidgets(
    '3. Maximum allowed drag: card background extends to max downward limit without clipping',
    (tester) async {
      await mount(tester, padding: const EdgeInsets.only(top: 40));
      controller.show(
        const DynamicNotification(
          title: 'Max Drag',
          message: 'Dragged to maximum threshold',
          duration: null,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final initialTextPos = tester.getTopLeft(find.text('Max Drag'));
      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      final shapeSize = tester.getSize(shape);
      final center = shapeSize.width / 2;

      // Drag downward by 160px (exceeding default maxDownwardDrag of 120px)
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Max Drag')),
      );
      await gesture.moveBy(const Offset(0, 160));
      await tester.pump();

      // Drag is clamped to maxDownwardDrag (120px)
      expect(controller.dragOffset, 120.0);
      expect(
        controller.interactionState,
        NotificationInteractionState.dragging,
      );

      // Content moved down by exactly 120px
      final draggedTextPos = tester.getTopLeft(find.text('Max Drag'));
      expect(draggedTextPos.dy, closeTo(initialTextPos.dy + 120.0, 0.5));

      // clipRect bottom accommodates the full 120px drag displacement + 24px shadow margin
      expect(
        shape,
        paints..something((Symbol method, List<dynamic> args) {
          if (method == #clipRect) {
            final rect = args[0] as Rect;
            return rect.bottom >= shapeSize.height + 120.0 + 24.0;
          }
          return false;
        }),
      );

      // The card background path is fully rendered at Y = shapeSize.height / 2 + 120
      expect(
        shape,
        paints..path(
          color: Colors.white,
          includes: [Offset(center, shapeSize.height / 2 + 120.0)],
        ),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '4. Downward drag that triggers opening: transitions coherently with background intact',
    (tester) async {
      await mount(tester, padding: const EdgeInsets.only(top: 40));
      var opened = 0;
      controller.show(
        DynamicNotification(
          title: 'Open Drag',
          message: 'Triggers open callback',
          duration: null,
          onTap: () => opened++,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      final shapeSize = tester.getSize(shape);
      final center = shapeSize.width / 2;

      // Drag downward by 60px (> openThreshold 44px)
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Open Drag')),
      );
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();

      expect(controller.dragOffset, 60.0);
      expect(
        controller.interactionState,
        NotificationInteractionState.dragging,
      );

      // Card background is fully present and visible at drag = 60
      expect(
        shape,
        paints..path(
          color: Colors.white,
          includes: [Offset(center, shapeSize.height / 2 + 60.0)],
        ),
      );

      // Release triggers opening
      await gesture.up();
      expect(controller.interactionState, NotificationInteractionState.opening);
      expect(opened, 1);

      // Advance halfway through reverse exit animation
      await tester.pump(const Duration(milliseconds: 150));
      // Card background painter clipRect continues to cover the transitioning card
      expect(
        shape,
        paints..something((Symbol method, List<dynamic> args) {
          if (method == #clipRect) {
            final rect = args[0] as Rect;
            return rect.bottom >= shapeSize.height;
          }
          return false;
        }),
      );

      await tester.pumpAndSettle();
      expect(find.text('Open Drag'), findsNothing);
    },
  );

  testWidgets(
    '5. Background visibility throughout downward drag: pixels behind text remain white over dark surface',
    (tester) async {
      final repaintKey = GlobalKey();
      await mount(
        tester,
        padding: const EdgeInsets.only(top: 40),
        repaintKey: repaintKey,
        scaffoldBackgroundColor: const Color(0xFF101010),
      );

      controller.show(
        const DynamicNotification(
          title: 'Pixel White Card Check',
          message: 'Ensures no transparency or detachment',
          duration: null,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Pixel White Card Check')),
      );

      // Helper to sample pixel color at global coordinates
      Future<Color> samplePixel(Offset pos) async {
        final boundary =
            repaintKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final ui.Image image = await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1.0),
        ) as ui.Image;
        final byteData = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ) as ByteData;
        final x = pos.dx.round().clamp(0, image.width - 1);
        final y = pos.dy.round().clamp(0, image.height - 1);
        final offset = (y * image.width + x) * 4;
        return Color.fromARGB(
          byteData.getUint8(offset + 3),
          byteData.getUint8(offset),
          byteData.getUint8(offset + 1),
          byteData.getUint8(offset + 2),
        );
      }

      // Check at resting position (drag = 0)
      final shapeRect = tester.getRect(
        find.byKey(const ValueKey('dynamic-notification-shape')),
      );
      final textRect = tester.getRect(find.text('Pixel White Card Check'));
      final initialCenter = textRect.center;
      // Sample below the text inside the card padding
      final sampleY = shapeRect.bottom - 15;
      final color0 = await samplePixel(Offset(shapeRect.center.dx, sampleY));
      expect(color0.r, greaterThan(0.94));
      expect(color0.g, greaterThan(0.94));
      expect(color0.b, greaterThan(0.94));

      // Drag downward in steps: 30px, 60px, 90px, and maximum 120px
      for (final step in [30.0, 60.0, 90.0, 120.0]) {
        await gesture.moveTo(initialCenter + Offset(0, step));
        await tester.pump();

        // Sample card background below text, offset by drag step
        final samplePos = Offset(shapeRect.center.dx, sampleY + step);
        final color = await samplePixel(samplePos);

        // MUST be white surface, NOT dark background (0xFF101010)!
        expect(
          color.r,
          greaterThan(0.94),
          reason: 'Card background became transparent at drag=$step',
        );
        expect(color.g, greaterThan(0.94));
        expect(color.b, greaterThan(0.94));

        // Also sample card background horizontally adjacent to text at the same Y
        final textSamplePos = Offset(
          shapeRect.right - 25,
          textRect.center.dy + step,
        );
        final textColor = await samplePixel(textSamplePos);
        expect(
          textColor.r,
          greaterThan(0.94),
          reason: 'Card background next to text missing at drag=$step',
        );
      }

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '6. Background and content position synchronization: 1-to-1 tracking during drag',
    (tester) async {
      await mount(tester, padding: const EdgeInsets.only(top: 40));
      controller.show(
        const DynamicNotification(
          title: 'Sync Check',
          message: 'Tracking alignment test',
          duration: null,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final initialPos = tester.getTopLeft(find.text('Sync Check'));
      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      final shapeSize = tester.getSize(shape);
      final center = shapeSize.width / 2;
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Sync Check')),
      );

      final displacements = [15.0, 35.0, 55.0, 75.0, 95.0, 115.0];
      for (final dy in displacements) {
        await gesture.moveTo(
          tester.getCenter(find.text('Sync Check')) +
              Offset(0, dy - controller.dragOffset),
        );
        await tester.pump();

        expect(controller.dragOffset, closeTo(dy, 0.5));
        final currentPos = tester.getTopLeft(find.text('Sync Check'));
        // Content position moves with exact 1:1 displacement
        expect(
          currentPos.dy - initialPos.dy,
          closeTo(controller.dragOffset, 0.5),
        );

        // Background painter geometry tracks by the exact same drag offset
        expect(
          shape,
          paints..path(
            color: Colors.white,
            includes: [
              Offset(center, shapeSize.height / 2 + controller.dragOffset),
              Offset(center, shapeSize.height + controller.dragOffset - 12),
            ],
          ),
        );
      }

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '7. No detached text after the open transition: card background envelops text during exit',
    (tester) async {
      await mount(tester, padding: const EdgeInsets.only(top: 40));
      var opened = false;
      controller.show(
        DynamicNotification(
          title: 'Detachment Prevention',
          message: 'Exit transition test',
          duration: null,
          onTap: () => opened = true,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      final shapeSize = tester.getSize(shape);

      // Drag downward to trigger open
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Detachment Prevention')),
      );
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
      await gesture.up();

      expect(opened, true);
      expect(controller.interactionState, NotificationInteractionState.opening);

      // Verify throughout the exit frames that the painter clipRect covers the card
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        if (find.text('Detachment Prevention').tryEvaluate()) {
          final shapeTopLeft = tester.getTopLeft(shape);
          final textCenter = tester.getCenter(
            find.text('Detachment Prevention'),
          );
          final localTextY = textCenter.dy - shapeTopLeft.dy;
          expect(
            shape,
            paints
              ..something((Symbol method, List<dynamic> args) {
                if (method == #clipRect) {
                  final rect = args[0] as Rect;
                  return rect.bottom >= shapeSize.height &&
                      rect.bottom >= localTextY;
                }
                return false;
              })
              ..path(
                color: Colors.white,
                includes: [Offset(shapeSize.width / 2, localTextY)],
              ),
          );
        }
      }

      await tester.pumpAndSettle();
      expect(find.text('Detachment Prevention'), findsNothing);
    },
  );

  testWidgets(
    '8. No duplicate open callbacks during drag release or subsequent rapid gestures',
    (tester) async {
      await mount(tester, padding: const EdgeInsets.only(top: 40));
      var openCount = 0;
      controller.show(
        DynamicNotification(
          title: 'Duplicate Guard',
          message: 'Rapid interaction test',
          duration: null,
          onTap: () => openCount++,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Swipe down to open
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Duplicate Guard')),
      );
      await gesture.moveBy(const Offset(0, 55));
      await tester.pump();
      await gesture.up();

      expect(openCount, 1);
      expect(controller.interactionState, NotificationInteractionState.opening);

      // Attempt second tap immediately while exiting
      if (find.text('Duplicate Guard').tryEvaluate()) {
        await tester.tap(find.text('Duplicate Guard'), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Attempt controller dismiss / open
      controller.dismiss();
      await tester.pumpAndSettle();

      // Callback MUST be fired exactly once
      expect(openCount, 1);
    },
  );

  testWidgets(
    '9. Pointer cancellation and interrupted gestures smoothly return without detached elements',
    (tester) async {
      await mount(tester, padding: const EdgeInsets.only(top: 40));
      var opened = 0;
      controller.show(
        DynamicNotification(
          title: 'Cancel Interruption',
          message: 'Cancel and re-touch test',
          duration: null,
          onTap: () => opened++,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final initialPos = tester.getTopLeft(find.text('Cancel Interruption'));

      // Drag downward 40px
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Cancel Interruption')),
      );
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(controller.dragOffset, 40.0);

      // Cancel pointer (e.g. system alert, palm rejection)
      await gesture.cancel();
      await tester.pump();
      expect(
        controller.interactionState,
        NotificationInteractionState.returning,
      );

      // Let it spring back partially
      await tester.pump(const Duration(milliseconds: 80));
      expect(controller.dragOffset, greaterThan(0));
      expect(controller.dragOffset, lessThan(40));

      // Re-touch to interrupt spring-back
      final gesture2 = await tester.startGesture(
        tester.getCenter(find.text('Cancel Interruption')),
      );
      await tester.pump();
      expect(controller.interactionState, NotificationInteractionState.holding);

      // Release without dragging
      await gesture2.up();
      await tester.pumpAndSettle();

      expect(controller.interactionState, NotificationInteractionState.idle);
      expect(controller.dragOffset, 0.0);
      expect(tester.getTopLeft(find.text('Cancel Interruption')), initialPos);
      expect(opened, 0);
    },
  );

  testWidgets(
    '10. Downward drag with anchorTop == 0 honors screen top boundary and expands clipBottom',
    (tester) async {
      // Zero safe area padding (e.g. tablet, desktop, or landscape)
      await mount(tester, padding: EdgeInsets.zero, originLift: 4.0);
      controller.show(
        const DynamicNotification(
          title: 'Zero Anchor Downward',
          message: 'Downward drag zero anchor test',
          duration: null,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      final shapeSize = tester.getSize(shape);
      final center = shapeSize.width / 2;

      // Drag downward by 50px
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Zero Anchor Downward')),
      );
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();

      expect(controller.dragOffset, 50.0);
      expect(
        controller.interactionState,
        NotificationInteractionState.dragging,
      );

      // Verify that clipRect top honors screen boundary (>= 0.0) while clipBottom expands
      expect(
        shape,
        paints..something((Symbol method, List<dynamic> args) {
          if (method == #clipRect) {
            final rect = args[0] as Rect;
            return rect.top >= 0.0 &&
                rect.bottom >= shapeSize.height + 50.0 + 24.0;
          }
          return false;
        }),
      );

      // Verify card background path includes the center point displaced downward
      expect(
        shape,
        paints..path(
          color: Colors.white,
          includes: [Offset(center, shapeSize.height / 2 + 50.0)],
        ),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '11. Upward drag on devices with safe area expands clipTop towards screenTop',
    (tester) async {
      await mount(tester, padding: const EdgeInsets.only(top: 40));
      controller.show(
        const DynamicNotification(
          title: 'Safe Area Upward Drag',
          message: 'Drag upward within safe area',
          duration: null,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      final shapeSize = tester.getSize(shape);
      final center = shapeSize.width / 2;

      // Drag upward by -40px
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Safe Area Upward Drag')),
      );
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();

      expect(controller.dragOffset, -40.0);

      // clipRect top accommodates upward displacement without clipping card
      expect(
        shape,
        paints..something((Symbol method, List<dynamic> args) {
          if (method == #clipRect) {
            final rect = args[0] as Rect;
            return rect.top <= -40.0;
          }
          return false;
        }),
      );

      // Card background is fully rendered at Y = shapeSize.height / 2 - 40.0
      expect(
        shape,
        paints..path(
          color: Colors.white,
          includes: [Offset(center, shapeSize.height / 2 - 40.0)],
        ),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '12. Horizontal swipe across notification does not trigger open action',
    (tester) async {
      await mount(tester, padding: const EdgeInsets.only(top: 40));
      var opened = 0;
      controller.show(
        DynamicNotification(
          title: 'Horizontal Swipe',
          message: 'Should not trigger open',
          duration: null,
          onTap: () => opened++,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Swipe horizontally by 60px with minimal vertical movement
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Horizontal Swipe')),
      );
      await gesture.moveBy(const Offset(60, 2));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(opened, 0, reason: 'Horizontal swipe must not trigger tap/open');
      expect(find.text('Horizontal Swipe'), findsOneWidget);
    },
  );

  testWidgets(
    '13. Downward drag with custom contentBuilder preserves white card background and moves together',
    (tester) async {
      await mount(tester, padding: const EdgeInsets.only(top: 40));
      controller.show(
        DynamicNotification(
          title: 'Custom Content Builder',
          duration: null,
          contentBuilder: (context) => const SizedBox(
            height: 50,
            child: Center(child: Text('Custom Body Text')),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final initialPos = tester.getTopLeft(find.text('Custom Body Text'));
      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      final shapeSize = tester.getSize(shape);
      final center = shapeSize.width / 2;

      // Drag downward 50px
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Custom Body Text')),
      );
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();

      expect(controller.dragOffset, 50.0);
      final currentPos = tester.getTopLeft(find.text('Custom Body Text'));
      expect(currentPos.dy - initialPos.dy, closeTo(50.0, 0.5));

      // White card background is present at the dragged position
      expect(
        shape,
        paints..path(
          color: Colors.white,
          includes: [Offset(center, shapeSize.height / 2 + 50.0)],
        ),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  group('Interactive Swipe-Up Reverse Morph Into Native Notch / Dynamic Island', () {
    testWidgets('1. Initial expanded state: morphProgress == 0.0 and card full width', (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Morph Test Initial',
          message: 'Fully expanded card',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.morphProgress, 0.0);
      expect(controller.dragOffset, 0.0);
      expect(controller.interactionState, NotificationInteractionState.idle);

      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      final shapeSize = tester.getSize(shape);
      expect(shapeSize.width, greaterThan(300.0));
      expect(find.text('Morph Test Initial').hitTestable(), findsOneWidget);
    });

    testWidgets('2. Small upward drag: morphProgress ~ 0.25, content visible, width begins contracting', (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Small Morph Drag',
          message: 'Progress 0.25',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Small Morph Drag')),
      );
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();

      expect(controller.dragOffset, -20.0);
      expect(controller.morphProgress, closeTo(0.25, 0.01));
      expect(controller.interactionState, NotificationInteractionState.dragging);
      expect(find.text('Small Morph Drag').hitTestable(), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('3. Medium upward drag: morphProgress == 0.50, content opacity is 0.0', (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Medium Morph Drag',
          message: 'Progress 0.50',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Medium Morph Drag')),
      );
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();

      expect(controller.dragOffset, -40.0);
      expect(controller.morphProgress, closeTo(0.50, 0.01));
      // Content has faded out completely (contentOpacity <= 0)
      expect(find.text('Medium Morph Drag').hitTestable(), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('4. Near-complete upward morph: morphProgress == 0.85, compact pill near anchor', (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Near Complete Drag',
          message: 'Progress 0.85',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Near Complete Drag')),
      );
      await gesture.moveBy(const Offset(0, -68));
      await tester.pump();

      expect(controller.dragOffset, -68.0);
      expect(controller.morphProgress, closeTo(0.85, 0.01));
      expect(find.text('Near Complete Drag').hitTestable(), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('5. Complete upward morph: reaches maxUpwardDrag (1.0) and completes exit on release', (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Max Morph Drag',
          message: 'Progress 1.0',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Max Morph Drag')),
      );
      await gesture.moveBy(const Offset(0, -85)); // exceeds -80 maxUpwardDrag
      await tester.pump();

      expect(controller.dragOffset, -80.0);
      expect(controller.morphProgress, 1.0);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.interactionState, NotificationInteractionState.idle);
      expect(find.text('Max Morph Drag'), findsNothing);
    });

    testWidgets('6. Real-time direction reversal: upward drag reverses downward smoothly restoring card and content', (tester) async {
      await mount(tester);
      var opened = 0;
      controller.show(
        DynamicNotification(
          title: 'Reversal Drag',
          message: 'Real-time recovery',
          duration: null,
          onTap: () => opened++,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Reversal Drag')),
      );

      // 1. Drag upward by -45px (content fades)
      await gesture.moveBy(const Offset(0, -45));
      await tester.pump();
      expect(controller.dragOffset, -45.0);
      expect(controller.morphProgress, closeTo(45.0 / 80.0, 0.01));
      expect(find.text('Reversal Drag').hitTestable(), findsNothing);

      // 2. Reverse direction downward to +20px without releasing pointer
      await gesture.moveBy(const Offset(0, 65)); // -45 + 65 = +20
      await tester.pump();
      expect(controller.dragOffset, 20.0);
      expect(controller.morphProgress, 0.0);
      expect(find.text('Reversal Drag').hitTestable(), findsOneWidget);

      // 3. Move back to origin 0px and release
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      expect(controller.dragOffset, 0.0);
      expect(controller.morphProgress, 0.0);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(opened, 0);
      expect(find.text('Reversal Drag'), findsOneWidget);
    });

    testWidgets('7. Incomplete upward drag springs back to resting position without dismissing', (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Spring Back Morph',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      // Drag upward by -16px (below -32 threshold)
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Spring Back Morph')),
      );
      await gesture.moveBy(const Offset(0, -16));
      await tester.pump();
      expect(controller.dragOffset, -16.0);

      await gesture.up();
      expect(controller.interactionState, NotificationInteractionState.returning);

      await tester.pumpAndSettle();
      expect(controller.interactionState, NotificationInteractionState.idle);
      expect(controller.dragOffset, 0.0);
      expect(controller.morphProgress, 0.0);
      expect(find.text('Spring Back Morph'), findsOneWidget);
    });

    testWidgets('8. Fast upward flick triggers reverse morph dismissal even from small distance', (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Flick Dismiss',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      // Small drag -10px, but fast upward fling
      await tester.fling(find.text('Flick Dismiss'), const Offset(0, -10), 1000.0);
      await tester.pumpAndSettle();

      expect(find.text('Flick Dismiss'), findsNothing);
      expect(controller.interactionState, NotificationInteractionState.idle);
    });

    testWidgets('9. Slow upward drag crossing threshold dismisses into notch', (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Slow Threshold Drag',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Slow Threshold Drag')),
      );
      // Drag past -32 threshold (e.g. -40px) slowly
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(controller.dragOffset, -40.0);

      await gesture.up();
      expect(controller.interactionState, NotificationInteractionState.dismissing);

      await tester.pumpAndSettle();
      expect(find.text('Slow Threshold Drag'), findsNothing);
    });

    testWidgets('10. Pointer cancellation during morph returns safely to resting state', (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Cancel Morph',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Cancel Morph')),
      );
      await gesture.moveBy(const Offset(0, -35));
      await tester.pump();
      expect(controller.dragOffset, -35.0);

      await gesture.cancel();
      await tester.pump();
      expect(controller.interactionState, NotificationInteractionState.returning);

      await tester.pumpAndSettle();
      expect(controller.interactionState, NotificationInteractionState.idle);
      expect(controller.dragOffset, 0.0);
      expect(find.text('Cancel Morph'), findsOneWidget);
    });

    testWidgets('11. No detached text: text stays strictly inside card bounds throughout morph', (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Attached Content Morph',
          message: 'Guaranteed no floating text',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      final initialShapeRect = tester.getRect(shape);
      final textRect = tester.getRect(find.text('Attached Content Morph'));

      expect(textRect.top, greaterThanOrEqualTo(initialShapeRect.top));
      expect(textRect.bottom, lessThanOrEqualTo(initialShapeRect.bottom));

      // Drag upward -20px (morphProgress = 0.25)
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Attached Content Morph')),
      );
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();

      // At -20px, text moved up by -20px and remains inside
      final draggedTextRect = tester.getRect(find.text('Attached Content Morph'));
      expect(draggedTextRect.center.dy, closeTo(textRect.center.dy - 20.0, 1.0));

      // Drag to -45px (morphProgress = 0.56, opacity becomes 0.0)
      await gesture.moveBy(const Offset(0, -25));
      await tester.pump();
      expect(find.text('Attached Content Morph').hitTestable(), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('12. Background remains attached during morph at multiple progress steps', (tester) async {
      await mount(tester);
      controller.show(
        const DynamicNotification(
          title: 'Background Attachment',
          message: 'Continuous surface',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      final shapeSize = tester.getSize(shape);
      final center = shapeSize.width / 2;

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Background Attachment')),
      );

      // Step at -20px
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      expect(
        shape,
        paints..path(
          color: Colors.white,
          includes: [Offset(center, shapeSize.height / 2 - 20.0)],
        ),
      );

      // Step at -35px
      await gesture.moveBy(const Offset(0, -15));
      await tester.pump();
      expect(
        shape,
        paints..path(
          color: Colors.white,
          includes: [Offset(center, shapeSize.height / 2 - 35.0)],
        ),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('13. Dismissal does not trigger onTap open callback', (tester) async {
      await mount(tester);
      var openCalls = 0;
      controller.show(
        DynamicNotification(
          title: 'Dismissal No Open',
          duration: null,
          onTap: () => openCalls++,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Dismissal No Open')),
      );
      await gesture.moveBy(const Offset(0, -45));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(openCalls, 0);
      expect(find.text('Dismissal No Open'), findsNothing);
    });

    testWidgets('14. Downward open behavior remains completely intact with reverse morph enabled', (tester) async {
      await mount(tester);
      var openCalls = 0;
      controller.show(
        DynamicNotification(
          title: 'Downward Open Intact',
          duration: null,
          onTap: () => openCalls++,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Downward Open Intact')),
      );
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
      expect(controller.dragOffset, 50.0);
      expect(controller.morphProgress, 0.0);

      await gesture.up();
      expect(controller.interactionState, NotificationInteractionState.opening);
      await tester.pumpAndSettle();

      expect(openCalls, 1);
      expect(find.text('Downward Open Intact'), findsNothing);
    });

    testWidgets('15. Tap-to-open remains completely intact without dragging', (tester) async {
      await mount(tester);
      var openCalls = 0;
      controller.show(
        DynamicNotification(
          title: 'Tap Open Intact',
          duration: null,
          onTap: () => openCalls++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tap Open Intact'));
      await tester.pumpAndSettle();

      expect(openCalls, 1);
      expect(find.text('Tap Open Intact'), findsNothing);
    });

    testWidgets('16. Long-press / hold behavior remains intact and pauses auto-dismiss timer', (tester) async {
      await mount(tester);
      var openCalls = 0;
      controller.show(
        DynamicNotification(
          title: 'Hold Intact',
          duration: const Duration(seconds: 1),
          onTap: () => openCalls++,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Hold Intact')),
      );
      expect(controller.interactionState, NotificationInteractionState.holding);

      // Hold for 1500ms (exceeding 1000ms duration)
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('Hold Intact'), findsOneWidget); // Did not auto-dismiss!

      // Release without moving: recognized as hold, does not trigger tap
      await gesture.up();
      await tester.pump();
      expect(openCalls, 0);

      // After release, remaining timer expires and dismisses
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Hold Intact'), findsNothing);
    });

    testWidgets('17. Notch geometry alignment on asymmetric off-center punch hole', (tester) async {
      await mount(
        tester,
        platform: TargetPlatform.android,
        padding: const EdgeInsets.only(top: 40, bottom: 20),
        displayFeatures: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(48, 8, 24, 24),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );
      controller.show(
        const DynamicNotification(
          title: 'Off Center Notch',
          message: 'Morph to camera at x=60',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Off Center Notch')),
      );

      // Drag up by -50px
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();

      expect(controller.morphProgress, closeTo(50.0 / 80.0, 0.01));

      final shape = find.byKey(const ValueKey('dynamic-notification-shape'));
      expect(shape, findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('18. iOS safe-area fallback geometry handles reverse morph smoothly', (tester) async {
      await mount(
        tester,
        padding: const EdgeInsets.only(top: 48),
      );
      controller.show(
        const DynamicNotification(
          title: 'iOS Fallback Morph',
          duration: null,
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('iOS Fallback Morph')),
      );
      await gesture.moveBy(const Offset(0, -45));
      await tester.pump();

      expect(controller.morphProgress, closeTo(45.0 / 80.0, 0.01));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('iOS Fallback Morph'), findsNothing);
    });
  });
}
