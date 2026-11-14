import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart' show VelocityTracker;
import 'package:flutter/material.dart';

import 'src/notch_geometry.dart';

export 'src/notch_geometry.dart';

/// Content and behavior for one in-app notification.
class DynamicNotification {
  const DynamicNotification({
    required this.title,
    this.message,
    this.icon,
    this.avatar,
    this.accent,
    this.onTap,
    this.contentBuilder,
    this.style = const DynamicNotificationStyle(),
    this.duration = const Duration(seconds: 2),
  });

  final String title;
  final String? message;
  final IconData? icon;
  final ImageProvider<Object>? avatar;
  final Color? accent;
  final VoidCallback? onTap;

  /// Replaces the default row. The host provides the animated card and gestures.
  /// [title] and [message] still supply the card's accessibility announcement.
  final WidgetBuilder? contentBuilder;

  /// Appearance shared by the animated shape and the settled card.
  final DynamicNotificationStyle style;

  /// Time after the entrance finishes. Use null to keep the card visible.
  final Duration? duration;
}

/// Optional appearance overrides for a [DynamicNotification].
class DynamicNotificationStyle {
  const DynamicNotificationStyle({
    this.backgroundColor,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  }) : assert(borderRadius == null || borderRadius >= 0);

  /// Defaults to the light or dark card color for the app's theme.
  final Color? backgroundColor;

  /// Uniform corner radius in logical pixels. Defaults to a pill shape.
  final double? borderRadius;

  /// Insets around either the default row or the custom content.
  final EdgeInsetsGeometry padding;
}

/// Controls one mounted [DynamicNotifications] host.
class DynamicNotificationController {
  _DynamicNotificationsState? _host;

  /// The current user interaction state of the active notification.
  NotificationInteractionState get interactionState =>
      _host?._interactionState ?? NotificationInteractionState.idle;

  /// The current vertical drag offset in logical pixels.
  double get dragOffset => _host?._drag ?? 0.0;

  /// The current reverse-morph progress into the camera notch / Dynamic Island,
  /// normalized from 0.0 (fully expanded resting card) to 1.0 (fully collapsed into notch).
  double get morphProgress => _host?._morphProgress ?? 0.0;

  /// The active notification, or null if no notification is currently being presented.
  DynamicNotification? get currentNotification => _host?._current;

  /// Shows [notification] once the host is mounted.
  ///
  /// While another card exits, the most recent call replaces the pending card.
  void show(DynamicNotification notification) => _host?._show(notification);

  /// Dismisses the active card and clears any pending notification.
  void dismiss() {
    final host = _host;
    if (host == null) return;
    host._pending = null;
    host._exit();
  }
}

const _fall = Interval(0.02, 0.46, curve: Curves.easeInOutQuad);
const _expand = Interval(0.46, 0.82, curve: Curves.easeInOutCubic);
const _reveal = Interval(0.64, 0.96, curve: Curves.easeOutCubic);
const _tint = Interval(0.15, 0.40, curve: Curves.easeInOutCubic);

/// Rendering engine used to animate the notification entrance and fluid silhouette.
enum NotificationRenderMode {
  /// Verified fluid morphology renderer (standard physics-based pendant drop).
  standard,
}

/// Interaction state of the active dynamic notification.
enum NotificationInteractionState {
  /// Notification is resting at its settled position with no active user touch.
  idle,

  /// User is actively touching and dragging the notification vertically.
  dragging,

  /// User is holding the notification in place (or touching without moving).
  holding,

  /// Notification was released beyond the dismissal threshold or flung upward and is exiting.
  dismissing,

  /// Notification was tapped or swiped down beyond the open threshold; open callback is triggered.
  opening,

  /// Notification was released below threshold and is smoothly springing back to resting position.
  returning,
}

/// Configuration for interactive gesture thresholds and physics.
class NotificationGestureConfig {
  const NotificationGestureConfig({
    this.dismissThreshold = -32.0,
    this.dismissVelocityThreshold = -320.0,
    this.openThreshold = 44.0,
    this.openVelocityThreshold = 320.0,
    this.maxUpwardDrag = -80.0,
    this.maxDownwardDrag = 120.0,
    this.maxTapDuration = const Duration(milliseconds: 350),
    this.springBackDuration = const Duration(milliseconds: 260),
    this.springBackCurve = Curves.easeOutCubic,
  });

  /// Upward drag distance in logical pixels required to trigger dismissal on release.
  /// Should be a negative value. Defaults to -32.0.
  final double dismissThreshold;

  /// Upward fling velocity in logical pixels per second required to trigger dismissal.
  /// Should be a negative value. Defaults to -320.0.
  final double dismissVelocityThreshold;

  /// Downward drag distance in logical pixels required to trigger the open action on release.
  /// Should be a positive value. Defaults to 44.0.
  final double openThreshold;

  /// Downward fling velocity in logical pixels per second required to trigger open.
  /// Should be a positive value. Defaults to 320.0.
  final double openVelocityThreshold;

  /// Maximum upward drag displacement in logical pixels. Defaults to -80.0.
  final double maxUpwardDrag;

  /// Maximum downward drag displacement in logical pixels. Defaults to 120.0.
  final double maxDownwardDrag;

  /// Maximum touch duration to be recognized as a tap instead of a long hold.
  /// Defaults to 350 milliseconds.
  final Duration maxTapDuration;

  /// Duration of the spring-back animation when returning to resting position.
  /// Defaults to 260 milliseconds.
  final Duration springBackDuration;

  /// Animation curve used for the spring-back return.
  /// Defaults to [Curves.easeOutCubic].
  final Curve springBackCurve;
}

