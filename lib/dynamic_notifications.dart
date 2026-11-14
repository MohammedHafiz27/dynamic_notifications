import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

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

const _fall = Interval(0.02, 0.51, curve: Curves.easeOutCubic);
const _expand = Interval(0.40, 0.78, curve: Curves.easeInOutCubic);
const _reveal = Interval(0.66, 0.96, curve: Curves.easeInOutCubic);
const _tint = Interval(0.15, 0.43, curve: Curves.easeInOutCubic);

/// Rendering engine used to animate the notification entrance and fluid silhouette.
enum NotificationRenderMode {
  /// Verified fluid morphology renderer (standard physics-based pendant drop).
  standard,

  /// Experimental liquid renderer incorporating continuous waist-and-shoulder
  /// silhouette bridge dynamics and asymmetric absorption sweep from liquid_notch.
  experimentalLiquid,
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

  @override
  State<DynamicNotifications> createState() => _DynamicNotificationsState();
}

class _DynamicNotificationsState extends State<DynamicNotifications>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  DynamicNotification? _current;
  DynamicNotification? _pending;
  Timer? _timer;
  bool _exiting = false;
  bool _reduceMotion = false;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _attachController();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
      reverseDuration: const Duration(milliseconds: 640),
    )..addStatusListener(_onStatus);

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
      _exit();
      return;
    }
    setState(() {
      _current = notification;
      _exiting = false;
      _drag = 0;
    });
    if (_reduceMotion) {
      _animation.value = 1;
    } else {
      _animation.forward();
    }
  }

  void _exit() {
    if (_current == null || _exiting) return;
    _timer?.cancel();
    setState(() => _exiting = true);
    if (_animation.value == 0) {
      _animation.stop();
      _finishExit();
    } else if (_reduceMotion) {
      _animation.value = 0;
    } else {
      _animation.reverse();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_exiting) {
      final duration = _current?.duration;
      if (duration != null) _timer = Timer(duration, _exit);
    }
    if (status == AnimationStatus.dismissed && _exiting) _finishExit();
  }

  void _finishExit() {
    final next = _pending;
    _pending = null;
    setState(() {
      _current = null;
      _exiting = false;
    });
    if (next != null) _show(next);
  }

  void _tap() {
    if (_exiting) return;
    final callback = _current?.onTap;
    _exit();
    callback?.call();
  }

  @override
  void dispose() {
    widget.controller._host = null;
    _timer?.cancel();
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
              (compact || constraints.maxHeight - safeOffset < 180 ? 0.0 : 22.0),
        );
        return AnimatedBuilder(
          animation: _animation,
          child: Semantics(
            container: true,
            liveRegion: true,
            label: [notification.title, ?notification.message].join('\n'),
            onTap: _tap,
            onDismiss: _exit,
            excludeSemantics: notification.contentBuilder == null,
            explicitChildNodes: notification.contentBuilder != null,
            child: GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTap: _tap,
              onVerticalDragUpdate: (details) {
                if (_exiting) return;
                setState(
                  () => _drag = (_drag + details.delta.dy).clamp(-48, 0),
                );
              },
              onVerticalDragEnd: (details) {
                if (_exiting) return;
                if (_drag < -18 || (details.primaryVelocity ?? 0) < -420) {
                  _exit();
                } else {
                  setState(() => _drag = 0);
                }
              },
              onVerticalDragCancel: () {
                if (!_exiting) setState(() => _drag = 0);
              },
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
          builder: (context, child) {
            final progress = widget.progressOverride ?? _animation.value;
            final reveal = compact ? progress : _reveal.transform(progress);
            final interactive = !_exiting && reveal == 1;
            final offset = Offset(
              0,
              compact ? 0 : math.max(-4, _drag) * _expand.transform(progress),
            );
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
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: landing),
                  child: Transform.translate(
                    offset: offset,
                    child: IgnorePointer(
                      ignoring: !interactive,
                      child: ExcludeSemantics(
                        excluding: !interactive,
                        child: Opacity(
                          opacity: reveal,
                          child: Transform.scale(
                            scale: lerpDouble(0.94, 1, reveal)!,
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

  @override
  void paint(Canvas canvas, Size size) {
    final cardHeight = size.height - landing;
    if (progress == 0 || size.width == 0 || cardHeight <= 0) return;

    final fall = _fall.transform(progress);
    final expand = compact ? 1.0 : _expand.transform(progress);
    final grow = const Interval(
      0,
      0.32,
      curve: Curves.easeOutCubic,
    ).transform(progress);
    final stretch = 1 + 0.22 * math.sin(math.pi * fall);
    final dropSize = math.min(46.0, math.min(size.width, cardHeight)) * grow;
    final width = lerpDouble(dropSize / stretch, size.width, expand)!;
    final height = lerpDouble(dropSize * stretch, cardHeight, expand)!;
    final centerY = compact
        ? cardHeight / 2
        : lerpDouble(-12, landing + cardHeight / 2, fall)! + drag;
    final centerX = size.width / 2 + anchorOffset * (1 - expand);
    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: width,
      height: height,
    );

    final radius = math.min(width, height) / 2;
    final corner = lerpDouble(
      radius,
      math.min(borderRadius ?? radius, radius),
      expand,
    )!;
    final topCorner = lerpDouble(width / 2, corner, expand)!;
    final topTangent = lerpDouble(0.33, 0.5523, expand)!;
    final shoulderY = lerpDouble(
      rect.top + height * 0.61,
      rect.top + corner,
      expand,
    )!;
    var path = Path()
      ..moveTo(rect.left + topCorner, rect.top)
      ..lineTo(rect.right - topCorner, rect.top)
      ..cubicTo(
        rect.right - topCorner * (1 - topTangent),
        rect.top,
        rect.right,
        lerpDouble(rect.top, shoulderY, 0.45)!,
        rect.right,
        shoulderY,
      )
      ..lineTo(rect.right, math.max(shoulderY, rect.bottom - corner))
      ..cubicTo(
        rect.right,
        rect.bottom - corner * 0.4477,
        rect.right - corner * 0.4477,
        rect.bottom,
        rect.right - corner,
        rect.bottom,
      )
      ..lineTo(rect.left + corner, rect.bottom)
      ..cubicTo(
        rect.left + corner * 0.4477,
        rect.bottom,
        rect.left,
        rect.bottom - corner * 0.4477,
        rect.left,
        math.max(shoulderY, rect.bottom - corner),
      )
      ..lineTo(rect.left, shoulderY)
      ..cubicTo(
        rect.left,
        lerpDouble(rect.top, shoulderY, 0.45)!,
        rect.left + topCorner * (1 - topTangent),
        rect.top,
        rect.left + topCorner,
        rect.top,
      )
      ..close();

    final tint = compact ? 1.0 : _tint.transform(progress);
    final bodyColor = Color.lerp(Colors.black, surface, tint)!;
    final paint = Paint()..color = bodyColor;
    final neckOpacity =
        1 -
        const Interval(0.18, 0.28, curve: Curves.easeInOut).transform(progress);
    final hasCutout = geometry?.hasCutout ?? false;
    final isPunchHole = hasCutout && geometry?.shape == NotchShape.punchHole;
    final isPill = hasCutout && geometry?.shape == NotchShape.pill;

    // Overlap slightly into the hardware cutout/safe area to eliminate
    // subpixel anti-aliasing seams and active display gap artifacts.
    // Clamp upward overlap to the available screen anchor so painter coordinates
    // never paint above the FlutterView boundary (Y_screen < 0).
    final dpr = (geometry?.devicePixelRatio != null && geometry!.devicePixelRatio > 0)
        ? geometry!.devicePixelRatio
        : 1.0;
    // Overlap depth: at least 2.2dp to eliminate subpixel anti-aliasing gaps and
    // ensure continuous attachment with the physical aperture contour.
    final targetOverlap = math.max(2.2, (2.2 * dpr).round() / dpr);

    // Cutout vertical metrics in local painter coordinates (local y = 0 at anchorTop)
    final cutoutBottomLocal = hasCutout
        ? (geometry!.bottom - anchorTop)
        : 0.0;
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

    // Safe overlap limit: stays on screen (Y_screen >= 0) and preserves camera lens
    final maxSafeOverlap = hasCutout
        ? math.min(geometry!.bottom, cutoutRadiusY * 0.45)
        : 0.0;
    final deltaOverlap = hasCutout
        ? math.min(targetOverlap, math.max(0.0, maxSafeOverlap))
        : 0.0;

    // Apex: lowest boundary point of the cutout offset upward by deltaOverlap
    final yApex = cutoutBottomLocal - deltaOverlap;

    double? tailLeft;
    double? tailRight;
    double? tailTopY;

    if (renderMode == NotificationRenderMode.standard) {
      if (!compact && rect.bottom > 0 && neckOpacity > 0) {
        final join = math.max(0.0, centerY + height * 0.12);
        final neckSpan = width / 2;

        // Contact half-width at the aperture is bounded by physical cutout dimensions
        final cutoutHalfWidth = (geometry?.width != null && geometry!.width > 0)
            ? geometry!.width / 2
            : 16.0;
        final maxContactRadius = isPunchHole
            ? math.min(14.0, math.max(8.0, cutoutRadius * 0.88))
            : math.min(20.0, math.max(12.0, cutoutHalfWidth));

        final rTop = math.min(neckSpan * 0.95, maxContactRadius) * neckOpacity;

        // Calculate aperture contact Y and tangent angles following the lower contour
        double yContact = yApex;
        double contourRise = 0.0;
        double contactCos = 0.0;
        double contactSin = 1.0;
        if (hasCutout && rTop > 0) {
          if (isPunchHole) {
            final rClamped = math.min(rTop, cutoutRadius * 0.92);
            final cosAlpha = math.sqrt(math.max(0.0, cutoutRadius * cutoutRadius - rClamped * rClamped)) / cutoutRadius;
            final sinAlpha = rClamped / cutoutRadius;
            final yRim = cutoutCenterYLocal + cutoutRadius * cosAlpha;
            yContact = yRim - deltaOverlap;
            contourRise = math.max(0.0, yApex - yContact);
            contactCos = cosAlpha;
            contactSin = sinAlpha;
          } else if (isPill) {
            final flatHalf = math.max(0.0, (geometry!.width - geometry!.height) / 2);
            if (rTop > flatHalf) {
              final dx = math.min(cutoutRadius * 0.92, rTop - flatHalf);
              final cosAlpha = math.sqrt(math.max(0.0, cutoutRadius * cutoutRadius - dx * dx)) / cutoutRadius;
              final sinAlpha = dx / cutoutRadius;
              final yRim = cutoutCenterYLocal + cutoutRadius * cosAlpha;
              yContact = yRim - deltaOverlap;
              contourRise = math.max(0.0, yApex - yContact);
              contactCos = cosAlpha;
              contactSin = sinAlpha;
            }
          }
        }

        // Clamp yContact to not exceed negative screen boundary
        yContact = math.max(-anchorTop, yContact);
        final hNeck = math.max(0.0, join - yContact);

        if (rTop > 0 && hNeck > 0) {
          tailLeft = centerX - rTop;
          tailRight = centerX + rTop;
          tailTopY = yContact;

          // Waist position and pinched radius under gravity tension
          final yWaist = yApex + math.max(1.5, (join - yApex) * 0.40);
          final pinchFactor = 0.42 + 0.38 * (1.0 - fall);
          final rWaist = rTop * pinchFactor;

          // Merge radius at the junction with the drop body
          final rJoin =
              math.min(neckSpan * 0.88, rTop + (neckSpan - rTop) * 0.45);

          final tail = Path();
          // Start at top-left contact point
          tail.moveTo(centerX - rTop, yContact);

          // Top transition: smooth continuous Bézier following lower contour of camera aperture
          if (contourRise > 0.001) {
            final cpY = yApex + contourRise / 3.0;
            final cx = contactCos > 0.05
                ? math.min(rTop * 0.65, math.max(rTop * 0.35, (4.0 / 3.0) * contourRise * (cutoutRadius * contactCos) / math.max(1.0, rTop)))
                : rTop * 0.5;
            tail.cubicTo(
              centerX - rTop + cx,
              cpY,
              centerX + rTop - cx,
              cpY,
              centerX + rTop,
              yContact,
            );
          } else {
            tail.lineTo(centerX + rTop, yContact);
          }

          final h = math.max(1.0, yWaist - yContact);
          final w = math.max(0.1, rTop - rWaist);
          final double cp1x;
          final double cp1y;
          final double cp2x;
          final double cp2y;

          if (contactCos > 0.05) {
            final maxL1 = math.min(w / contactCos * 0.45, h / contactSin * 0.35);
            final l1 = math.max(1.0, maxL1);
            cp1x = centerX + rTop - l1 * contactCos;
            cp1y = yContact + l1 * contactSin;
            cp2x = centerX + rWaist + w * 0.06;
            cp2y = yWaist - math.min(4.0, h * 0.28);
          } else {
            cp1x = centerX + rTop - w * 0.15;
            cp1y = yContact + h * 0.38;
            cp2x = centerX + rWaist + w * 0.08;
            cp2y = yWaist - math.min(4.0, h * 0.30);
          }

          // Right flank: smooth tangent transition from aperture contact down to waist
          tail.cubicTo(
            cp1x,
            cp1y,
            cp2x,
            cp2y,
            centerX + rWaist,
            yWaist,
          );
          tail.cubicTo(
            centerX + rWaist,
            yWaist + (join - yWaist) * 0.35,
            centerX + rJoin * 0.90,
            join - (join - yWaist) * 0.35,
            centerX + rJoin,
            join,
          );

          // Bottom connection inside the drop body
          tail.lineTo(centerX - rJoin, join);

          // Left flank: from body join up to waist, then to top-left contact with mirror symmetry
          tail.cubicTo(
            centerX - rJoin * 0.90,
            join - (join - yWaist) * 0.35,
            centerX - rWaist,
            yWaist + (join - yWaist) * 0.35,
            centerX - rWaist,
            yWaist,
          );
          tail.cubicTo(
            2 * centerX - cp2x,
            cp2y,
            2 * centerX - cp1x,
            cp1y,
            centerX - rTop,
            yContact,
          );

          tail.close();
          path = Path.combine(PathOperation.union, path, tail);

          // Keep the attachment dark while the body lightens away from the edge.
          paint.shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(bodyColor, Colors.black, math.max(0.65, neckOpacity))!,
              bodyColor,
            ],
          ).createShader(
            Rect.fromLTRB(0, yContact, 1, math.max(join, 1)),
          );
        }
      }
    } else {
      // Experimental Liquid Renderer (inspired by liquid_notch silhouette bridge & absorption sweep)
      final cutoutHalfWidth = (geometry?.width != null && geometry!.width > 0)
          ? geometry!.width / 2
          : 16.0;
      final maxContactRadius = isPunchHole
          ? math.min(14.0, math.max(8.0, cutoutRadius * 0.88))
          : math.min(22.0, math.max(12.0, cutoutHalfWidth));

      final bool showBridge;
      final double bridgeOpacity;
      final double shoulder;
      final double waist;
      final double attach;
      final double join = math.max(0.0, centerY + height * 0.16);

      if (!compact && rect.bottom > 0) {
        if (!isExiting && progress <= 0.44) {
          showBridge = true;
          final bridgeFactor = (1.0 - (progress / 0.44)).clamp(0.0, 1.0);
          bridgeOpacity = Curves.easeIn.transform(bridgeFactor);
          // Shoulder tapers from aperture contact to a tight neck
          shoulder = math.min(maxContactRadius, 24.0) * (0.35 + 0.65 * bridgeFactor);
          // Waist pinches down under gravity tension and collapses cleanly to 0 at pinch-off
          final pinchFactor = Curves.easeInCubic.transform(bridgeFactor);
          waist = shoulder * 0.48 * pinchFactor;
          attach = math.min(width * 0.44, shoulder + 10.0 * bridgeFactor);
        } else if (isExiting && progress <= 0.65) {
          showBridge = true;
          final u = (progress / 0.65).clamp(0.0, 1.0);
          final suction = math.sin(math.pi * u);
          bridgeOpacity = (1.0 - u).clamp(0.0, 1.0);
          // During absorption, shoulder and waist emerge organically and taper smoothly to 0 at progress = 0
          shoulder = math.min(maxContactRadius * 1.25, 28.0) * math.pow(suction, 0.7);
          waist = shoulder * 0.55 * math.pow(suction, 0.9);
          attach = math.min(width * 0.46, shoulder + 12.0 * suction);
        } else {
          showBridge = false;
          bridgeOpacity = 0.0;
          shoulder = 0.0;
          waist = 0.0;
          attach = 0.0;
        }

        // Calculate aperture contact Y and tangent angles following the lower contour
        double yContact = yApex;
        double contourRise = 0.0;
        double contactCos = 0.0;
        double contactSin = 1.0;
        if (hasCutout && shoulder > 0) {
          if (isPunchHole) {
            final rClamped = math.min(shoulder, cutoutRadius * 0.92);
            final cosAlpha = math.sqrt(math.max(0.0, cutoutRadius * cutoutRadius - rClamped * rClamped)) / cutoutRadius;
            final sinAlpha = rClamped / cutoutRadius;
            final yRim = cutoutCenterYLocal + cutoutRadius * cosAlpha;
            yContact = yRim - deltaOverlap;
            contourRise = math.max(0.0, yApex - yContact);
            contactCos = cosAlpha;
            contactSin = sinAlpha;
          } else if (isPill) {
            final flatHalf = math.max(0.0, (geometry!.width - geometry!.height) / 2);
            if (shoulder > flatHalf) {
              final dx = math.min(cutoutRadius * 0.92, shoulder - flatHalf);
              final cosAlpha = math.sqrt(math.max(0.0, cutoutRadius * cutoutRadius - dx * dx)) / cutoutRadius;
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

        if (showBridge && shoulder > 0 && waist > 0 && join > yContact) {
          tailLeft = centerX - math.max(shoulder, attach);
          tailRight = centerX + math.max(shoulder, attach);
          tailTopY = yContact;
          final waistY = math.max(yApex + 2.0, lerpDouble(yApex, rect.top, 0.58)!);

          final bridge = Path();
          bridge.moveTo(centerX - shoulder, yContact);

          if (contourRise > 0.001) {
            final cpY = yApex + contourRise / 3.0;
            final cx = contactCos > 0.05
                ? math.min(shoulder * 0.65, math.max(shoulder * 0.35, (4.0 / 3.0) * contourRise * (cutoutRadius * contactCos) / math.max(1.0, shoulder)))
                : shoulder * 0.5;
            bridge.cubicTo(
              centerX - shoulder + cx,
              cpY,
              centerX + shoulder - cx,
              cpY,
              centerX + shoulder,
              yContact,
            );
          } else {
            bridge.lineTo(centerX + shoulder, yContact);
          }

          final h = math.max(1.0, waistY - yContact);
          final w = math.max(0.1, shoulder - waist);
          final double cp1x;
          final double cp1y;
          final double cp2x;
          final double cp2y;

          if (contactCos > 0.05) {
            final maxL1 = math.min(w / contactCos * 0.45, h / contactSin * 0.35);
            final l1 = math.max(1.0, maxL1);
            cp1x = centerX + shoulder - l1 * contactCos;
            cp1y = yContact + l1 * contactSin;
            cp2x = centerX + waist + w * 0.06;
            cp2y = waistY - math.min(4.0, h * 0.28);
          } else {
            cp1x = centerX + shoulder - w * 0.15;
            cp1y = yContact + h * 0.38;
            cp2x = centerX + waist + w * 0.10;
            cp2y = waistY - math.min(4.0, h * 0.30);
          }

          // Concave cubic shoulder down to waist with tangent continuity
          bridge.cubicTo(
            cp1x,
            cp1y,
            cp2x,
            cp2y,
            centerX + waist,
            waistY,
          );
          // Waist to target attachment
          bridge.cubicTo(
            centerX + waist,
            waistY + 6,
            centerX + attach,
            join - 6,
            centerX + attach,
            join,
          );
          bridge.lineTo(centerX - attach, join);
          bridge.cubicTo(
            centerX - attach,
            join - 6,
            centerX - waist,
            waistY + 6,
            centerX - waist,
            waistY,
          );
          bridge.cubicTo(
            2 * centerX - cp2x,
            cp2y,
            2 * centerX - cp1x,
            cp1y,
            centerX - shoulder,
            yContact,
          );
          bridge.close();

          path = Path.combine(PathOperation.union, path, bridge);

          paint.shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(bodyColor, Colors.black, math.max(0.65, bridgeOpacity))!,
              bodyColor,
            ],
          ).createShader(
            Rect.fromLTRB(0, yContact, 1, math.max(join, 1)),
          );
        }
      }
    }

    final tailPad = (tailLeft != null && tailRight != null)
        ? math.max(28.0, (tailRight - tailLeft) / 2 + 16.0)
        : 28.0;
    final clipLeft = tailLeft != null
        ? math.min(-24.0, math.min(rect.left, centerX - tailPad))
        : math.min(-24.0, rect.left);
    final clipRight = tailRight != null
        ? math.max(size.width + 24.0, math.max(rect.right, centerX + tailPad))
        : math.max(size.width + 24.0, rect.right);
    final minPathY = tailTopY ?? 0.0;
    final maxAnchorOverlap = math.max(0.0, anchorTop);
    final clipTop = hasCutout
        ? math.min(minPathY, -math.min(16.0, maxAnchorOverlap))
        : -math.min(16.0, maxAnchorOverlap);

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        clipLeft,
        clipTop,
        clipRight,
        size.height + 24,
      ),
    );
    if (expand > 0) {
      canvas.drawShadow(
        path,
        Colors.black.withValues(alpha: 0.26 * expand),
        12,
        true,
      );
    }
    canvas.drawPath(path, paint);
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
    canvas.drawLine(
      Offset(centerX, -12),
      Offset(centerX, 12),
      originPaint,
    );

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
      old.isExiting != isExiting;
}
