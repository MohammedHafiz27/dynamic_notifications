import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The origin source of a [NotchGeometry] measurement.
enum NotchGeometrySource {
  /// Cutout bounding rectangle reported directly by the operating system
  /// via hardware display features (`DisplayFeatureType.cutout`).
  displayFeature,

  /// Inferred from calibrated platform device profiles (e.g. iOS Dynamic Island
  /// or notch top safe-area insets).
  profile,

  /// Inferred from system safe area or status bar insets.
  safeArea,

  /// Provided by optional native platform cutout path (e.g. Android API 31+ getCutoutPath).
  nativePath,

  /// No cutout is present on this device or display.
  none,
}

/// Confidence level of the detected [NotchGeometry].
enum NotchGeometryConfidence {
  /// Measured directly from operating system display APIs with exact bounds.
  exact,

  /// Calibrated against known device families and verified simulator profiles.
  calibrated,

  /// Inferred from fallback heuristics such as status bar height.
  fallback,

  /// Confirmed that no cutout exists.
  none,
}

/// The physical shape profile of the device notch or cutout.
enum NotchShape {
  /// Compact circular or square camera cutout (e.g. standard Android punch hole).
  punchHole,

  /// Elongated pill-shaped cutout (e.g. Dynamic Island or dual-camera hole).
  pill,

  /// Wide notch attached to the upper display edge (e.g. iPhone notch).
  notch,

  /// No notch or cutout.
  none,
}

/// The screen edge where the cutout or notch is located.
enum CutoutEdge {
  /// Cutout located along or attached to the top display edge.
  top,

  /// Cutout located along or attached to the left display edge.
  left,

  /// Cutout located along or attached to the right display edge.
  right,

  /// Cutout located along or attached to the bottom display edge.
  bottom,

  /// No cutout is present.
  none,
}

/// Geometric properties of the screen's hardware camera cutout, notch, or island.
@immutable
class NotchGeometry {
  const NotchGeometry({
    this.bounds,
    required this.center,
    required this.width,
    required this.height,
    required this.top,
    required this.bottom,
    required this.screenSize,
    required this.insets,
    required this.source,
    required this.confidence,
    required this.shape,
    required this.hasCutout,
    CutoutEdge? edge,
    this.devicePixelRatio = 1.0,
  }) : edge = edge ?? (hasCutout ? CutoutEdge.top : CutoutEdge.none);

  /// The bounding rectangle of the cutout in logical pixels, if available.
  final Rect? bounds;

  /// The anchor center point of the cutout or fallback status bar in logical pixels.
  final Offset center;

  /// The width of the cutout in logical pixels (0.0 if no cutout).
  final double width;

  /// The height of the cutout in logical pixels (0.0 if no cutout).
  final double height;

  /// The top edge of the cutout in logical pixels.
  final double top;

  /// The bottom edge of the cutout in logical pixels.
  final double bottom;

  /// Dimensions of the active window or screen in logical pixels.
  final Size screenSize;

  /// System view padding / insets in logical pixels.
  final EdgeInsets insets;

  /// The origin source of this geometry.
  final NotchGeometrySource source;

  /// Confidence level in this geometry.
  final NotchGeometryConfidence confidence;

  /// Physical shape category of the cutout.
  final NotchShape shape;

  /// Whether a physical camera cutout, notch, or island was detected.
  final bool hasCutout;

  /// Screen edge where the cutout is located.
  final CutoutEdge edge;

  /// The device pixel ratio at the time of measurement.
  final double devicePixelRatio;

  /// Horizontal anchor coordinate in logical pixels.
  double get anchorX => center.dx;

  /// Suggested vertical anchor coordinate where the water drop should originate.
  double get anchorTop {
    if (!hasCutout || edge != CutoutEdge.top) return math.max(0.0, insets.top);
    if (source == NotchGeometrySource.profile) {
      return math.max(0.0, bottom);
    }
    return math.max(0.0, bottom - 1.0);
  }

  /// Whether a physical cutout is located along the top display edge.
  bool get hasTopCutout => hasCutout && edge == CutoutEdge.top;

