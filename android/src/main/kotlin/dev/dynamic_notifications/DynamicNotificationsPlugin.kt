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

        // Standard DisplayCutout bounding rects (API 28+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val rects = cutout.boundingRects
            if (rects.isNotEmpty()) {
                val topRect = rects.firstOrNull { it.top == 0 } ?: rects.first()
                data["boundLeft"] = topRect.left.toDouble()
                data["boundTop"] = topRect.top.toDouble()
                data["boundRight"] = topRect.right.toDouble()
                data["boundBottom"] = topRect.bottom.toDouble()
                data["boundWidth"] = topRect.width().toDouble()
                data["boundHeight"] = topRect.height().toDouble()
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
        return data
    }
}
