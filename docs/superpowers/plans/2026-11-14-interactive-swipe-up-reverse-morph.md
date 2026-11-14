# Interactive Swipe-Up Reverse Morph Into Native Notch / Dynamic Island

> **Implementation Plan**  
> **Date:** 2026-11-14  
> **Branch:** `feature/fix-drag-card-background`  
> **Renderer:** `NotificationRenderMode.standard` (only renderer)  
> **Source of Truth:** `NotchGeometry` & Native Android Geometry Provider

---

## 1. Goal & Architecture Overview

Upgrade the upward swipe interaction in `dynamic_notifications` from a standard dismiss animation into a real-time, interactive, reversible **shape morph** that pulls the notification card back into the device's camera cutout / Dynamic Island.

### Key Visual & Physical Mechanics:
1. **Interactive Finger Tracking:** As the user drags upward ($\Delta y < 0$), normalized progress $u = (-\text{effectiveDrag} / D_{\max}) \in [0.0, 1.0]$ directly drives every geometric property without delay or jitter.
2. **Organic Shape Morphing:**
   - Width contracts from full card width ($396\text{dp}$ max) toward the cutout width ($20\text{--}36\text{dp}$) via cubic easing.
   - Height shrinks from settled card height toward cutout height ($16\text{--}24\text{dp}$).
   - Corner radius morphs from card radius into a smooth pill/circle radius ($H / 2$).
   - Center coordinates $(C_x, C_y)$ glide from the card center toward the hardware notch anchor $(targetCenterX, targetCenterY)$.
   - Bottom edge pulls upward continuously toward the cutout apex ($yApex$).
3. **Retracting Fluid Bridge & Meniscus:** At $u \ge 0.35$, a concave liquid suction neck emerges connecting the contracting pill to the cutout rim, pinches at the waist, and retracts cleanly into the notch aperture.
4. **Smooth Content Dissolve:** Notification title, subtitle, avatar, and icon fade out progressively ($u \in [0.0, 0.42]$) and scale down gracefully, preventing text detachment or overflow.
5. **Real-time Reversibility:** If the user drags downward before release, $u$ immediately decreases, smoothly restoring card geometry, dimensions, and content without state resets or animation restarts.
6. **Velocity-Aware Physics on Release:**
   - If released beyond dismissal threshold ($u \ge 0.40$) or flicked upward ($v_y \le -320\text{dp/s}$): spring smoothly from current $u$ to $1.0$ (complete collapse), then trigger dismissal callback.
   - If released below threshold with low/downward velocity: spring smoothly back to $u = 0.0$ (`Curves.easeOutCubic`), restoring settled card and resuming auto-dismiss timer.

---

## 2. File Structure & Responsibilities

| File | Changes |
|---|---|
| `lib/dynamic_notifications.dart` | • Expose `morphProgress` on `DynamicNotificationController`.<br>• Calculate normalized `morphProgress` ($u$) in `_DynamicNotificationsState`.<br>• Update `_springController` listener and forward completion logic for collapse-to-notch.<br>• Pass `morphProgress` into `_NotificationPainter` and content builder.<br>• Implement shape morph (width, height, center, corner radius, liquid suction bridge, gradient, shadow) in `_NotificationPainter.paint`.<br>• Fade and scale content gracefully based on `morphProgress`. |
| `test/dynamic_notifications_test.dart` | • Add 18 comprehensive regression and interaction tests covering: expanded state ($u=0$), partial drag ($u=0.25$), medium drag ($u=0.50$), near-complete collapse ($u=0.85$), complete collapse ($u=1.0$), real-time direction reversal, spring-back, fast upward flick, hold/pause, no detached text, clipping safety, preserved downward open, preserved tap-to-open, and platform notch geometry. |
| `test/reverse_morph_screenshot_test.dart` | • Reproducible frame capture test generating baseline screenshots at 0%, 25%, 50%, 75%, and 100% collapse into `doc/screenshots/morph/`. |

---

## 3. Step-by-Step Implementation Tasks

### Task 1: Controller & State Gesture Physics Pipeline
- [ ] Add `double get morphProgress` getter to `DynamicNotificationController`.
- [ ] In `_DynamicNotificationsState`:
  - Calculate `effectiveUpwardDrag`: when $\text{effectiveDrag} < 0$, derive $u = (-\text{effectiveDrag} / \text{gestureConfig.maxUpwardDrag.abs()}).clamp(0.0, 1.0)$.
  - Support programmatic or timer exit: when $\text{_exiting}$ and $\text{_drag} == 0$, $u = (1.0 - \text{_animation.value})$.
  - In `_handlePointerUp`: when release triggers dismissal, animate `_springAnimation` from current `_drag` to `gestureConfig.maxUpwardDrag` ($u = 1.0$). Upon reaching $-D_{\max}$, call `_finishExit()` to cleanly remove card and invoke semantics/dismissal.
  - In `_springBack`: animate `_drag` to $0.0$ using `gestureConfig.springBackCurve` (`Curves.easeOutCubic`), restoring idle state and timer.