  /// The 2D origin point where the notification liquid morph begins.
  ///
  /// For top-edge cutouts (including top-center, top-left, and top-right corner cameras),
  /// this follows the actual camera cutout's horizontal coordinate and anchor top.
  ///
  /// For physical side-edge cutouts (left/right) or bottom-only cutouts,
  /// this returns the virtual top-center origin of the current display.
  Offset get animationOrigin {
    if (hasTopCutout) {
      return Offset(anchorX, anchorTop);
    }
    final viewportCenter = screenSize.width > 0
        ? (insets.left + screenSize.width - insets.right) / 2
        : 0.0;
    final safeTop = insets.top + 4.0;
    return Offset(viewportCenter, safeTop);
  }

  /// Exact 2D anchor point where the fluid droplet emerges into the display.
  Offset get anchorPoint {
    switch (edge) {
      case CutoutEdge.left:
        final x = hasCutout
            ? math.max(0.0, bounds != null ? bounds!.right - 1.0 : insets.left)
            : insets.left;
        return Offset(x, center.dy);
      case CutoutEdge.right:
        final x = hasCutout
            ? math.min(
                screenSize.width,
                bounds != null
                    ? bounds!.left + 1.0
                    : screenSize.width - insets.right,
              )
            : screenSize.width - insets.right;
        return Offset(x, center.dy);
      case CutoutEdge.bottom:
        final y = hasCutout
            ? math.min(
                screenSize.height,
                bounds != null
                    ? bounds!.top + 1.0
                    : screenSize.height - insets.bottom,
              )
            : screenSize.height - insets.bottom;
        return Offset(center.dx, y);
      case CutoutEdge.top:
      case CutoutEdge.none:
        return Offset(anchorX, anchorTop);
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotchGeometry &&
        other.bounds == bounds &&
        other.center == center &&
        other.width == width &&
        other.height == height &&
        other.top == top &&
        other.bottom == bottom &&
        other.screenSize == screenSize &&
        other.insets == insets &&
        other.source == source &&
        other.confidence == confidence &&
        other.shape == shape &&
        other.hasCutout == hasCutout &&
        other.edge == edge &&
        other.devicePixelRatio == devicePixelRatio;
  }

  @override
  int get hashCode => Object.hash(
        bounds,
        center,
        width,
        height,
        top,
        bottom,
        screenSize,
        insets,
        source,
        confidence,
        shape,
        hasCutout,
        edge,
        devicePixelRatio,
      );

  @override
  String toString() =>
      'NotchGeometry(shape: $shape, edge: $edge, source: $source, confidence: $confidence, '
      'bounds: $bounds, bottom: $bottom, hasCutout: $hasCutout)';
}

/// Detects and classifies notch and camera cutout geometry from [BuildContext]
/// or [MediaQueryData].
class NotchGeometryDetector {
  const NotchGeometryDetector._();

  /// Detects notch geometry from the provided [BuildContext].
  static NotchGeometry detect(BuildContext context) {
    final mq = MediaQuery.of(context);
    final platform = Theme.of(context).platform;
    final cached = AndroidCutoutGeometryProvider.instance.cached;
    if (platform == TargetPlatform.android &&
        cached != null &&
        cached.screenSize == mq.size &&
        cached.devicePixelRatio == mq.devicePixelRatio) {
      return cached;
    }
    return fromMediaQuery(
      mediaQuery: mq,
      platform: platform,
    );
  }

