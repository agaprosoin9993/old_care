package com.example.zuoye

import android.app.Application
import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.view.View
import com.tencent.tencentmap.mapsdk.maps.MapView
import com.tencent.tencentmap.mapsdk.maps.TencentMap
import com.tencent.tencentmap.mapsdk.maps.CameraUpdateFactory
import com.tencent.tencentmap.mapsdk.maps.model.LatLng
import com.tencent.tencentmap.mapsdk.maps.model.MarkerOptions
import com.tencent.tencentmap.mapsdk.maps.model.BitmapDescriptor
import com.tencent.tencentmap.mapsdk.maps.model.BitmapDescriptorFactory
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

class TencentMapController(
    private val context: Context,
    private val mapView: MapView,
    private val id: Int,
    private val messenger: io.flutter.plugin.common.BinaryMessenger
) : PlatformView, Application.ActivityLifecycleCallbacks {

    private var tencentMap: TencentMap? = null
    private var methodChannel: MethodChannel
    private var currentZoom: Float = 12f
    private val markers = mutableListOf<com.tencent.tencentmap.mapsdk.maps.model.Marker>()
    private var isDisposed = false

    init {
        tencentMap = mapView.map
        
        methodChannel = MethodChannel(messenger, "tencent_map_$id")
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "moveToLocation" -> {
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")
                    val zoom = call.argument<Double>("zoom")
                    if (latitude != null && longitude != null) {
                        moveCamera(latitude, longitude, (zoom?.toFloat() ?: currentZoom))
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Invalid arguments", null)
                    }
                }
                "zoomIn" -> {
                    zoomIn()
                    result.success(null)
                }
                "zoomOut" -> {
                    zoomOut()
                    result.success(null)
                }
                "addMarker" -> {
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")
                    val title = call.argument<String>("title")
                    val color = call.argument<String>("color")
                    if (latitude != null && longitude != null) {
                        addMarker(latitude, longitude, title ?: "", color)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Invalid arguments", null)
                    }
                }
                "clearMarkers" -> {
                    clearMarkers()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        tencentMap?.apply {
            uiSettings?.apply {
                setZoomGesturesEnabled(true)
                setScrollGesturesEnabled(true)
                setRotateGesturesEnabled(true)
                setZoomControlsEnabled(false)
                setScaleViewEnabled(true)
                setMyLocationButtonEnabled(false)
            }
            moveCamera(
                CameraUpdateFactory.newLatLngZoom(
                    LatLng(39.9042, 116.4074),
                    currentZoom
                )
            )
        }
        
        if (context is Application) {
            context.registerActivityLifecycleCallbacks(this)
        }
        
        mapView.onStart()
    }

    private fun moveCamera(latitude: Double, longitude: Double, zoom: Float) {
        currentZoom = zoom
        tencentMap?.animateCamera(
            CameraUpdateFactory.newLatLngZoom(
                LatLng(latitude, longitude),
                zoom
            )
        )
    }

    private fun zoomIn() {
        currentZoom = (currentZoom + 1f).coerceAtMost(18f)
        tencentMap?.animateCamera(CameraUpdateFactory.zoomIn())
    }

    private fun zoomOut() {
        currentZoom = (currentZoom - 1f).coerceAtLeast(3f)
        tencentMap?.animateCamera(CameraUpdateFactory.zoomOut())
    }

    private fun addMarker(latitude: Double, longitude: Double, title: String, color: String?) {
        val hue = getMarkerHue(color)
        
        val markerOptions = MarkerOptions()
            .position(LatLng(latitude, longitude))
            .title(title)
            .anchor(0.5f, 1f)
            .icon(BitmapDescriptorFactory.defaultMarker(hue))
        
        tencentMap?.addMarker(markerOptions)?.let { marker ->
            markers.add(marker)
        }
    }

    private fun getMarkerHue(colorString: String?): Float {
        if (colorString.isNullOrEmpty()) return BitmapDescriptorFactory.HUE_RED
        
        return try {
            var hex = colorString.replace("#", "")
            if (hex.length == 8) {
                hex = hex.substring(2)
            }
            val color = Color.parseColor("#$hex")
            
            when {
                color == Color.RED -> BitmapDescriptorFactory.HUE_RED
                color == Color.BLUE -> BitmapDescriptorFactory.HUE_BLUE
                color == Color.GREEN -> BitmapDescriptorFactory.HUE_GREEN
                color == Color.YELLOW -> BitmapDescriptorFactory.HUE_YELLOW
                color == Color.MAGENTA -> BitmapDescriptorFactory.HUE_MAGENTA
                color == Color.CYAN -> BitmapDescriptorFactory.HUE_CYAN
                isBlueColor(color) -> BitmapDescriptorFactory.HUE_BLUE
                isRedColor(color) -> BitmapDescriptorFactory.HUE_RED
                isGreenColor(color) -> BitmapDescriptorFactory.HUE_GREEN
                else -> BitmapDescriptorFactory.HUE_RED
            }
        } catch (e: Exception) {
            BitmapDescriptorFactory.HUE_RED
        }
    }
    
    private fun isBlueColor(color: Int): Boolean {
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)
        return b > r && b > g
    }
    
    private fun isRedColor(color: Int): Boolean {
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)
        return r > g && r > b
    }
    
    private fun isGreenColor(color: Int): Boolean {
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)
        return g > r && g > b
    }

    private fun clearMarkers() {
        markers.forEach { it.remove() }
        markers.clear()
    }

    override fun getView(): View {
        return mapView
    }

    override fun dispose() {
        if (isDisposed) return
        isDisposed = true
        
        if (context is Application) {
            context.unregisterActivityLifecycleCallbacks(this)
        }
        
        methodChannel.setMethodCallHandler(null)
        clearMarkers()
        mapView.onDestroy()
    }

    override fun onActivityCreated(activity: android.app.Activity, savedInstanceState: Bundle?) {}
    
    override fun onActivityStarted(activity: android.app.Activity) {}
    
    override fun onActivityResumed(activity: android.app.Activity) {
        if (!isDisposed) {
            mapView.onResume()
        }
    }
    
    override fun onActivityPaused(activity: android.app.Activity) {
        if (!isDisposed) {
            mapView.onPause()
        }
    }
    
    override fun onActivityStopped(activity: android.app.Activity) {}
    
    override fun onActivitySaveInstanceState(activity: android.app.Activity, outState: Bundle) {}
    
    override fun onActivityDestroyed(activity: android.app.Activity) {}
}
