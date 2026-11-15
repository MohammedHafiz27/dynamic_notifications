# Dynamic Notifications

Fluid, cutout-aware in-app notifications for Flutter on iOS and Android. Notifications emerge directly from your device's physical camera aperture or Dynamic Island via curve-driven fluid morphing, blossom into rounded notification cards, and retract back into the aperture upon dismissal.

[![pub package](https://img.shields.io/pub/v/dynamic_notifications.svg)](https://pub.dev/packages/dynamic_notifications)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.47.2-02569B.svg?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.13.2-0175C2.svg?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-API%2021%2B-3DDC84.svg?logo=android)](https://developer.android.com)
[![iOS](https://img.shields.io/badge/iOS-15.0%2B-000000.svg?logo=apple)](https://developer.apple.com/ios)
<!-- TODO(verify): confirm minimum supported iOS version in Runner deployment target; package has no native iOS dependencies, example runner targets iOS 15.0 -->

---

## Visual Demonstration

The notification emerges directly from the device's physical camera cutout or Dynamic Island, expands downward with a curve-driven fluid silhouette, presents the notification content, and reverses back into the aperture upon dismissal or interactive swipe.

<p align="center">
  <img src="https://raw.githubusercontent.com/MohammedHafiz27/dynamic_notifications/main/docs/assets/ios-demo.gif" width="340" alt="iOS Dynamic Island Notification Demo">
  <!-- TODO(verify): URL will return 200 once feature branch is merged into main and pushed to remote -->
  <!-- TODO(verify): add an Android punch-hole demo GIF -->
  <br>
  <em>Captured on iPhone 16 Pro Max simulator running the example application (iOS demonstrated).</em>
</p>

---

## Why Dynamic Notifications?

| Feature | `dynamic_notifications` | `flutter_local_notifications` | `overlay_support` | `toastification` |
| :--- | :--- | :--- | :--- | :--- |
| **Cutout Awareness** | Yes (Android `DisplayCutout` + iOS Dynamic Island / Notch) | No (OS system tray only) | No (fixed insets) | No (fixed toast positioning) |
| **Emergence Animation** | Curve-driven fluid morph from camera aperture | Standard OS tray banner | Slide / Fade overlay | Slide / Bounce / Fade |
| **Interactive Reverse Morph** | Yes (scrubs morph progress in reverse on drag) | No | No | No |
| **Gesture Support** | Tap, swipe up (dismiss), swipe down (open), hold (pause) | Tap only (notification payload) | Swipe to dismiss | Tap, swipe to dismiss |
| **Presentation Layer** | In-app Flutter overlay above navigator | System notification tray / lock screen | In-app overlay | In-app toast overlay |
| **Native Platform Channel** | Android API 28+ / 31+ cutout query | Full Android / iOS notification services | None (pure Flutter) | None (pure Flutter) |

---

## Features

- **Curve-Driven Fluid Morph** — Natural droplet formation emerging directly from the camera cutout or Dynamic Island via staged `Interval` curves (`_fall`, `_expand`, `_reveal`, `_tint`) before settling into the notification card.
- **Hardware-Aware Geometry Detection** —
  - **Android Platform Channel**: Queries Android's `DisplayCutout` (`boundingRectTop`, API 28+) and native `cutoutPath` (API 31+) via `AndroidCutoutGeometryProvider` to locate physical camera aperture bounds.
  - **Cross-Platform Fallback**: Calibrated heuristics using `MediaQuery.viewPadding`, `padding`, and `DisplayFeature` cutout bounds for multi-device support.
- **Interactive Gestures** —
  - **Tap to Open**: Executes the `onTap` callback and dismisses the card.
  - **Swipe Down to Open**: Dragging downward past the open threshold (`44.0` pt) or flinging downward (`>= 320.0` pt/s) triggers `onTap`.
  - **Interactive Swipe Dismissal**: Dragging upward past the dismiss threshold (`-32.0` pt) or flinging upward (`<= -320.0` pt/s) scrubs the morph progress in reverse back into the cutout.
  - **Press-and-Hold**: Touching and holding pauses the auto-dismiss timer while the user reads or interacts.
  - **Cubic Spring Return**: Releasing a drag without crossing dismissal or open thresholds smoothly returns the card to its resting position (`Curves.easeOutCubic`, 260 ms).
- **Customizable Card Content** — Built-in standard notification cards (title, message, icon, avatar, accent color) or arbitrary Flutter widget hierarchies via `contentBuilder`.
- **Accessibility & Reduced Motion** — Automatically detects `MediaQuery.disableAnimationsOf(context)`: snaps directly between states (progress 0.0 and 1.0) without animation delay, while providing screen-reader announcements via `Semantics`.

---

## Installation

Add `dynamic_notifications` to your `pubspec.yaml`:

```sh
flutter pub add dynamic_notifications
```

Or reference a local checkout during development:

```yaml
dependencies:
  dynamic_notifications:
    path: ../dynamic_notifications
```

---

## Platform Setup

### Android Setup

To allow the notification to emerge directly from the camera cutout, the Android host window must be configured to extend into the display cutout area.

1. In `android/app/src/main/res/values/styles.xml`, ensure your `NormalTheme` includes `windowLayoutInDisplayCutoutMode`:

```xml
<style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
    <item name="android:windowBackground">?android:colorBackground</item>
    <item name="android:windowLayoutInDisplayCutoutMode">shortEdges</item>
</style>
```

*(On Android 11+ / API 30+, `always` can also be used).*

2. In your Flutter `main()` entrypoint, enable edge-to-edge system UI display:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}
```

### iOS Setup

No native configuration or Podfile changes are required for iOS. Geometry detection on iOS is handled within Flutter through `MediaQuery.viewPadding` safe-area insets and `DisplayFeature` metrics.

---

## Quick Start

1. Create a `DynamicNotificationController` instance.
2. Install the `DynamicNotifications` host once in `MaterialApp.builder` (outside the navigator).
3. Call `controller.show()` to present notifications from anywhere in your app.

```dart
import 'package:dynamic_notifications/dynamic_notifications.dart';
import 'package:flutter/material.dart';

final notifications = DynamicNotificationController();

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => DynamicNotifications(
        controller: notifications,
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => notifications.show(
              const DynamicNotification(
                title: 'Download complete',
                message: 'Your file is ready to view.',
                icon: Icons.download_done,
              ),
            ),
            child: const Text('Show Notification'),
          ),
        ),
      ),
    );
  }
}
```

---

## Configuration & API Reference

### `DynamicNotifications` (Host Widget)

The host widget listens to the controller and paints the fluid morph notification overlay above your application subtree.

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `controller` | `DynamicNotificationController` | *Required* | Controller coordinating notification display and dismissals. |
| `child` | `Widget` | *Required* | The underlying widget subtree (typically your navigator from `MaterialApp.builder`). |
| `originLift` | `double` | `0.0` | Moves the automatic drop origin up by this many logical pixels (must be `>= 0`). |
| `renderMode` | `NotificationRenderMode` | `NotificationRenderMode.standard` | Rendering engine used to draw the notification silhouette and animation. |
| `gestureConfig` | `NotificationGestureConfig` | `const NotificationGestureConfig()` | Thresholds and curves for interactive drag, fling, tap, and spring return. |
| `debugShowGuides` | `bool` | `false` | Renders visual guides showing detected cutout bounds, anchor origin, and neck boundaries. |
| `geometryOverride` | `NotchGeometry?` | `null` | Manually overrides detected notch geometry (useful for testing or simulator verification). |
| `progressOverride` | `double?` | `null` | Freezes animation progress between `0.0` (cutout) and `1.0` (card) for inspection. |

---

### `DynamicNotificationController`

Coordinates presenting and dismissing notifications on a mounted host:

| Member | Type | Description |
| :--- | :--- | :--- |
| `show(DynamicNotification notification)` | `void` | Shows a notification. If another card is active, replaces any pending notification ("latest wins"). |
| `dismiss()` | `void` | Clears any pending notification and initiates reverse exit of the active card. |
| `interactionState` | `NotificationInteractionState` | Current interaction state of the active notification (idle, dragging, holding, dismissing, opening, returning). |
| `dragOffset` | `double` | Current vertical drag displacement in logical pixels (`0.0` when idle). |
| `morphProgress` | `double` | Current reverse morph progress into the cutout, normalized from `0.0` (resting card) to `1.0` (collapsed). |
| `currentNotification` | `DynamicNotification?` | The currently presented notification, or `null` if idle. |

---

### `NotificationGestureConfig`

Customizes gesture thresholds, fling velocities, limits, and spring return curves:

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `dismissThreshold` | `double` | `-32.0` | Upward drag distance in logical pixels required to trigger dismissal on release (negative value). |
| `dismissVelocityThreshold` | `double` | `-320.0` | Upward fling velocity in logical pixels per second required to trigger dismissal (negative value). |
| `openThreshold` | `double` | `44.0` | Downward drag distance in logical pixels required to trigger the open action on release (positive value). |
| `openVelocityThreshold` | `double` | `320.0` | Downward fling velocity in logical pixels per second required to trigger open (positive value). |
| `maxUpwardDrag` | `double` | `-80.0` | Maximum upward drag displacement in logical pixels (negative value). |
| `maxDownwardDrag` | `double` | `120.0` | Maximum downward drag displacement in logical pixels (positive value). |
| `maxTapDuration` | `Duration` | `Duration(milliseconds: 350)` | Maximum touch duration to be recognized as a tap rather than a hold. |
| `springBackDuration` | `Duration` | `Duration(milliseconds: 260)` | Duration of the return animation when returning to resting position after sub-threshold drag. |
| `springBackCurve` | `Curve` | `Curves.easeOutCubic` | Animation curve used for the return animation. |

---

### `NotificationInteractionState`

Enum representing the user interaction lifecycle of the active notification:

- `NotificationInteractionState.idle` — Notification is resting at its settled position with no active touch.
- `NotificationInteractionState.dragging` — User is actively touching and dragging the notification vertically.
- `NotificationInteractionState.holding` — User is touching and holding the notification in place without moving.
- `NotificationInteractionState.dismissing` — Notification was released beyond the dismissal threshold or flung upward and is exiting.
- `NotificationInteractionState.opening` — Notification was tapped or swiped down beyond the open threshold; `onTap` callback is triggered.
- `NotificationInteractionState.returning` — Notification was released below threshold and is smoothly returning to resting position.

---

### `NotificationRenderMode`

- `NotificationRenderMode.standard` — Verified fluid morphology renderer (standard drop emergence and card transformation).

---

### `DynamicNotification` (Data Model)

Defines notification content, duration, and behavior:

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `title` | `String` | *Required* | Card title and primary accessibility announcement. |
| `message` | `String?` | `null` | Secondary text displayed below the title. |
| `icon` | `IconData?` | `null` | Leading icon in the built-in card. |
| `avatar` | `ImageProvider?` | `null` | Circular avatar image (takes priority over `icon`). |
| `accent` | `Color?` | `null` | Accent color applied to the leading icon. |
| `duration` | `Duration?` | `Duration(seconds: 2)` | Display time before auto-dismissal (`null` for persistent card). |
| `onTap` | `VoidCallback?` | `null` | Callback executed when tapped or swiped downward past `openThreshold`. Tap automatically dismisses the card. |
| `contentBuilder` | `WidgetBuilder?` | `null` | Custom widget layout replacing the built-in card row. |
| `style` | `DynamicNotificationStyle` | `const DynamicNotificationStyle()` | Appearance overrides (background color, border radius, padding). |

---

### `DynamicNotificationStyle`

Appearance overrides for the notification card:

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `backgroundColor` | `Color?` | `null` | Card background color. When `null`, defaults to theme card color (light `Colors.white`, dark `Color(0xFF28272A)`). |
| `borderRadius` | `double?` | `null` | Uniform corner radius in logical pixels (asserts `>= 0`). When `null`, defaults to pill shape (`36.0`). |
| `padding` | `EdgeInsetsGeometry` | `EdgeInsets.symmetric(horizontal: 16, vertical: 14)` | Insets around built-in row or custom content builder. |

---

### Custom Card Example

Supply a `contentBuilder` to display custom layouts such as upload progress bars or media controls:

```dart
notifications.show(
  DynamicNotification(
    title: 'Uploading files',
    message: '60% complete',
    duration: null, // Persistent until dismissed
    style: const DynamicNotificationStyle(
      backgroundColor: Color(0xFF242426),
      borderRadius: 22,
    ),
    contentBuilder: (context) => const Row(
      children: [
        Icon(Icons.cloud_upload_outlined, color: Color(0xFFFF636A)),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Uploading files',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: 0.6,
                color: Color(0xFFFF636A),
                backgroundColor: Color(0xFF505054),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        Text('60%', style: TextStyle(color: Colors.white)),
      ],
    ),
  ),
);
```

---

## Notch Geometry & Public API Exports

All geometric models and detector classes are exported by `package:dynamic_notifications/dynamic_notifications.dart`:

### `NotchGeometry`

Immutable representation of the device cutout geometry:

- **Getters**:
  - `bounds` (`Rect?`): Bounding rectangle of the cutout in logical pixels, if available.
  - `center` (`Offset`): Anchor center point of the cutout or fallback safe-area.
  - `width` (`double`): Cutout width in logical pixels (`0.0` if no cutout).
  - `height` (`double`): Cutout height in logical pixels (`0.0` if no cutout).
  - `top` / `bottom` (`double`): Top and bottom edges of the cutout in logical pixels.
  - `screenSize` (`Size`): Dimensions of the active window or screen.
  - `insets` (`EdgeInsets`): System view padding or window insets.
  - `source` (`NotchGeometrySource`): Origin source (`displayFeature`, `profile`, `safeArea`, `nativePath`, `none`).
  - `confidence` (`NotchGeometryConfidence`): Detection confidence (`exact`, `calibrated`, `fallback`, `none`).
  - `shape` (`NotchShape`): Cutout classification (`punchHole`, `pill`, `notch`, `none`).
  - `hasCutout` (`bool`): Whether a physical cutout, notch, or island was detected.
  - `edge` (`CutoutEdge`): Cutout edge placement (`top`, `left`, `right`, `bottom`, `none`).
  - `devicePixelRatio` (`double`): Active device pixel ratio.
  - `anchorX` (`double`): Horizontal anchor coordinate in logical pixels (`center.dx`).
  - `anchorTop` (`double`): Suggested vertical anchor coordinate where the fluid drop originates.
  - `hasTopCutout` (`bool`): `true` when a physical cutout is located along the top display edge.
  - `animationOrigin` (`Offset`): 2D origin point where fluid emergence begins.
  - `animationDirection` (`Offset`): Emergence direction vector (always `(0.0, 1.0)` vertically downward).
  - `anchorPoint` (`Offset`): Exact 2D anchor point on the display.
  - `emergenceDirection` (`Offset`): Direction vector along which the droplet emerges into the display.
- **Constants**:
  - `NotchGeometry.empty`: Represents displays with no cutouts or insets.

### `NotchGeometryDetector`

Utility class for detecting cutout geometry from Flutter metrics:

- `NotchGeometryDetector.detect(BuildContext context)`: Resolves notch geometry from current context, incorporating cached native Android geometry when available.
- `NotchGeometryDetector.fromMediaQuery({required MediaQueryData mediaQuery, required TargetPlatform platform})`: Resolves geometry directly from provided media query and target platform.

### `AndroidCutoutGeometryProvider`

Singleton platform channel client communicating with Android's native cutout APIs:

- `AndroidCutoutGeometryProvider.instance`: Shared singleton instance.
- `channel`: The underlying `MethodChannel('dynamic_notifications/android_geometry')`.
- `cached`: The currently cached `NotchGeometry?`, or `null`.
- `load({required MediaQueryData mediaQuery, bool forceRefresh = false})`: Asynchronously queries Android `DisplayCutout`, caches the result, and returns the resolved `NotchGeometry?`.
- `clear()`: Clears any cached geometry and active pending queries.

---

## Behavior Notes & Limitations

1. **Devices Without Cutouts**: On square-corner displays or devices without physical cutouts, `dynamic_notifications` gracefully falls back to the top safe area status bar insets with a centered top origin.
2. **Single Pending Notification ("Latest Wins")**: The host maintains a single pending slot rather than an unbounded FIFO queue. If `controller.show()` is called while a notification is currently active or exiting, the new notification replaces any previous pending notification and enters as soon as the active exit concludes.
3. **Controller Attachment Rule**: A single `DynamicNotificationController` can only be attached to one mounted `DynamicNotifications` host at a time. Attaching it to a second host will throw a `StateError` (*"A controller can only be attached to one host."*).
4. **Mount Placement**: Always place `DynamicNotifications` in `MaterialApp.builder` outside the `Navigator`. This ensures notifications overlay all routes, modal bottom sheets, and dialogs without resetting during page transitions.
5. **Asynchronous Android Geometry**: On Android, `AndroidCutoutGeometryProvider.instance.load()` is invoked asynchronously upon initial mount. The first frame may use `MediaQuery` fallback metrics until the native platform channel completes, whereupon the host updates with exact native cutout bounds.

---

## Debugging & Testing

### Visual Debugging

Enable visual guides to display cutout bounds and anchor crosshairs, or freeze animation progress for frame inspection:

```dart
DynamicNotifications(
  controller: notifications,
  debugShowGuides: true,       // Shows green/red cutout bounding boxes and anchor crosshairs
  progressOverride: 0.45,      // Freezes animation at 45% progress (0.0 to 1.0)
  geometryOverride: const NotchGeometry(
    bounds: Rect.fromLTWH(180, 0, 34, 34),
    center: Offset(197, 17),
    width: 34,
    height: 34,
    top: 0,
    bottom: 34,
    screenSize: Size(393, 852),
    insets: EdgeInsets.only(top: 47),
    source: NotchGeometrySource.safeArea,
    confidence: NotchGeometryConfidence.fallback,
    shape: NotchShape.punchHole,
    hasCutout: true,
  ),
  child: child!,
)
```

### Testing Hooks

The package exposes test verification hooks decorated with `@visibleForTesting`:

- `DynamicNotifications.sideCutoutRendererEntered` (`bool`): In regression tests, verifies that orientation-independent vertical liquid morph is used instead of horizontal side renderers.
- `DynamicNotifications.resetSideCutoutRendererFlag()` (`void`): Resets the side-cutout renderer test verification flag.

---

## Architecture Overview

```
┌─────────────────────────────────┐
│ DynamicNotificationController   │  (show, dismiss, interactionState, dragOffset)
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│ DynamicNotifications (Host)     │  (Pointer events, Stack, Semantics, Overlay)
└────────────────┬────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌───────────────┐ ┌──────────────────────────────────┐
│ NotchGeometry │ │ Curve-Driven Fluid Morph         │
│ Detection     │ │ Entrance: Interval Curves        │
│ (Native / MQ) │ │ Return: Cubic Ease-Out (260 ms)  │
└───────────────┘ └──────────────────────────────────┘
```

1. **Geometry Stage**: The host queries `AndroidCutoutGeometryProvider` on Android (API 28+ / 31+) or `NotchGeometryDetector` across platforms to resolve physical aperture bounds, horizontal anchor `anchorX`, and drop origin `anchorTop`.
2. **Droplet Emergence**: An elongated teardrop path emerges from the cutout anchor and extends downward using staged `Interval` curves (`_fall`, `_expand`, `_reveal`, `_tint`).
3. **Card Morph**: The droplet expands outward and morphs into the settled notification card.
4. **Interactive Gestures & Dismissal**:
   - Upward drag scrubs the morph progress in reverse. Releasing past `-32.0` pt (or flinging `<= -320.0` pt/s) exits into the cutout.
   - Downward drag past `44.0` pt (or flinging `>= 320.0` pt/s) triggers `onTap` and opens.
   - Sub-threshold release triggers a cubic spring return back to resting position.
   - Touching and holding pauses the auto-dismiss timer.

---

## Running the Example

The example project contains an interactive YouTube-style application demonstrating notifications, gesture interactions, and geometry diagnostics:

```sh
cd example
flutter run
```

---

## Community & Contributing

- **Issues & Bug Reports**: [GitHub Issues](https://github.com/MohammedHafiz27/dynamic_notifications/issues)
- **Source Repository**: [MohammedHafiz27/dynamic_notifications](https://github.com/MohammedHafiz27/dynamic_notifications)
- **Release History**: [CHANGELOG.md](CHANGELOG.md)

---

## License & Attribution

- Released under the [MIT License](LICENSE).
- Created and maintained by **Mohammed Hafiz**.
- Motion concept inspired by [expo-dynamic-notifications](https://github.com/rit3zh/expo-dynamic-notifications).