  /// Detects and resolves notch geometry from [mediaQuery] and [platform].
  static NotchGeometry fromMediaQuery({
    required MediaQueryData mediaQuery,
    required TargetPlatform platform,
  }) {
    final insets = mediaQuery.viewPadding != EdgeInsets.zero
        ? mediaQuery.viewPadding
        : mediaQuery.padding;
    final padding = insets;
    final size = mediaQuery.size;
    final orientation = mediaQuery.orientation;
    final dpr = mediaQuery.devicePixelRatio;
    final viewportCenter = (padding.left + size.width - padding.right) / 2;

    // 1. Check for physical cutout display features
    final topCandidates = <Rect>[];
    final leftCandidates = <Rect>[];
    final rightCandidates = <Rect>[];
    final bottomCandidates = <Rect>[];

    for (final feature in mediaQuery.displayFeatures) {
      if (feature.type != DisplayFeatureType.cutout) continue;
      final bounds = feature.bounds;
      if (bounds.isEmpty || !bounds.isFinite) continue;

      // Classify edge based on position, insets, and screen boundaries
      final topLimit = math.max(padding.top, 32.0);
      final bottomLimit = math.max(padding.top + 24.0, 68.0);
      final sideMarginLeft = math.max(padding.left, 48.0);
      final sideMarginRight = math.max(padding.right, 48.0);

      final hasTopInset = padding.top > 0;
      final isInsideTopInset = hasTopInset &&
          bounds.top <= padding.top &&
          bounds.bottom <= math.max(padding.top + 8.0, 48.0);

      final isInsideLeftInset =
          padding.left > 0 && bounds.right <= padding.left + 4.0;
      final isInsideRightInset =
          padding.right > 0 && bounds.left >= size.width - padding.right - 4.0;

      final isTopRegion =
          bounds.top <= topLimit && bounds.bottom <= bottomLimit;
      final isBottomRegion =
          bounds.bottom >= size.height - math.max(padding.bottom, 48.0);

      // In portrait, any cutout situated in the top safe area / status bar region belongs
      // to the top edge (e.g. Honor View 20 corner punch-hole) and must never be misclassified as a side cutout.
      // In landscape, top-edge cutouts are identified when within the top inset and outside side insets.
      final isTopCutout = (orientation == Orientation.portrait &&
              (isInsideTopInset || isTopRegion)) ||
          (isInsideTopInset && !isInsideLeftInset && !isInsideRightInset) ||
          (isTopRegion &&
              !isInsideLeftInset &&
              !isInsideRightInset &&
              padding.left == 0 &&
              padding.right == 0 &&
              bounds.top <= 8.0);

      final isLeftSide = !isTopCutout &&
          (isInsideLeftInset ||
              (bounds.left <= 2.0 &&
                  bounds.width < size.width * 0.5 &&
                  !isTopRegion) ||
              (orientation == Orientation.landscape &&
                  bounds.left <= sideMarginLeft &&
                  bounds.width < size.width * 0.5 &&
                  !isInsideTopInset));

      final isRightSide = !isTopCutout &&
          (isInsideRightInset ||
              (bounds.right >= size.width - 2.0 &&
                  bounds.width < size.width * 0.5 &&
                  !isTopRegion) ||
              (orientation == Orientation.landscape &&
                  bounds.right >= size.width - sideMarginRight &&
                  bounds.width < size.width * 0.5 &&
                  !isInsideTopInset));

      if (isLeftSide || isRightSide) {
        if (isLeftSide) {
          leftCandidates.add(bounds);
        } else {
          rightCandidates.add(bounds);
        }
      } else if (isTopCutout || isTopRegion) {
        topCandidates.add(bounds);
      } else if (isBottomRegion) {
        bottomCandidates.add(bounds);
      } else {
        // Fallback by minimum distance to edges
        final dTop = bounds.top;
        final dBottom = size.height - bounds.bottom;
        final dLeft = bounds.left;
        final dRight = size.width - bounds.right;
        final minD = math.min(math.min(dTop, dBottom), math.min(dLeft, dRight));
        if (minD == dTop) {
          topCandidates.add(bounds);
        } else if (minD == dLeft) {
          leftCandidates.add(bounds);
        } else if (minD == dRight) {
          rightCandidates.add(bounds);
        } else {
          bottomCandidates.add(bounds);
        }
      }
    }

    // Multiple Cutout Priority:
    // 1. Top cutout takes priority.
    // 2. Otherwise select a valid left or right cutout.
    // 3. Bottom-only cutouts retain the safe existing fallback.
    // 4. Never combine unrelated cutouts into one bounding rectangle.
    if (topCandidates.isNotEmpty) {
      // Find candidate closest to viewport center
      topCandidates.sort((a, b) => (a.center.dx - viewportCenter)
          .abs()
          .compareTo((b.center.dx - viewportCenter).abs()));

      Rect resolved = topCandidates.first;
      if (topCandidates.length > 1) {
        final second = topCandidates[1];
        // If two cutouts are adjacent (e.g. dual punch holes separated by a small gap),
        // combine their bounding boxes into a single cluster.
        final gapX = (resolved.center.dx - second.center.dx).abs() -
            (resolved.width + second.width) / 2;
        if (gapX <= 16.0 && (resolved.top - second.top).abs() <= 12.0) {
          resolved = resolved.expandToInclude(second);
        }
      }

      // On Android, DisplayCutout.getBoundingRects() snaps cutouts to the upper display edge
      // (top = 0.0) and extends the bottom boundary to the status bar insets (insets.top).
      // We must detect whether this is a status-bar-extended bounding box for an enclosed camera
      // (punch hole or pill), or a true physical notch cut into the bezel.
      if (platform == TargetPlatform.android && resolved.top <= 2.0) {
        final statusBarHeight = math.max(padding.top, resolved.bottom);
        final touchesStatusBarBottom =
            (resolved.bottom - padding.top).abs() <= 3.0 ||
                resolved.bottom >= padding.top - 2.0;

        if (touchesStatusBarBottom) {
          if (resolved.width <= 72.0) {
            // Standard single circular punch hole camera inside the status bar.
            // In Android status bar layouts, the camera aperture is vertically centered
            // with the status bar icons (Y_center ≈ 0.52 * H) with radius ~12..16dp.
            final radius = math.min(
              resolved.width / 2,
              math.min(16.0, statusBarHeight * 0.32),
            );
            final centerY = statusBarHeight * 0.52;
            final physicalBottom = math.min(
              resolved.bottom,
              statusBarHeight -
                  math.max(4.0, math.min(8.5, statusBarHeight * 0.18)),
            );
            final physicalWidth =
                math.min(resolved.width, math.max(24.0, radius * 2));
            final physicalBounds = Rect.fromCenter(
              center: Offset(resolved.center.dx, centerY),
              width: physicalWidth,
              height: radius * 2,
            );
            return NotchGeometry(
              bounds: physicalBounds,
              center: physicalBounds.center,
              width: physicalWidth,
              height: radius * 2,
              top: math.max(0.0, physicalBounds.top),
              bottom: physicalBottom,
              screenSize: size,
              insets: padding,
              source: NotchGeometrySource.displayFeature,
              confidence: NotchGeometryConfidence.calibrated,
              shape: NotchShape.punchHole,
              hasCutout: true,
              edge: CutoutEdge.top,
              devicePixelRatio: dpr,
            );
          } else if (resolved.width <= 120.0) {
            // Pill / dual camera punch hole inside the status bar
            final physicalBottom = math.min(
              resolved.bottom,
              statusBarHeight -
                  math.max(3.0, math.min(7.0, statusBarHeight * 0.15)),
            );
            return NotchGeometry(
              bounds: resolved,
              center: resolved.center,
              width: resolved.width,
              height: resolved.height,
              top: resolved.top,
              bottom: physicalBottom,
              screenSize: size,
              insets: padding,
              source: NotchGeometrySource.displayFeature,
              confidence: NotchGeometryConfidence.calibrated,
              shape: NotchShape.pill,
              hasCutout: true,
              edge: CutoutEdge.top,
              devicePixelRatio: dpr,
            );
          }
        }
      }

      final shape = _classifyShape(resolved, CutoutEdge.top);
      return NotchGeometry(
        bounds: resolved,
        center: resolved.center,
        width: resolved.width,
        height: resolved.height,
        top: resolved.top,
        bottom: resolved.bottom,
        screenSize: size,
        insets: padding,
        source: NotchGeometrySource.displayFeature,
        confidence: NotchGeometryConfidence.exact,
        shape: shape,
        hasCutout: true,
        edge: CutoutEdge.top,
        devicePixelRatio: dpr,
      );
    }

    if (leftCandidates.isNotEmpty) {
      final viewportVerticalCenter = (padding.top + size.height - padding.bottom) / 2;
      leftCandidates.sort((a, b) => (a.center.dy - viewportVerticalCenter)
          .abs()
          .compareTo((b.center.dy - viewportVerticalCenter).abs()));

      Rect resolved = leftCandidates.first;
      if (leftCandidates.length > 1) {
        final second = leftCandidates[1];
        final gapY = (resolved.center.dy - second.center.dy).abs() -
            (resolved.height + second.height) / 2;
        if (gapY <= 16.0 && (resolved.left - second.left).abs() <= 12.0) {
          resolved = resolved.expandToInclude(second);
        }
      }

      final shape = _classifyShape(resolved, CutoutEdge.left);
      return NotchGeometry(
        bounds: resolved,
        center: resolved.center,
        width: resolved.width,
        height: resolved.height,
        top: resolved.top,
        bottom: resolved.bottom,
        screenSize: size,
        insets: padding,
        source: NotchGeometrySource.displayFeature,
        confidence: NotchGeometryConfidence.exact,
        shape: shape,
        hasCutout: true,
        edge: CutoutEdge.left,
        devicePixelRatio: dpr,
      );
    }

    if (rightCandidates.isNotEmpty) {
      final viewportVerticalCenter = (padding.top + size.height - padding.bottom) / 2;
      rightCandidates.sort((a, b) => (a.center.dy - viewportVerticalCenter)
          .abs()
          .compareTo((b.center.dy - viewportVerticalCenter).abs()));

      Rect resolved = rightCandidates.first;
      if (rightCandidates.length > 1) {
        final second = rightCandidates[1];
        final gapY = (resolved.center.dy - second.center.dy).abs() -
            (resolved.height + second.height) / 2;
        if (gapY <= 16.0 && (resolved.right - second.right).abs() <= 12.0) {
          resolved = resolved.expandToInclude(second);
        }
      }

      final shape = _classifyShape(resolved, CutoutEdge.right);
      return NotchGeometry(
        bounds: resolved,
        center: resolved.center,
        width: resolved.width,
        height: resolved.height,
        top: resolved.top,
        bottom: resolved.bottom,
        screenSize: size,
        insets: padding,
        source: NotchGeometrySource.displayFeature,
        confidence: NotchGeometryConfidence.exact,
        shape: shape,
        hasCutout: true,
        edge: CutoutEdge.right,
        devicePixelRatio: dpr,
      );
    }

    // 2. Check for calibrated iOS profiles (where Apple APIs do not expose physical cutout bounds)
    if (platform == TargetPlatform.iOS &&
        orientation == Orientation.portrait &&
        padding.top >= 44.0) {
      final double edge;
      final NotchShape shape;
      final double width;
      final double height;
      final double top;

      if (padding.top >= 58.0) {
        // iPhone 14 Pro, 14 Pro Max, 15 series, 16 series (Dynamic Island)
        edge = padding.top >= 62.0 ? 50.0 : 48.0;
        shape = NotchShape.pill;
        width = 126.0;
        height = 37.0;
        top = math.max(0.0, edge - height);
      } else if (padding.top >= 50.0) {
        // iPhone 13 Pro / 14 (compact notch)
        edge = 36.0;
        shape = NotchShape.notch;
        width = 160.0;
        height = 36.0;
        top = 0.0;
      } else if (padding.top >= 47.0) {
        // iPhone 12 / 13 / 14 / 16e standard notch
        edge = 31.0;
        shape = NotchShape.notch;
        width = 180.0;
        height = 31.0;
        top = 0.0;
      } else {
        // iPhone X / XS / 11 standard notch
        edge = 29.0;
        shape = NotchShape.notch;
        width = 208.0;
        height = 29.0;
        top = 0.0;
      }

      final bottom = math.min(padding.top - 2.0, edge);
      final bounds = Rect.fromCenter(
        center: Offset(viewportCenter, (top + bottom) / 2),
        width: width,
        height: bottom - top,
      );

      return NotchGeometry(
        bounds: bounds,
        center: Offset(viewportCenter, (top + bottom) / 2),
        width: width,
        height: bottom - top,
        top: top,
        bottom: bottom,
        screenSize: size,
        insets: padding,
        source: NotchGeometrySource.profile,
        confidence: NotchGeometryConfidence.calibrated,
        shape: shape,
        hasCutout: true,
        devicePixelRatio: dpr,
      );
    }

    // 3. Fallback: device without cutout or unsupported platform
    final hasInsets = padding.top > 0;
    return NotchGeometry(
      bounds: null,
      center: Offset(viewportCenter, padding.top / 2),
      width: 0.0,
      height: 0.0,
      top: 0.0,
      bottom: padding.top,
      screenSize: size,
      insets: padding,
      source: hasInsets ? NotchGeometrySource.safeArea : NotchGeometrySource.none,
      confidence: hasInsets
          ? NotchGeometryConfidence.fallback
          : NotchGeometryConfidence.none,
      shape: NotchShape.none,
      hasCutout: false,
      devicePixelRatio: dpr,
    );
  }

