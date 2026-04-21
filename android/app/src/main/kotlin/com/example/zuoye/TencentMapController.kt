package com.example.zuoye

import android.app.Application
import android.content.Context
import android.os.Bundle
import android.view.View
import com.tencent.tencentmap.mapsdk.maps.MapView
import com.tencent.tencentmap.mapsdk.maps.TencentMap
import com.tencent.tencentmap.mapsdk.maps.CameraUpdateFactory
import com.tencent.tencentmap.mapsdk.maps.model.LatLng
import com.tencent.tencentmap.mapsdk.maps.model.MarkerOptions
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
        val markerOptions = MarkerOptions()
            .position(LatLng(latitude, longitude))
            .title(title)
            .anchor(0.5f, 1f)
        
        tencentMap?.addMarker(markerOptions)?.let { marker ->
            markers.add(marker)
        }
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