### Task 2: Notification Content Graceful Fade & Scale
- [ ] In `_DynamicNotificationsState._buildNotification`:
  - Compute `contentOpacity = reveal * math.max(0.0, 1.0 - morphProgress * 2.35)`.
  - Compute `contentScale = lerpDouble(0.94, 1.0, reveal)! * lerpDouble(1.0, 0.72, morphProgress)!`.
  - Wrap content with dynamic `contentOpacity` and `contentScale`.
  - Ensure interactive touch is disabled when $u > 0.40$.

### Task 3: Geometric Reverse Morph in `_NotificationPainter`
- [ ] Add `morphProgress` parameter to `_NotificationPainter`.
- [ ] In `_NotificationPainter.paint`:
  - Compute target notch geometry:
    - `targetCenterX = size.width / 2 + anchorOffset`
    - `targetCenterY = hasCutout ? (cutoutCenterYLocal - deltaOverlap * 0.5) : (-anchorTop / 2.0)`
    - `targetWidth = hasCutout ? math.max(20.0, isPunchHole ? cutoutRadius * 2.0 : geometry!.width * 0.95) : 32.0`
    - `targetHeight = hasCutout ? math.max(16.0, cutoutRadiusY * 2.0) : 16.0`
    - `targetCorner = targetHeight / 2.0`
  - Interpolate card rectangle:
    - $W(u) = \text{lerpDouble}(\text{cardWidth}, \text{targetWidth}, \text{Curves.easeInOutCubic.transform}(u))$
    - $H(u) = \text{lerpDouble}(\text{cardHeight}, \text{targetHeight}, \text{Curves.easeInOut.transform}(u))$
    - $C_x(u) = \text{lerpDouble}(\text{centerX}, \text{targetCenterX}, \text{Curves.easeInOut.transform}(u))$
    - $C_y(u) = \text{lerpDouble}(\text{landing} + \text{cardHeight}/2 + \text{drag}, \text{targetCenterY}, \text{Curves.easeInQuad.transform}(u))$
    - $R(u) = \text{lerpDouble}(\text{corner}, \text{targetCorner}, \text{Curves.easeIn.transform}(u))$
  - Render shape path using $W(u), H(u), C_x(u), C_y(u), R(u)$.
  - When $u \ge 0.35$, synthesize the retracting liquid suction neck connecting the pill's upper contour to the cutout lower rim (`yApex`).
  - Interpolate shadow: $\text{shadowOpacity} = \text{lerpDouble}(0.24, 0.0, \text{Curves.easeIn.transform}(u))$.
  - Interpolate color/gradient from `surface` to `Colors.black` at the contact aperture.
  - Verify and maintain dynamic `clipRect` bounds.

### Task 4: Automated Regression & Interaction Test Suite
- [ ] Write 18 targeted tests in `test/dynamic_notifications_test.dart`:
  1. Initial expanded state ($u=0.0$).
  2. Small upward drag ($u=0.25$): width contracted slightly, content visible.
  3. Medium upward drag ($u=0.50$): width contracted significantly, content faded out ($0.0$ opacity).
  4. Near-complete upward morph ($u=0.85$): compact pill nearing notch anchor.
  5. Complete upward morph ($u=1.0$): fully collapsed into notch.
  6. Real-time direction reversal (drag up to $-45\text{dp}$, then down to $+20\text{dp}$): verifies exact shape and content restoration.
  7. Incomplete upward drag spring-back: release at $-15\text{dp}$ returns smoothly to resting position without dismissing.
  8. Fast upward flick: fling at $1000\text{dp/s}$ dismisses into notch.
  9. Slow upward drag crossing threshold: dismisses into notch.
  10. Pointer cancellation during morph: cleanly springs back without errors.
  11. No detached text: verifies content is clipped and faded inside card bounds at all $u$.
  12. Background remains attached during morph: verifies pixel integrity.
  13. Dismissal callback invoked exactly once on completion.
  14. Downward open behavior remains completely intact.
  15. Tap-to-open remains completely intact.
  16. Long-press / hold behavior remains completely intact.
  17. Notch geometry alignment on asymmetric / corner punch-hole.
  18. iOS safe-area fallback geometry.

### Task 5: Frame Capture Visual Evidence
- [ ] Create `test/reverse_morph_screenshot_test.dart` to capture reproducible PNG screenshots at 0%, 25%, 50%, 75%, and 100% collapse.
- [ ] Run test and store screenshots in `doc/screenshots/morph/`.

### Task 6: Final Verification
- [ ] Run `flutter test` across all suites.
- [ ] Run `flutter analyze` for package and example app.
- [ ] Run `cd example/android && ./gradlew assembleDebug` to verify native Android build.
- [ ] Verify git safety (on `feature/fix-drag-card-background`, no commits, no pushes).