  static NotchShape _classifyShape(Rect bounds, [CutoutEdge edge = CutoutEdge.top]) {
    // Cutouts attached to or touching the display edge are notches if wide
    if (edge == CutoutEdge.top && bounds.top <= 2.0) {
      return NotchShape.notch;
    }
    if (edge == CutoutEdge.left && bounds.left <= 2.0 && bounds.width > 36.0) {
      return NotchShape.notch;
    }
    if (edge == CutoutEdge.right && bounds.width > 36.0) {
      return NotchShape.notch;
    }
    final aspect = bounds.width / math.max(1.0, bounds.height);
    if (aspect > 1.35 || aspect < 0.74) {
      return NotchShape.pill;
    }
    return NotchShape.punchHole;
  }
}

/// Optional cached geometry provider that queries native Android [DisplayCutout] APIs
/// (including Android 12+ / API 31+ [DisplayCutout.getCutoutPath]) via a platform channel.
class AndroidCutoutGeometryProvider {
  AndroidCutoutGeometryProvider({
    this.channel = const MethodChannel('dynamic_notifications/android_geometry'),
  });

  /// The shared singleton instance.
  static final AndroidCutoutGeometryProvider instance =
      AndroidCutoutGeometryProvider();

  /// The platform channel used to communicate with the host Android activity.
  final MethodChannel channel;

