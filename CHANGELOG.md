## 0.1.0

- Initial release of `local_dynamic_notifications`, an in-app notification overlay emerging organically from display cutouts and safe areas.
- Public API surface:
  - `DynamicNotifications`: Root overlay widget coordinating fluid notification morphing with `originLift`, `geometryOverride`, and `gestureConfig`.
  - `DynamicNotificationController`: Programmatic controller for displaying, queueing, and dismissing notifications, with observable `interactionState` and `stateNotifier`.
  - `DynamicNotification`: Content model supporting title, message, leading/trailing widgets, duration overrides, `onOpen` callback, and custom layout via `contentBuilder`.
  - `DynamicNotificationStyle`: Visual styling including surface colors, corner radius, padding, elevation, and shadows.
  - `NotificationGestureConfig`: Interactive physics configuration for vertical drag scrubbing, fling dismissal, and return spring curves.
  - `NotchGeometry` & `NotchGeometryDetector`: Automatic hardware cutout detection across iOS Dynamic Island, top notches, and Android punch holes.
  - `AndroidCutoutGeometryProvider`: Native platform channel integration retrieving exact Android `DisplayCutout` coordinates.
- Streamlined rendering engine utilizing a unified physics-based pendant drop morphology across all device orientations.
- Safe-area fallback for notch-free devices and tablets.
