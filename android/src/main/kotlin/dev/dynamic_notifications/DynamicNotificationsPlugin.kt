package dev.dynamic_notifications

import android.app.Activity
import android.graphics.RectF
import android.os.Build
import android.view.DisplayCutout
import android.view.View
import android.view.WindowInsets
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Flutter plugin providing cached and real-time Android DisplayCutout geometry
 * (including DisplayCutout.getCutoutPath on Android 12+ / API 31+).
 */
class DynamicNotificationsPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var cachedGeometry: Map<String, Any?>? = null

    companion object {
        const val CHANNEL_NAME = "dynamic_notifications/android_geometry"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        attachInsetsListener()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        cachedGeometry = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        attachInsetsListener()
    }

    override fun onDetachedFromActivity() {
        activity = null
        cachedGeometry = null
    }

    private fun attachInsetsListener() {
        val window = activity?.window ?: return
        window.decorView.setOnApplyWindowInsetsListener { view: View, insets: WindowInsets ->
            cacheGeometryFromInsets(insets)
            view.onApplyWindowInsets(insets)
        }
        val currentInsets = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            window.decorView.rootWindowInsets
        } else {
            null
        }
        if (currentInsets != null) {
            cacheGeometryFromInsets(currentInsets)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getCutoutGeometry" -> {
                val startNs = System.nanoTime()
                val geometry = cachedGeometry ?: run {
                    val insets = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        activity?.window?.decorView?.rootWindowInsets
                    } else {
                        null
                    }
                    if (insets != null) {
                        cacheGeometryFromInsets(insets)
                    } else {
                        buildFallbackGeometry()
                    }
                }
                val elapsedUs = (System.nanoTime() - startNs) / 1000
                val response = HashMap(geometry)
                response["latencyUs"] = elapsedUs
                response["cached"] = cachedGeometry != null
                result.success(response)
            }
            else -> result.notImplemented()
        }
    }

    private fun cacheGeometryFromInsets(insets: WindowInsets): Map<String, Any?> {
        val data = mutableMapOf<String, Any?>()
        data["deviceModel"] = Build.MODEL ?: "Unknown"
        data["apiLevel"] = Build.VERSION.SDK_INT
        data["targetSdk"] = activity?.applicationInfo?.targetSdkVersion ?: 0

        val cutout: DisplayCutout? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            insets.displayCutout
        } else {
            null
        }

        if (cutout == null) {
            data["hasCutout"] = false
            data["hasPath"] = false
            data["edge"] = "none"
            cachedGeometry = data
            return data
        }

        data["hasCutout"] = true

        // API 31+ cutoutPath support
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val path = cutout.cutoutPath
            if (path != null) {
                val rectF = RectF()
                @Suppress("DEPRECATION")
                path.computeBounds(rectF, true)
                data["hasPath"] = true
                data["pathLeft"] = rectF.left.toDouble()
                data["pathTop"] = rectF.top.toDouble()
                data["pathRight"] = rectF.right.toDouble()
                data["pathBottom"] = rectF.bottom.toDouble()
                data["pathWidth"] = rectF.width().toDouble()
                data["pathHeight"] = rectF.height().toDouble()
            } else {
                data["hasPath"] = false
            }
        } else {
            data["hasPath"] = false
        }

        // DisplayCutout edge classification and bounding rect resolution (API 28+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            var selectedRect: android.graphics.Rect? = null
            var selectedEdge = "none"

            // API 29+ (Android Q) exposes per-edge bounding rects
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val topRect = cutout.boundingRectTop
                val leftRect = cutout.boundingRectLeft
                val rightRect = cutout.boundingRectRight
                val bottomRect = cutout.boundingRectBottom

                if (!topRect.isEmpty) {
                    selectedEdge = "top"
                    selectedRect = topRect
                } else if (!leftRect.isEmpty) {
                    selectedEdge = "left"
                    selectedRect = leftRect
                } else if (!rightRect.isEmpty) {
                    selectedEdge = "right"
                    selectedRect = rightRect
                } else if (!bottomRect.isEmpty) {
                    selectedEdge = "bottom"
                    selectedRect = bottomRect
                }
            }

            // Fallback for API 28 or when per-edge rects were not populated
            if (selectedRect == null) {
                val rects = cutout.boundingRects
                if (rects.isNotEmpty()) {
                    val decorView = activity?.window?.decorView
                    val screenWidth = decorView?.width ?: 0
                    val screenHeight = decorView?.height ?: 0

                    // Top cutout takes priority
                    val topCandidate = rects.firstOrNull { it.top <= 2 || (it.top <= 48 && it.bottom <= 120) }
                    if (topCandidate != null) {
                        selectedEdge = "top"
                        selectedRect = topCandidate
                    } else {
                        val leftCandidate = rects.firstOrNull { it.left <= 2 || (screenWidth > 0 && it.left < screenWidth * 0.2) }
                        if (leftCandidate != null) {
                            selectedEdge = "left"
                            selectedRect = leftCandidate
                        } else {
                            val rightCandidate = rects.firstOrNull { (screenWidth > 0 && it.right >= screenWidth - 2) || (screenWidth > 0 && it.right > screenWidth * 0.8) }
                            if (rightCandidate != null) {
                                selectedEdge = "right"
                                selectedRect = rightCandidate
                            } else {
                                val bottomCandidate = rects.firstOrNull { (screenHeight > 0 && it.bottom >= screenHeight - 2) }
                                if (bottomCandidate != null) {
                                    selectedEdge = "bottom"
                                    selectedRect = bottomCandidate
                                } else {
                                    selectedEdge = "top"
                                    selectedRect = rects.first()
                                }
                            }
                        }
                    }
                }
            }

            data["edge"] = selectedEdge
            if (selectedRect != null && !selectedRect.isEmpty) {
                data["boundLeft"] = selectedRect.left.toDouble()
                data["boundTop"] = selectedRect.top.toDouble()
                data["boundRight"] = selectedRect.right.toDouble()
                data["boundBottom"] = selectedRect.bottom.toDouble()
                data["boundWidth"] = selectedRect.width().toDouble()
                data["boundHeight"] = selectedRect.height().toDouble()

                // If cutoutPath encompasses multiple cutouts across screens, invalidate hasPath
                if (data["hasPath"] == true) {
                    val pLeft = data["pathLeft"] as? Double ?: 0.0
                    val pTop = data["pathTop"] as? Double ?: 0.0
                    val pRight = data["pathRight"] as? Double ?: 0.0
                    val pBottom = data["pathBottom"] as? Double ?: 0.0

                    val boundsMatch = (pLeft >= selectedRect.left - 4) &&
                            (pTop >= selectedRect.top - 4) &&
                            (pRight <= selectedRect.right + 4) &&
                            (pBottom <= selectedRect.bottom + 4)
                    if (!boundsMatch) {
                        data["hasPath"] = false
                        data.remove("pathLeft")
                        data.remove("pathTop")
                        data.remove("pathRight")
                        data.remove("pathBottom")
                        data.remove("pathWidth")
                        data.remove("pathHeight")
                    }
                }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val waterfall = cutout.waterfallInsets
                data["waterfallTop"] = waterfall.top
                data["waterfallBottom"] = waterfall.bottom
                data["waterfallLeft"] = waterfall.left
                data["waterfallRight"] = waterfall.right
            }
            data["safeInsetTop"] = cutout.safeInsetTop
            data["safeInsetBottom"] = cutout.safeInsetBottom
            data["safeInsetLeft"] = cutout.safeInsetLeft
            data["safeInsetRight"] = cutout.safeInsetRight

            val window = activity?.window
            if (window != null) {
                val params = window.attributes
                val mode = params.layoutInDisplayCutoutMode
                data["layoutInDisplayCutoutMode"] = mode
                val extends = (mode == android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES) ||
                        (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && mode == android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS)
                data["windowExtendsIntoCutout"] = extends
            }
        }

        cachedGeometry = data
        return data
    }

    private fun buildFallbackGeometry(): Map<String, Any?> {
        val data = mutableMapOf<String, Any?>()
        data["deviceModel"] = Build.MODEL ?: "Unknown"
        data["apiLevel"] = Build.VERSION.SDK_INT
        data["targetSdk"] = activity?.applicationInfo?.targetSdkVersion ?: 0
        data["hasCutout"] = false
        data["hasPath"] = false
        data["edge"] = "none"
        return data
    }
}