  NotchGeometry? _cached;
  Future<NotchGeometry?>? _pendingLoad;

  /// Returns the cached [NotchGeometry] if available, otherwise null.
  NotchGeometry? get cached => _cached;

  /// Sets the cached geometry directly for unit testing.
  @visibleForTesting
  set cachedForTesting(NotchGeometry? value) => _cached = value;

  /// Asynchronously queries native Android cutout geometry, caches the result,
  /// and returns a resolved [NotchGeometry].
  Future<NotchGeometry?> load({
    required MediaQueryData mediaQuery,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cached != null &&
        _cached!.screenSize == mediaQuery.size &&
        _cached!.devicePixelRatio == mediaQuery.devicePixelRatio) {
      return _cached;
    }
    if (_pendingLoad != null) {
      return _pendingLoad;
    }
    final future = _loadInternal(mediaQuery);
    _pendingLoad = future;
    try {
      return await future;
    } finally {
      if (identical(_pendingLoad, future)) {
        _pendingLoad = null;
      }
    }
  }

  Future<NotchGeometry?> _loadInternal(MediaQueryData mediaQuery) async {
    try {
      final res =
          await channel.invokeMapMethod<String, dynamic>('getCutoutGeometry');
      if (res == null) return null;
      final hasCutout = res['hasCutout'] as bool? ?? false;
      final insets = mediaQuery.viewPadding != EdgeInsets.zero
          ? mediaQuery.viewPadding
          : mediaQuery.padding;

      if (!hasCutout) {
        _cached = NotchGeometry(
          bounds: null,
          center: Offset(mediaQuery.size.width / 2, mediaQuery.padding.top / 2),
          width: 0.0,
          height: 0.0,
          top: 0.0,
          bottom: mediaQuery.padding.top,
          screenSize: mediaQuery.size,
          insets: insets,
          source: mediaQuery.padding.top > 0
              ? NotchGeometrySource.safeArea
              : NotchGeometrySource.none,
          confidence: mediaQuery.padding.top > 0
              ? NotchGeometryConfidence.fallback
              : NotchGeometryConfidence.none,
          shape: NotchShape.none,
          hasCutout: false,
          edge: CutoutEdge.none,
          devicePixelRatio: mediaQuery.devicePixelRatio,
        );
        return _cached;
      }

      final edgeStr = res['edge'] as String?;
      final CutoutEdge edge;
      switch (edgeStr) {
        case 'left':
          edge = CutoutEdge.left;
          break;
        case 'right':
          edge = CutoutEdge.right;
          break;
        case 'bottom':
          edge = CutoutEdge.bottom;
          break;
        case 'top':
          edge = CutoutEdge.top;
          break;
        default:
          edge = CutoutEdge.top;
      }

      if (edge == CutoutEdge.bottom) {
        // Bottom-only cutouts retain the safe existing fallback
        _cached = NotchGeometry(
          bounds: null,
          center: Offset(mediaQuery.size.width / 2, mediaQuery.padding.top / 2),
          width: 0.0,
          height: 0.0,
          top: 0.0,
          bottom: mediaQuery.padding.top,
          screenSize: mediaQuery.size,
          insets: insets,
          source: mediaQuery.padding.top > 0
              ? NotchGeometrySource.safeArea
              : NotchGeometrySource.none,
          confidence: mediaQuery.padding.top > 0
              ? NotchGeometryConfidence.fallback
              : NotchGeometryConfidence.none,
          shape: NotchShape.none,
          hasCutout: false,
          edge: CutoutEdge.none,
          devicePixelRatio: mediaQuery.devicePixelRatio,
        );
        return _cached;
      }

      final dpr =
          mediaQuery.devicePixelRatio > 0 ? mediaQuery.devicePixelRatio : 1.0;
      final hasPath = res['hasPath'] as bool? ?? false;
      Rect? resolvedBounds;
      NotchGeometrySource source = NotchGeometrySource.displayFeature;

      // Extract edge-specific boundingRect (API 28+)
      Rect? boundRect;
      if (res.containsKey('boundLeft')) {
        final bLeft = (res['boundLeft'] as num).toDouble();
        final bTop = (res['boundTop'] as num).toDouble();
        final bRight = (res['boundRight'] as num).toDouble();
        final bBottom = (res['boundBottom'] as num).toDouble();
        final candidate =
            Rect.fromLTRB(bLeft / dpr, bTop / dpr, bRight / dpr, bBottom / dpr);
        if (candidate.isFinite &&
            !candidate.isEmpty &&
            candidate.width > 0 &&
            candidate.height > 0) {
          boundRect = candidate;
        }
      }

      // 1. Prefer and validate native cutoutPath on API 31+
      // Ensure candidate path bounds do not combine unrelated cutouts across screens
      if (hasPath && res.containsKey('pathLeft')) {
        final pLeft = (res['pathLeft'] as num).toDouble();
        final pTop = (res['pathTop'] as num).toDouble();
        final pRight = (res['pathRight'] as num).toDouble();
        final pBottom = (res['pathBottom'] as num).toDouble();
        final candidate =
            Rect.fromLTRB(pLeft / dpr, pTop / dpr, pRight / dpr, pBottom / dpr);
        final isValidCandidate = candidate.isFinite &&
            !candidate.isEmpty &&
            candidate.width > 0 &&
            candidate.height > 0 &&
            (boundRect == null ||
                (candidate.left >= boundRect.left - 4.0 &&
                    candidate.top >= boundRect.top - 4.0 &&
                    candidate.right <= boundRect.right + 4.0 &&
                    candidate.bottom <= boundRect.bottom + 4.0));
        if (isValidCandidate) {
          resolvedBounds = candidate;
          source = NotchGeometrySource.nativePath;
        }
      }

      // 2. Fall back to standard DisplayCutout boundingRects (API 28+)
      if (resolvedBounds == null && boundRect != null) {
        resolvedBounds = boundRect;
        source = NotchGeometrySource.displayFeature;
      }

      if (resolvedBounds == null) {
        return null;
      }

      final shape = NotchGeometryDetector._classifyShape(resolvedBounds, edge);

      _cached = NotchGeometry(
        bounds: resolvedBounds,
        center: resolvedBounds.center,
        width: resolvedBounds.width,
        height: resolvedBounds.height,
        top: resolvedBounds.top,
        bottom: resolvedBounds.bottom,
        screenSize: mediaQuery.size,
        insets: insets,
        source: source,
        confidence: NotchGeometryConfidence.exact,
        shape: shape,
        hasCutout: true,
        edge: edge,
        devicePixelRatio: dpr,
      );
      return _cached;
    } catch (_) {
      return null;
    }
  }

  /// Clears any cached geometry and active pending query.
  void clear() {
    _cached = null;
    _pendingLoad = null;
  }
}
