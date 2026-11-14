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

const _fall = Interval(0.02, 0.46, curve: Curves.easeInOutQuad);
const _expand = Interval(0.46, 0.82, curve: Curves.easeInOutCubic);
const _reveal = Interval(0.64, 0.96, curve: Curves.easeOutCubic);
const _tint = Interval(0.15, 0.40, curve: Curves.easeInOutCubic);

/// Rendering engine used to animate the notification entrance and fluid silhouette.
enum NotificationRenderMode {
  /// Verified fluid morphology renderer (standard physics-based pendant drop).
  standard,
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
      0.0,
      0.24,
      curve: Curves.easeOutCubic,
    ).transform(progress);

    final double eggFactor;
    if (compact || isExiting || progress > 0.44) {
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
              math.pi * (progress / (isExiting ? 0.42 : 0.36)).clamp(0.0, 1.0),
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
    final rect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: width,
      height: height,
    );

    final radius = math.min(width, height) / 2;
    final cardCorner = math.min(
      borderRadius ?? (cardHeight / 2),
      cardHeight / 2,
    );
    final corner = lerpDouble(radius, cardCorner, expand)!;
    final topFlat = math.max(0.0, width / 2 - corner);
    final botFlat = math.max(0.0, width / 2 - corner);

    final tint = compact ? 1.0 : _tint.transform(progress);
    final bodyColor = Color.lerp(Colors.black, surface, tint)!;
    final paint = Paint()..color = bodyColor;
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

    double? tailLeft;
    double? tailRight;
    double? tailTopY;

    final cutoutHalfWidth = (geometry?.width != null && geometry!.width > 0)
        ? geometry!.width / 2
        : 16.0;
    final maxContactRadius = isPunchHole
        ? math.min(14.0, math.max(8.0, cutoutRadius * 0.88))
        : (isPill
              ? math.min(52.0, math.max(28.0, cutoutHalfWidth * 0.78))
              : math.min(48.0, math.max(16.0, cutoutHalfWidth * 0.78)));

    Path path;

    final isAttachedEntrance = !compact && !isExiting && progress <= 0.28;
    if (isAttachedEntrance) {
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

      // If exiting and within suction interval, connect exit bridge
      if (isExiting && progress <= 0.60 && rect.bottom > 0) {
        final u = (progress / 0.60).clamp(0.0, 1.0);
        final suction = math.sin(math.pi * u);
        final bridgeOpacity = (1.0 - u).clamp(0.0, 1.0);
        final shoulder =
            math.min(maxContactRadius * 1.25, 26.0) * math.pow(suction, 0.7);
        final waist = shoulder * 0.52 * math.pow(suction, 0.9);
        final attach = math.min(width * 0.46, shoulder + 12.0 * suction);
        final join = math.max(yApex + 2.0, rect.top + height * 0.22);
        final yContact = math.max(-anchorTop, yApex);

        if (shoulder > 0 && waist > 0 && join > yContact) {
          tailLeft = centerX - math.max(shoulder, attach);
          tailRight = centerX + math.max(shoulder, attach);
          tailTopY = yContact;
          final waistY = math.max(
            yApex + 2.0,
            lerpDouble(yApex, rect.top, 0.55)!,
          );

          final bridge = Path()
            ..moveTo(centerX - shoulder, yContact)
            ..lineTo(centerX + shoulder, yContact)
            ..cubicTo(
              centerX + shoulder - (shoulder - waist) * 0.18,
              yContact + (waistY - yContact) * 0.40,
              centerX + waist + (shoulder - waist) * 0.08,
              waistY - math.min(4.0, (waistY - yContact) * 0.28),
              centerX + waist,
              waistY,
            )
            ..cubicTo(
              centerX + waist,
              waistY + (join - waistY) * 0.35,
              centerX + attach * 0.92,
              join - (join - waistY) * 0.35,
              centerX + attach,
              join,
            )
            ..lineTo(centerX - attach, join)
            ..cubicTo(
              centerX - attach * 0.92,
              join - (join - waistY) * 0.35,
              centerX - waist,
              waistY + (join - waistY) * 0.35,
              centerX - waist,
              waistY,
            )
            ..cubicTo(
              centerX - waist - (shoulder - waist) * 0.08,
              waistY - math.min(4.0, (waistY - yContact) * 0.28),
              centerX - shoulder + (shoulder - waist) * 0.18,
              yContact + (waistY - yContact) * 0.40,
              centerX - shoulder,
              yContact,
            )
            ..close();

          path = Path.combine(PathOperation.union, path, bridge);

          if (bodyColor != Colors.black) {
            paint.shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(
                  bodyColor,
                  Colors.black,
                  math.max(0.65, bridgeOpacity),
                )!,
                bodyColor,
              ],
            ).createShader(Rect.fromLTRB(0, yContact, 1, math.max(join, 1)));
          }
        }
      }
    }

    // Meniscus tip remaining on the Dynamic Island aperture after detachment
    final bool showMeniscus =
        !compact && !isExiting && isPill && progress > 0.28 && progress <= 0.40;
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
      Rect.fromLTRB(clipLeft, clipTop, clipRight, size.height + 24),
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
      old.isExiting != isExiting;
}
