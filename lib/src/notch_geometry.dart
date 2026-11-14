import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';

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
    this.devicePixelRatio = 1.0,
  });

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

  /// The device pixel ratio at the time of measurement.
  final double devicePixelRatio;

  /// Horizontal anchor coordinate in logical pixels.
  double get anchorX => center.dx;

  /// Suggested vertical anchor coordinate where the water drop should originate.
  double get anchorTop {
    if (!hasCutout) return math.max(0.0, insets.top);
    if (source == NotchGeometrySource.profile) {
      return math.max(0.0, bottom);
    }
    return math.max(0.0, bottom - 1.0);
  }

  /// Empty geometry constant for displays with no insets or cutouts.
  static const NotchGeometry empty = NotchGeometry(
    bounds: null,
    center: Offset.zero,
    width: 0.0,
    height: 0.0,
    top: 0.0,
    bottom: 0.0,
    screenSize: Size.zero,
    insets: EdgeInsets.zero,
    source: NotchGeometrySource.none,
    confidence: NotchGeometryConfidence.none,
    shape: NotchShape.none,
    hasCutout: false,
    devicePixelRatio: 1.0,
  );

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
        devicePixelRatio,
      );

  @override
  String toString() =>
      'NotchGeometry(shape: $shape, source: $source, confidence: $confidence, '
      'bounds: $bounds, bottom: $bottom, hasCutout: $hasCutout)';
}

/// Detects and classifies notch and camera cutout geometry from [BuildContext]
/// or [MediaQueryData].
class NotchGeometryDetector {
  const NotchGeometryDetector._();

  /// Detects notch geometry from the provided [BuildContext].
  static NotchGeometry detect(BuildContext context) {
    return fromMediaQuery(
      mediaQuery: MediaQuery.of(context),
      platform: Theme.of(context).platform,
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
    final candidates = <Rect>[];
    for (final feature in mediaQuery.displayFeatures) {
      if (feature.type != DisplayFeatureType.cutout) continue;
      final bounds = feature.bounds;
      if (bounds.isEmpty || !bounds.isFinite) continue;

      // Filter cutouts outside the horizontal active viewport bounds
      if (bounds.right <= padding.left ||
          bounds.left >= size.width - padding.right) {
        continue;
      }

      // In landscape orientation, cutouts located on the left or right edges
      // (side cutouts) must not be treated as top drop anchors.
      if (orientation == Orientation.landscape) {
        final sideMarginLeft = math.max(padding.left, 24.0);
        final sideMarginRight = math.max(padding.right, 24.0);
        final isLeftSide = bounds.left <= sideMarginLeft &&
            bounds.width < size.width * 0.5;
        final isRightSide = bounds.right >= size.width - sideMarginRight &&
            bounds.width < size.width * 0.5;
        if (isLeftSide || isRightSide) {
          continue;
        }
      }

      // Check whether cutout is located in the top region of the display.
      // Top cutouts must start near the top boundary (at or above safe padding
      // or within the top 32dp), and bottom must not exceed reasonable notch depth.
      final topLimit = math.max(padding.top, 32.0);
      final bottomLimit = math.max(padding.top + 24.0, 68.0);
      if (bounds.top <= topLimit && bounds.bottom <= bottomLimit) {
        candidates.add(bounds);
      }
    }

    if (candidates.isNotEmpty) {
      // Find candidate closest to viewport center
      candidates.sort((a, b) => (a.center.dx - viewportCenter)
          .abs()
          .compareTo((b.center.dx - viewportCenter).abs()));

      Rect resolved = candidates.first;
      if (candidates.length > 1) {
        final second = candidates[1];
        // If two cutouts are adjacent (e.g. dual punch holes separated by a small gap),
        // combine their bounding boxes into a single cluster.
        final gapX = (resolved.center.dx - second.center.dx).abs() -
            (resolved.width + second.width) / 2;
        if (gapX <= 16.0 && (resolved.top - second.top).abs() <= 12.0) {
          resolved = resolved.expandToInclude(second);
        }
      }

      final shape = _classifyShape(resolved);
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

  static NotchShape _classifyShape(Rect bounds) {
    // Cutouts attached to or touching the upper display edge are notches
    // (including wide notches and centered teardrop / waterdrop notches).
    if (bounds.top <= 2.0) {
      return NotchShape.notch;
    }
    final aspect = bounds.width / math.max(1.0, bounds.height);
    if (aspect > 1.35) {
      return NotchShape.pill;
    }
    return NotchShape.punchHole;
  }
}
