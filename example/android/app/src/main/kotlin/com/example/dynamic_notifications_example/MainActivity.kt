package com.example.dynamic_notifications_example

import android.graphics.RectF
import android.os.Build
import android.view.DisplayCutout
import android.view.View
import android.view.WindowInsets
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "dynamic_notifications/android_geometry"
    private var cachedGeometry: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Set up insets listener on root view to eagerly capture and cache cutout geometry
        window.decorView.setOnApplyWindowInsetsListener { view: View, insets: WindowInsets ->
            cacheGeometryFromInsets(insets)
            view.onApplyWindowInsets(insets)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCutoutGeometry" -> {
                    val startNs = System.nanoTime()
                    val geometry = cachedGeometry ?: run {
                        val insets = window.decorView.rootWindowInsets
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
    }

    private fun cacheGeometryFromInsets(insets: WindowInsets): Map<String, Any?> {
        val data = mutableMapOf<String, Any?>()
        data["deviceModel"] = Build.MODEL ?: "Unknown"
        data["apiLevel"] = Build.VERSION.SDK_INT
        data["targetSdk"] = applicationInfo.targetSdkVersion

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
            val safeInsets = cutout.waterfallInsets
            data["safeInsetTop"] = cutout.safeInsetTop
            data["safeInsetBottom"] = cutout.safeInsetBottom
            data["safeInsetLeft"] = cutout.safeInsetLeft
            data["safeInsetRight"] = cutout.safeInsetRight

            val params = window.attributes
            val mode = params.layoutInDisplayCutoutMode
            data["layoutInDisplayCutoutMode"] = mode
            val extends = (mode == android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES) ||
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && mode == android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS)
            data["windowExtendsIntoCutout"] = extends
        }

        cachedGeometry = data
        return data
    }

    private fun buildFallbackGeometry(): Map<String, Any?> {
        val data = mutableMapOf<String, Any?>()
        data["deviceModel"] = Build.MODEL ?: "Unknown"
        data["apiLevel"] = Build.VERSION.SDK_INT
        data["targetSdk"] = applicationInfo.targetSdkVersion
        data["hasCutout"] = false
        data["hasPath"] = false
        return data
    }
}