/// Places a notification above [child] without blocking touches outside it.
///
/// Install once in MaterialApp.builder, outside the navigator.
class DynamicNotifications extends StatefulWidget {
  const DynamicNotifications({
    super.key,
    required this.controller,
    required this.child,
    this.originLift = 0,
    this.geometryOverride,
    this.debugShowGuides = false,
    this.progressOverride,
    this.renderMode = NotificationRenderMode.standard,
    this.gestureConfig = const NotificationGestureConfig(),
  }) : assert(originLift >= 0 && originLift < double.infinity);

  final DynamicNotificationController controller;
  final Widget child;

  /// Moves the automatic drop origin up by this many logical pixels.
  /// The card still lands in the safe area. Defaults to zero.
  final double originLift;

  /// Optional override for the detected notch geometry.
  /// When null, geometry is automatically detected from the platform environment.
  final NotchGeometry? geometryOverride;

  /// When true, renders on-screen visual guides for the reported cutout bounds,
  /// calculated anchor origin, and the top boundary of the animated neck.
  /// Defaults to false.
  final bool debugShowGuides;

  /// Optional manual override for animation progress (between 0.0 and 1.0).
  /// Used for frame-by-frame visual inspection and screenshot validation.
  /// Defaults to null (live animation).
  final double? progressOverride;

  /// The rendering engine used to draw the notification silhouette and animation.
  /// Defaults to [NotificationRenderMode.standard].
  final NotificationRenderMode renderMode;

  /// Configuration for interactive gesture thresholds and physics.
  final NotificationGestureConfig gestureConfig;

  @override
  State<DynamicNotifications> createState() => _DynamicNotificationsState();
}

class _DynamicNotificationsState extends State<DynamicNotifications>
    with TickerProviderStateMixin {
  late final AnimationController _animation;
  late final AnimationController _springController;
  late Animation<double> _springAnimation;

  DynamicNotification? _current;
  DynamicNotification? _pending;
  int _generation = 0;
  int _springGeneration = 0;
  bool _entranceComplete = false;
  double _exitDrag = 0.0;
  double _exitStartProgress = 1.0;
  Timer? _timer;
  DateTime? _timerStart;
  Duration? _timerRemaining;
  bool _pointerDown = false;
  int? _activePointerId;
  bool _isDragging = false;
  double _dragStartY = 0;
  double _dragBaseY = 0;
  VelocityTracker? _velocityTracker;

  bool _exiting = false;
  bool _reduceMotion = false;
  double _drag = 0;
  NotificationInteractionState _interactionState =
      NotificationInteractionState.idle;
  DateTime? _pointerDownTime;
  Offset? _pointerDownPosition;
  bool _pointerMoved = false;

  @override
  void initState() {
    super.initState();
    _attachController();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
      reverseDuration: const Duration(milliseconds: 640),
    )..addStatusListener(_onStatus);

    _springController = AnimationController(
      vsync: this,
      duration: widget.gestureConfig.springBackDuration,
    )..addListener(() {
        if (_springGeneration != _generation) return;
        setState(() {
          _drag = _springAnimation.value;
          if (_drag <= 0) {
            final maxUp = widget.gestureConfig.maxUpwardDrag.abs();
            _animation.value =
                maxUp > 0 ? (1.0 + _drag / maxUp).clamp(0.0, 1.0) : 1.0;
          } else {
            _animation.value = 1.0;
          }
        });
      })..addStatusListener((status) {
        if (_springGeneration != _generation) return;
        if (status == AnimationStatus.completed) {
          if (_interactionState == NotificationInteractionState.dismissing) {
            _finishExit();
            return;
          }
          setState(() {
            _drag = 0.0;
            _dragBaseY = 0.0;
            _isDragging = false;
            _animation.value = 1.0;
            _interactionState = NotificationInteractionState.idle;
          });
          _resumeTimer();
        }
      });
    _springAnimation = const AlwaysStoppedAnimation(0.0);

    if (widget.progressOverride != null) {
      _current = const DynamicNotification(
        title: 'Geometry Validation',
        message: 'Visual Seam Inspection',
        duration: null,
      );
      _animation.value = widget.progressOverride!.clamp(0.0, 1.0);
    }
  }

  void _attachController() {
    if (widget.controller._host != null) {
      throw StateError('A controller can only be attached to one host.');
    }
    widget.controller._host = this;
  }

  @override
  void didUpdateWidget(DynamicNotifications oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _attachController();
      oldWidget.controller._host = null;
    }
    if (oldWidget.gestureConfig.springBackDuration !=
        widget.gestureConfig.springBackDuration) {
      _springController.duration = widget.gestureConfig.springBackDuration;
    }
    if (oldWidget.progressOverride != widget.progressOverride) {
      if (widget.progressOverride != null) {
        _current ??= const DynamicNotification(
          title: 'Geometry Validation',
          message: 'Visual Seam Inspection',
          duration: null,
        );
        _animation.value = widget.progressOverride!.clamp(0.0, 1.0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion && _animation.isAnimating) {
      _animation.value = _exiting ? 0 : 1;
    }

    // Automatically and non-blockingly load native Android cutout geometry if on Android
    // and no explicit override is provided.
    if (Theme.of(context).platform == TargetPlatform.android &&
        widget.geometryOverride == null) {
      final mq = MediaQuery.of(context);
      AndroidCutoutGeometryProvider.instance.load(mediaQuery: mq).then((geo) {
        if (mounted && geo != null) {
          setState(() {});
        }
      });
    }
  }

  void _show(DynamicNotification notification) {
    if (_current != null) {
      _pending = notification;
      if (!_exiting) {
        _exit();
      }
      return;
    }
    _startEntrance(notification);
  }

  void _startEntrance(DynamicNotification notification) {
    _generation++;

    _timer?.cancel();
    _timer = null;
    _timerStart = null;
    _timerRemaining = null;

    _springController.stop();
    _animation.stop();

    _activePointerId = null;
    _pointerDown = false;
    _pointerDownTime = null;
    _pointerDownPosition = null;
    _pointerMoved = false;
    _isDragging = false;
    _velocityTracker = null;
    _dragStartY = 0.0;
    _dragBaseY = 0.0;
    _drag = 0.0;
    _exitDrag = 0.0;
    _exitStartProgress = 1.0;
    _exiting = false;
    _entranceComplete = false;
    _interactionState = NotificationInteractionState.idle;

    _animation.value = 0.0;

    setState(() {
      _current = notification;
    });

    if (_reduceMotion) {
      _animation.value = 1.0;
    } else {
      _animation.forward(from: 0.0);
    }
  }

  void _exit() {
    if (_current == null || _exiting) return;
    _activePointerId = null;
    _pointerDown = false;
    _timer?.cancel();
    _timer = null;
    _timerStart = null;
    _timerRemaining = null;
    _springController.stop();

    _exitDrag = _drag;
    _exitStartProgress = _animation.value > 0.0 ? _animation.value : 1.0;

    setState(() {
      _exiting = true;
      if (_interactionState != NotificationInteractionState.opening) {
        _interactionState = NotificationInteractionState.dismissing;
      }
    });

    if (_animation.value == 0) {
      _animation.stop();
      _finishExit();
    } else if (_reduceMotion) {
      _animation.value = 0.0;
      _finishExit();
    } else {
      _animation.reverse(from: _animation.value);
    }
  }

  void _open() {
    if (_exiting ||
        _interactionState == NotificationInteractionState.dismissing) {
      return;
    }
    setState(() => _interactionState = NotificationInteractionState.opening);
    _springController.stop();
    final callback = _current?.onTap;
    _exit();
    callback?.call();
  }

  void _onTimerExpired() {
    if (_current == null || _exiting) return;
    if (_pointerDown || _interactionState != NotificationInteractionState.idle) {
      return;
    }
    _exit();
  }

  void _onStatus(AnimationStatus status) {
    final gen = _generation;
    if (status == AnimationStatus.completed && !_exiting && !_entranceComplete) {
      _entranceComplete = true;
      if (gen != _generation) return;
      final duration = _current?.duration;
      if (duration != null) {
        _timerRemaining = duration;
        _timerStart = clock.now();
        _timer = Timer(duration, () {
          if (gen != _generation) return;
          _onTimerExpired();
        });
      }
    }
    if (status == AnimationStatus.dismissed && _exiting) {
      if (gen != _generation) return;
      _finishExit();
    }
  }

  void _finishExit() {
    final next = _pending;
    _pending = null;
    _timer?.cancel();
    _timer = null;
    _timerStart = null;
    _timerRemaining = null;
    _isDragging = false;
    _activePointerId = null;
    _pointerDown = false;
    _velocityTracker = null;
    _dragStartY = 0.0;
    _dragBaseY = 0.0;
    _springController.stop();
    _animation.stop();
    _current = null;
    _exiting = false;
    _entranceComplete = false;
    _drag = 0.0;
    _exitDrag = 0.0;
    _exitStartProgress = 1.0;
    _interactionState = NotificationInteractionState.idle;
    _pointerDownTime = null;
    _pointerDownPosition = null;
    _pointerMoved = false;

    if (next != null) {
      _startEntrance(next);
    } else {
      setState(() {});
    }
  }

  double get _morphProgress {
    if (_current == null) return 0.0;
    return (1.0 - _animation.value).clamp(0.0, 1.0);
  }

  void _springBack() {
    _springGeneration = _generation;
    if (_drag == 0.0 && _animation.value == 1.0) {
      setState(() => _interactionState = NotificationInteractionState.idle);
      _resumeTimer();
      return;
    }
    setState(() => _interactionState = NotificationInteractionState.returning);
    _springAnimation = Tween<double>(
      begin: _drag,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _springController,
        curve: widget.gestureConfig.springBackCurve,
      ),
    );
    _springController.forward(from: 0.0);
  }

  void _pauseTimer() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
      _timer = null;
      if (_timerStart != null && _timerRemaining != null) {
        final elapsed = clock.now().difference(_timerStart!);
        _timerRemaining = _timerRemaining! - elapsed;
        if (_timerRemaining! < Duration.zero) {
          _timerRemaining = Duration.zero;
        }
      }
    }
  }

  void _resumeTimer() {
    if (_current == null ||
        _exiting ||
        _pointerDown ||
        _interactionState != NotificationInteractionState.idle) {
      return;
    }
    if (_timer != null && _timer!.isActive) return;
    final remaining = _timerRemaining;
    if (remaining != null) {
      final effectiveDuration = remaining <= const Duration(milliseconds: 400)
          ? const Duration(milliseconds: 400)
          : remaining;
      _timerRemaining = effectiveDuration;
      _timerStart = clock.now();
      _timer = Timer(effectiveDuration, _onTimerExpired);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_exiting) return;
    if (_activePointerId != null) return;
    _activePointerId = event.pointer;
    _pointerDown = true;
    _pointerDownTime = clock.now();
    _pointerDownPosition = event.position;
    _pointerMoved = false;
    _dragStartY = event.position.dy;
    _dragBaseY = _drag;
    _isDragging = false;
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    _springController.stop();
    _pauseTimer();
    setState(() => _interactionState = NotificationInteractionState.holding);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_exiting || !_pointerDown || event.pointer != _activePointerId) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    if (_pointerDownPosition != null &&
        (event.position - _pointerDownPosition!).distance > 18.0) {
      _pointerMoved = true;
    }
    final deltaY = event.position.dy - _dragStartY;
    if (!_isDragging && (_dragBaseY != 0 || deltaY.abs() > 4.0)) {
      _isDragging = true;
    }
    if (_isDragging) {
      final newDrag = (_dragBaseY + deltaY).clamp(
        widget.gestureConfig.maxUpwardDrag,
        widget.gestureConfig.maxDownwardDrag,
      );
      _drag = newDrag;
      if (_drag <= 0) {
        final maxUp = widget.gestureConfig.maxUpwardDrag.abs();
        final dragProgress = maxUp > 0
            ? (1.0 + _drag / maxUp).clamp(0.0, 1.0)
            : 1.0;
        _animation.value = dragProgress;
      } else {
        _animation.value = 1.0;
      }
      setState(() {
        _interactionState = NotificationInteractionState.dragging;
      });
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointerId) return;
    _activePointerId = null;
    _pointerDown = false;
    if (_exiting) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final velocity =
        _velocityTracker?.getVelocityEstimate()?.pixelsPerSecond.dy ?? 0.0;
    _velocityTracker = null;

    if (_isDragging || _drag != 0) {
      final config = widget.gestureConfig;

      // Upward dismissal: crossed threshold upward, or flung upward while displaced upward
      if (_drag <= config.dismissThreshold ||
          (_drag <= 0 && velocity <= config.dismissVelocityThreshold)) {
        _exit();
        return;
      }

      // Downward open: crossed threshold downward, or flung downward while displaced downward
      if (_drag >= config.openThreshold ||
          (_drag >= 0 && velocity >= config.openVelocityThreshold)) {
        _open();
        return;
      }

      // Spring back
      _springBack();
      return;
    }

    setState(() => _interactionState = NotificationInteractionState.idle);
    _resumeTimer();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointerId) return;
    _activePointerId = null;
    _pointerDown = false;
    _pointerDownPosition = null;
    _pointerMoved = false;
    _isDragging = false;
    _velocityTracker = null;
    if (_exiting) return;
    if (_drag != 0 || _animation.value < 1.0) {
      _springBack();
    } else {
      setState(() => _interactionState = NotificationInteractionState.idle);
      _resumeTimer();
    }
  }

  void _onTap() {
    if (_exiting ||
        _interactionState == NotificationInteractionState.dismissing ||
        _interactionState == NotificationInteractionState.opening) {
      return;
    }
    if (_isDragging || _drag != 0 || _pointerMoved) {
      _pointerMoved = false;
      return;
    }
    final now = clock.now();
    final downTime = _pointerDownTime;
    _pointerDownTime = null;
    _pointerDownPosition = null;
    _pointerMoved = false;
    if (downTime != null &&
        now.difference(downTime) >= widget.gestureConfig.maxTapDuration) {
      // Long press / hold release: do not trigger tap!
      setState(() => _interactionState = NotificationInteractionState.idle);
      _resumeTimer();
      return;
    }
    _open();
  }

  @override
  void dispose() {
    widget.controller._host = null;
    _timer?.cancel();
    _springController.dispose();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notification = _current;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final padding = viewPadding != EdgeInsets.zero
        ? viewPadding
        : MediaQuery.paddingOf(context);
    final safeTop = padding.top + 4;
    var anchorTop = safeTop;
    final viewportCenter =
        (padding.left + MediaQuery.sizeOf(context).width - padding.right) / 2;
    var anchorX = viewportCenter;
    final geometry =
        widget.geometryOverride ?? NotchGeometryDetector.detect(context);

    if (notification != null && !_reduceMotion) {
      if (geometry.hasCutout) {
        anchorX = geometry.center.dx;
        anchorTop = geometry.anchorTop;
      } else if (widget.geometryOverride != null) {
        anchorX = geometry.center.dx;
        anchorTop = geometry.anchorTop;
      } else {
        anchorTop = safeTop;
        anchorX = viewportCenter;
      }
      anchorTop = math.max(0, anchorTop - widget.originLift);
    }
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (notification != null)
          Positioned(
            top: anchorTop,
            left: padding.left,
            right: padding.right,
            bottom: padding.bottom,
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 396),
                    child: _buildNotification(
                      notification,
                      math.max(0.0, safeTop - anchorTop),
                      anchorX - viewportCenter,
                      anchorTop,
                      geometry,
                      widget.debugShowGuides,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotification(
    DynamicNotification notification,
    double safeOffset,
    double anchorOffset,
    double anchorTop,
    NotchGeometry geometry,
    bool debugShowGuides,
  ) {
    final theme = Theme.of(context);
    final style = notification.style;
    final surface =
        style.backgroundColor ??
        (theme.brightness == Brightness.dark
            ? const Color(0xFF28272A)
            : Colors.white);
    final dark =
        ThemeData.estimateBrightnessForColor(surface) == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF171719);
    final secondary = dark ? const Color(0xFFD2D0D3) : const Color(0xFF66646A);
    final accent = notification.accent ?? foreground;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _reduceMotion;
        final landing = math.max(
          0.0,
          safeOffset +
              (compact || constraints.maxHeight - safeOffset < 180
                  ? 0.0
                  : 22.0),
        );
        return AnimatedBuilder(
          animation: _animation,
          child: Semantics(
            container: true,
            liveRegion: true,
            label: [notification.title, ?notification.message].join('\n'),
            onTap: _open,
            onDismiss: _exit,
            excludeSemantics: notification.contentBuilder == null,
            explicitChildNodes: notification.contentBuilder != null,
            child: Listener(
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              child: GestureDetector(
                excludeFromSemantics: true,
                behavior: HitTestBehavior.opaque,
                onTap: _onTap,
                child: ClipRRect(
                borderRadius: BorderRadius.circular(style.borderRadius ?? 36),
                child: Padding(
                  padding: style.padding,
                  child: notification.contentBuilder != null
                      ? Material(
                          type: MaterialType.transparency,
                          child: Builder(builder: notification.contentBuilder!),
                        )
                      : Row(
                          children: [
                            if (notification.avatar case final avatar?
                                when constraints.maxWidth >= 150) ...[
                              CircleAvatar(radius: 21, backgroundImage: avatar),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: foreground,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  if (notification.message
                                      case final message?) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      message,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: secondary,
                                            fontSize: 13,
                                            height: 1.25,
                                            decoration: TextDecoration.none,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (notification.icon case final icon?
                                when constraints.maxWidth >= 128) ...[
                              const SizedBox(width: 12),
                              Icon(icon, size: 22, color: accent),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
          ),
          builder: (context, child) {
            final progress = widget.progressOverride ?? _animation.value;
            final reveal = compact ? progress : _reveal.transform(progress);
            final double effectiveDrag;
            if (compact) {
              effectiveDrag = 0.0;
            } else if (_exiting) {
              effectiveDrag = _exitStartProgress > 0.0
                  ? _exitDrag * (_animation.value / _exitStartProgress)
                  : 0.0;
            } else {
              effectiveDrag = _drag;
            }
            final offset = Offset(0, effectiveDrag);
            final morphProgress = _morphProgress;
            final contentOpacity = reveal;
            final contentScale = lerpDouble(0.94, 1.0, reveal)!;
            final isInteractionLocked = _exiting || (!_entranceComplete && reveal < 1.0) || (_interactionState != NotificationInteractionState.returning && morphProgress > 0.35);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey('dynamic-notification-shape'),
                      painter: _NotificationPainter(
                        progress: progress,
                        drag: offset.dy,
                        landing: landing,
                        anchorOffset: anchorOffset,
                        anchorTop: anchorTop,
                        surface: surface,
                        borderRadius: style.borderRadius,
                        compact: compact,
                        geometry: geometry,
                        debugShowGuides: debugShowGuides,
                        renderMode: widget.renderMode,
                        isExiting: _exiting,
                        morphProgress: morphProgress,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: landing),
                  child: Transform.translate(
                    offset: offset,
                    child: IgnorePointer(
                      ignoring: isInteractionLocked,
                      child: ExcludeSemantics(
                        excluding: isInteractionLocked,
                        child: Opacity(
                          opacity: contentOpacity,
                          child: Transform.scale(
                            scale: contentScale,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NotificationPainter extends CustomPainter {
  const _NotificationPainter({
    required this.progress,
    required this.drag,
    required this.landing,
    required this.anchorOffset,
    required this.anchorTop,
    required this.surface,
    required this.borderRadius,
    required this.compact,
    this.geometry,
    this.debugShowGuides = false,
    this.renderMode = NotificationRenderMode.standard,
    this.isExiting = false,
    this.morphProgress = 0.0,
  });

  final double progress;
  final double drag;
  final double landing;
  final double anchorOffset;
  final double anchorTop;
  final Color surface;
  final double? borderRadius;
  final bool compact;
  final NotchGeometry? geometry;
  final bool debugShowGuides;
  final NotificationRenderMode renderMode;
  final bool isExiting;
  final double morphProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final cardHeight = size.height - landing;
    if (progress == 0 || size.width == 0 || cardHeight <= 0) return;

    final hasCutout = geometry?.hasCutout ?? false;
    final isPunchHole = hasCutout && geometry?.shape == NotchShape.punchHole;
    final isPill = hasCutout && geometry?.shape == NotchShape.pill;

    final dpr =
        (geometry?.devicePixelRatio != null && geometry!.devicePixelRatio > 0)
        ? geometry!.devicePixelRatio
        : 1.0;
    final targetOverlap = math.max(2.2, (2.2 * dpr).round() / dpr);

    final cutoutBottomLocal = hasCutout ? (geometry!.bottom - anchorTop) : 0.0;
    final cutoutCenterYLocal = hasCutout
        ? (geometry!.center.dy - anchorTop)
        : 0.0;
    final cutoutRadiusX = (hasCutout && geometry!.width > 0)
        ? geometry!.width / 2
        : 12.0;
    final cutoutRadiusY = (hasCutout && geometry!.height > 0)
        ? geometry!.height / 2
        : cutoutRadiusX;
    final cutoutRadius = math.min(cutoutRadiusX, cutoutRadiusY);

    final maxSafeOverlap = hasCutout
        ? math.min(geometry!.bottom, cutoutRadiusY * 0.45)
        : 0.0;
    final deltaOverlap = hasCutout
        ? math.min(targetOverlap, math.max(0.0, maxSafeOverlap))
        : 0.0;

    final yApex = cutoutBottomLocal - deltaOverlap;

    final cutoutHalfWidth = (geometry?.width != null && geometry!.width > 0)
        ? geometry!.width / 2
        : 16.0;
    final maxContactRadius = isPunchHole
        ? math.min(14.0, math.max(8.0, cutoutRadius * 0.88))
        : (isPill
              ? math.min(52.0, math.max(28.0, cutoutHalfWidth * 0.78))
              : math.min(48.0, math.max(16.0, cutoutHalfWidth * 0.78)));

    final fall = _fall.transform(progress);
    final expand = compact ? 1.0 : _expand.transform(progress);
    final grow = const Interval(
      0.0,
      0.24,
      curve: Curves.easeOutCubic,
    ).transform(progress);

    final double eggFactor;
    if (compact || progress > 0.44) {
      eggFactor = 0.0;
    } else if (progress <= 0.28) {
      eggFactor = const Interval(
        0.08,
        0.24,
        curve: Curves.easeInOut,
      ).transform(progress);
    } else {
      // Relaxation from egg to circle after detachment
      eggFactor =
          1.0 -
          const Interval(
            0.28,
            0.44,
            curve: Curves.easeInOut,
          ).transform(progress);
    }
    final effectiveEgg = eggFactor * (1.0 - expand);

    final stretch =
        1.0 +
        0.28 *
            (1.0 - expand) *
            math.sin(
              math.pi * (progress / 0.36).clamp(0.0, 1.0),
            );
    final dropSize =
        math.min(48.0, math.min(size.width, cardHeight)) *
        (compact ? 1.0 : (0.32 + 0.68 * grow));

    final width = lerpDouble(dropSize / stretch, size.width, expand)!;
    final height = lerpDouble(dropSize * stretch, cardHeight, expand)!;
    final centerY = compact
        ? cardHeight / 2
        : lerpDouble(-12, landing + cardHeight / 2, fall)! + drag;
    final centerX = size.width / 2 + anchorOffset * (1.0 - expand);
    final radius = math.min(width, height) / 2;
    final cardCorner = math.min(
      borderRadius ?? (cardHeight / 2),
      cardHeight / 2,
    );
    final corner = lerpDouble(radius, cardCorner, expand)!;

    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: width,
      height: height,
    );

    final topFlat = math.max(0.0, width / 2 - corner);
    final botFlat = math.max(0.0, width / 2 - corner);

    final tint = compact ? 1.0 : _tint.transform(progress);
    final bodyColor = Color.lerp(Colors.black, surface, tint)!;
    final paint = Paint()..color = bodyColor;

    double? tailLeft;
    double? tailRight;
    double? tailTopY;

    Path path;

    final isAttached = !compact && progress <= 0.28;
    if (isAttached) {
      final u = (progress / 0.28).clamp(0.0, 1.0);
      final shoulder =
          maxContactRadius *
          lerpDouble(0.96, 0.65, Curves.easeInOut.transform(u))!;

      // Calculate aperture contact Y and tangent angles following the lower contour
      double yContact = yApex;
      double contourRise = 0.0;
      double contactCos = 0.0;
      double contactSin = 1.0;
      if (hasCutout && shoulder > 0) {
        if (isPunchHole) {
          final rClamped = math.min(shoulder, cutoutRadius * 0.92);
          final cosAlpha =
              math.sqrt(
                math.max(
                  0.0,
                  cutoutRadius * cutoutRadius - rClamped * rClamped,
                ),
              ) /
              cutoutRadius;
          final sinAlpha = rClamped / cutoutRadius;
          final yRim = cutoutCenterYLocal + cutoutRadius * cosAlpha;
          yContact = yRim - deltaOverlap;
          contourRise = math.max(0.0, yApex - yContact);
          contactCos = cosAlpha;
          contactSin = sinAlpha;
        } else if (isPill) {
          final flatHalf = math.max(
            0.0,
            (geometry!.width - geometry!.height) / 2,
          );
          if (shoulder > flatHalf) {
            final dx = math.min(cutoutRadius * 0.92, shoulder - flatHalf);
            final cosAlpha =
                math.sqrt(
                  math.max(0.0, cutoutRadius * cutoutRadius - dx * dx),
                ) /
                cutoutRadius;
            final sinAlpha = dx / cutoutRadius;
            final yRim = cutoutCenterYLocal + cutoutRadius * cosAlpha;
            yContact = yRim - deltaOverlap;
            contourRise = math.max(0.0, yApex - yContact);
            contactCos = cosAlpha;
            contactSin = sinAlpha;
          }
        }
      }
      yContact = math.max(-anchorTop, yContact);

      // Droplet vertical extent
      final yBottom =
          yApex +
          lerpDouble(
            22.0,
            math.max(rect.bottom - yApex, 78.0),
            Curves.easeInOutQuad.transform(u),
          )!;

      // Pinch waist: smoothly narrows from wide funnel to pinched waist
      final pinch = math.pow(u, 2.0);
      final waist = shoulder * (0.45 - 0.28 * pinch);
      final waistY =
          yContact + (yBottom - yContact) * lerpDouble(0.48, 0.36, u)!;

      // Bulb width: rounded bulb forming at the bottom
      final wBulb =
          lerpDouble(
            10.0,
            math.max(width / 2, 24.5),
            Curves.easeInOutCubic.transform(u),
          )!;
      final bulbY =
          yContact + (yBottom - yContact) * lerpDouble(0.76, 0.68, u)!;

      tailLeft = centerX - shoulder;
      tailRight = centerX + shoulder;
      tailTopY = yContact;

      path = Path()..moveTo(centerX - shoulder, yContact);

      if (contourRise > 0.001) {
        final cpY = yApex + contourRise / 3.0;
        final cx = contactCos > 0.05
            ? math.min(
                shoulder * 0.65,
                math.max(
                  shoulder * 0.35,
                  (4.0 / 3.0) *
                      contourRise *
                      (cutoutRadius * contactCos) /
                      math.max(1.0, shoulder),
                ),
              )
            : shoulder * 0.5;
        path.cubicTo(
          centerX - shoulder + cx,
          cpY,
          centerX + shoulder - cx,
          cpY,
          centerX + shoulder,
          yContact,
        );
      } else {
        path.lineTo(centerX + shoulder, yContact);
      }

      final hFlank = math.max(1.0, waistY - yContact);
      final wFlank = math.max(0.1, shoulder - waist);
      final double cp1x, cp1y, cp2x, cp2y;
      if (contactCos > 0.05) {
        final maxL1 = math.min(
          wFlank / contactCos * 0.45,
          hFlank / contactSin * 0.35,
        );
        final l1 = math.max(1.0, maxL1);
        cp1x = centerX + shoulder - l1 * contactCos;
        cp1y = yContact + l1 * contactSin;
        cp2x = centerX + waist + wFlank * 0.05;
        cp2y = waistY - math.min(6.0, hFlank * 0.30);
      } else {
        cp1x = centerX + shoulder - wFlank * 0.22;
        cp1y = yContact + hFlank * 0.38;
        cp2x = centerX + waist + wFlank * 0.06;
        cp2y = waistY - math.min(6.0, hFlank * 0.30);
      }

      // 1. Right flank: concave cubic from (centerX + shoulder, yContact) to (centerX + waist, waistY)
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, centerX + waist, waistY);

      // 2. Right waist to bulb: outward cubic from (centerX + waist, waistY) to (centerX + wBulb, bulbY)
      final hWaistBulb = math.max(1.0, bulbY - waistY);
      path.cubicTo(
        centerX + waist,
        waistY + hWaistBulb * 0.40,
        centerX + wBulb,
        bulbY - hWaistBulb * 0.35,
        centerX + wBulb,
        bulbY,
      );

      // 3. Bulb bottom: from (centerX + wBulb, bulbY) around (centerX, yBottom) to (centerX - wBulb, bulbY)
      final hBulbBot = math.max(1.0, yBottom - bulbY);
      path.cubicTo(
        centerX + wBulb,
        bulbY + hBulbBot * 0.5523,
        centerX + wBulb * 0.5523,
        yBottom,
        centerX,
        yBottom,
      );
      path.cubicTo(
        centerX - wBulb * 0.5523,
        yBottom,
        centerX - wBulb,
        bulbY + hBulbBot * 0.5523,
        centerX - wBulb,
        bulbY,
      );

      // 4. Left bulb to waist: from (centerX - wBulb, bulbY) to (centerX - waist, waistY)
      path.cubicTo(
        centerX - wBulb,
        bulbY - hWaistBulb * 0.35,
        centerX - waist,
        waistY + hWaistBulb * 0.40,
        centerX - waist,
        waistY,
      );

      // 5. Left flank: concave cubic from (centerX - waist, waistY) to (centerX - shoulder, yContact)
      path.cubicTo(
        2 * centerX - cp2x,
        cp2y,
        2 * centerX - cp1x,
        cp1y,
        centerX - shoulder,
        yContact,
      );
      path.close();

      if (surface != Colors.black) {
        paint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black,
            Color.lerp(Colors.black, surface, 0.35)!,
            Color.lerp(Colors.black, surface, 0.85)!,
            surface,
          ],
          stops: const [0.0, 0.30, 0.70, 1.0],
        ).createShader(
          Rect.fromLTRB(0, yContact, 1, math.max(yBottom, yContact + 1.0)),
        );
      }
    } else {
      final bulbY = rect.top + height * (0.50 + 0.14 * effectiveEgg);
      final wBulb = width / 2;

      path = Path();
      if (topFlat > 0) {
        // Expanded card with flat top and bottom edges
        path
          ..moveTo(centerX - topFlat, rect.top)
          ..lineTo(centerX + topFlat, rect.top)
          ..cubicTo(
            centerX + topFlat + (wBulb - topFlat) * 0.5523,
            rect.top,
            centerX + wBulb,
            bulbY - (bulbY - rect.top) * 0.5523,
            centerX + wBulb,
            bulbY,
          )
          ..cubicTo(
            centerX + wBulb,
            bulbY + (rect.bottom - bulbY) * 0.5523,
            centerX + botFlat + (wBulb - botFlat) * 0.5523,
            rect.bottom,
            centerX + botFlat,
            rect.bottom,
          )
          ..lineTo(centerX - botFlat, rect.bottom)
          ..cubicTo(
            centerX - botFlat - (wBulb - botFlat) * 0.5523,
            rect.bottom,
            centerX - wBulb,
            bulbY + (rect.bottom - bulbY) * 0.5523,
            centerX - wBulb,
            bulbY,
          )
          ..cubicTo(
            centerX - wBulb,
            bulbY - (bulbY - rect.top) * 0.5523,
            centerX - topFlat - (wBulb - topFlat) * 0.5523,
            rect.top,
            centerX - topFlat,
            rect.top,
          )
          ..close();
      } else {
        // Airborne droplet: morphs from pointed teardrop (effectiveEgg = 1.0)
        // to circular disc (effectiveEgg = 0.0)
        final kX = lerpDouble(0.5523, 0.0, effectiveEgg)!;
        final kYTop = lerpDouble(0.0, 0.35, effectiveEgg)!;
        final kYBulb = lerpDouble(0.5523, 0.40, effectiveEgg)!;

        path
          ..moveTo(centerX, rect.top)
          ..cubicTo(
            centerX + wBulb * kX,
            rect.top + (bulbY - rect.top) * kYTop,
            centerX + wBulb,
            bulbY - (bulbY - rect.top) * kYBulb,
            centerX + wBulb,
            bulbY,
          )
          ..cubicTo(
            centerX + wBulb,
            bulbY + (rect.bottom - bulbY) * 0.5523,
            centerX + wBulb * 0.5523,
            rect.bottom,
            centerX,
            rect.bottom,
          )
          ..cubicTo(
            centerX - wBulb * 0.5523,
            rect.bottom,
            centerX - wBulb,
            bulbY + (rect.bottom - bulbY) * 0.5523,
            centerX - wBulb,
            bulbY,
          )
          ..cubicTo(
            centerX - wBulb,
            bulbY - (bulbY - rect.top) * kYBulb,
            centerX - wBulb * kX,
            rect.top + (bulbY - rect.top) * kYTop,
            centerX,
            rect.top,
          )
          ..close();
      }

    }

    // Meniscus tip remaining on the Dynamic Island aperture after detachment
    final bool showMeniscus =
        !compact && isPill && progress > 0.28 && progress <= 0.40;
    Path? meniscusPath;
    if (showMeniscus) {
      final recoil = ((progress - 0.28) / (0.40 - 0.28)).clamp(0.0, 1.0);
      final recoilHeight = (1.0 - Curves.easeInCubic.transform(recoil));
      final recoilWidth = (1.0 - Curves.easeIn.transform(recoil));
      final mHeight = 7.5 * recoilHeight;
      final mShoulder = 22.0 * recoilWidth;

      if (mHeight > 0.2 && mShoulder > 1.0) {
        final mYContact = math.max(-anchorTop, yApex);
        meniscusPath = Path()
          ..moveTo(centerX - mShoulder, mYContact)
          ..lineTo(centerX + mShoulder, mYContact)
          ..cubicTo(
            centerX + mShoulder * 0.50,
            mYContact + mHeight * 0.15,
            centerX + 3.0,
            mYContact + mHeight * 0.85,
            centerX,
            mYContact + mHeight,
          )
          ..cubicTo(
            centerX - 3.0,
            mYContact + mHeight * 0.85,
            centerX - mShoulder * 0.50,
            mYContact + mHeight * 0.15,
            centerX - mShoulder,
            mYContact,
          )
          ..close();

        tailLeft = math.min(
          tailLeft ?? (centerX - mShoulder),
          centerX - mShoulder,
        );
        tailRight = math.max(
          tailRight ?? (centerX + mShoulder),
          centerX + mShoulder,
        );
        tailTopY = math.min(tailTopY ?? mYContact, mYContact);
      }
    }

    final tailPad = (tailLeft != null && tailRight != null)
        ? math.max(28.0, (tailRight - tailLeft) / 2 + 16.0)
        : 28.0;
    final clipLeft = tailLeft != null
        ? math.min(-24.0, math.min(rect.left - 24.0, centerX - tailPad))
        : math.min(-24.0, rect.left - 24.0);
    final clipRight = tailRight != null
        ? math.max(size.width + 24.0, math.max(rect.right + 24.0, centerX + tailPad))
        : math.max(size.width + 24.0, rect.right + 24.0);
    final minPathY = tailTopY ?? 0.0;
    final maxAnchorOverlap = math.max(0.0, anchorTop);
    final screenTop = -maxAnchorOverlap;
    final baseClipTop = hasCutout
        ? math.min(minPathY, -math.min(16.0, maxAnchorOverlap))
        : -math.min(16.0, maxAnchorOverlap);
    final clipTop = math.max(
      screenTop,
      math.min(baseClipTop + math.min(0.0, drag), rect.top - 24.0),
    );
    final clipBottom = math.max(size.height + 24.0, rect.bottom + 24.0);

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(clipLeft, clipTop, clipRight, clipBottom),
    );
    final shadowOpacity = expand > 0
        ? lerpDouble(0.20, 0.26, expand)!
        : (!compact && progress > 0.28
              ? 0.20 * ((progress - 0.28) / 0.08).clamp(0.0, 1.0)
              : 0.0);
    final elevation = expand > 0 ? lerpDouble(8.0, 12.0, expand)! : 8.0;
    if (shadowOpacity > 0) {
      canvas.drawShadow(
        path,
        Colors.black.withValues(alpha: shadowOpacity),
        elevation,
        true,
      );
    }
    canvas.drawPath(path, paint);
    if (meniscusPath != null) {
      canvas.drawPath(meniscusPath, Paint()..color = Colors.black);
    }
    canvas.restore();

    if (debugShowGuides) {
      _paintDebugGuides(
        canvas: canvas,
        size: size,
        centerX: centerX,
        yContact: tailTopY ?? yApex,
        yApex: yApex,
        tailLeft: tailLeft,
        tailRight: tailRight,
      );
    }
  }

  void _paintDebugGuides({
    required Canvas canvas,
    required Size size,
    required double centerX,
    required double yContact,
    required double yApex,
    required double? tailLeft,
    required double? tailRight,
  }) {
    // 1. Cutout bounding box in local painter coordinates
    if (geometry?.bounds != null) {
      final b = geometry!.bounds!;
      final cutoutCenterLocalX = size.width / 2 + anchorOffset;
      final cutoutCenterLocalY = b.center.dy - anchorTop;
      final localBounds = Rect.fromCenter(
        center: Offset(cutoutCenterLocalX, cutoutCenterLocalY),
        width: b.width,
        height: b.height,
      );
      final boundsPaint = Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(localBounds, boundsPaint);
    }

    // 2. Origin crosshair (anchor origin at local Y = 0)
    final originPaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(centerX - 12, 0),
      Offset(centerX + 12, 0),
      originPaint,
    );
    canvas.drawLine(Offset(centerX, -12), Offset(centerX, 12), originPaint);

    // 3. Top of animated neck and attachment contact points
    if (tailLeft != null && tailRight != null) {
      final neckGuidePaint = Paint()
        ..color = const Color(0xFFFFEA00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(
        Offset(tailLeft, yContact),
        Offset(tailRight, yContact),
        neckGuidePaint,
      );
      canvas.drawCircle(
        Offset(tailLeft, yContact),
        3.0,
        neckGuidePaint..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(tailRight, yContact),
        3.0,
        neckGuidePaint..style = PaintingStyle.fill,
      );
      final apexPaint = Paint()
        ..color = const Color(0xFF76FF03)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, yApex), 3.5, apexPaint);
    }
  }

  @override
  bool shouldRepaint(_NotificationPainter old) =>
      old.progress != progress ||
      old.drag != drag ||
      old.landing != landing ||
      old.anchorOffset != anchorOffset ||
      old.anchorTop != anchorTop ||
      old.surface != surface ||
      old.borderRadius != borderRadius ||
      old.compact != compact ||
      old.geometry != geometry ||
      old.debugShowGuides != debugShowGuides ||
      old.renderMode != renderMode ||
      old.isExiting != isExiting ||
      old.morphProgress != morphProgress;
}
