package com.example.zuoye

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

class TencentLocationService(
    private val context: Context,
    private val messenger: io.flutter.plugin.common.BinaryMessenger
) : LocationListener {

    private val locationManager: LocationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private var methodChannel: MethodChannel
    private var pendingResult: MethodChannel.Result? = null
    private var isRequesting = false
    private var timeoutHandler: android.os.Handler? = null
    private var timeoutRunnable: Runnable? = null

    companion object {
        const val CHANNEL_NAME = "tencent_location_service"
        private const val DEFAULT_LATITUDE = 39.9042
        private const val DEFAULT_LONGITUDE = 116.4074
        private const val TIMEOUT_MS = 5000L
    }

    init {
        methodChannel = MethodChannel(messenger, CHANNEL_NAME)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentLocation" -> {
                    requestSingleLocation(result)
                }
                "stopLocation" -> {
                    stopLocationUpdates()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestSingleLocation(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            sendDefaultLocation(result, "没有定位权限")
            return
        }

        if (isRequesting) {
            result.error("ALREADY_REQUESTING", "正在定位中", null)
            return
        }

        isRequesting = true
        pendingResult = result

        try {
            val lastKnown = getBestLastKnownLocation()
            if (lastKnown != null && System.currentTimeMillis() - lastKnown.time < 60000) {
                android.util.Log.d("LocationService", "使用缓存位置: ${lastKnown.latitude}, ${lastKnown.longitude}")
                isRequesting = false
                pendingResult = null
                sendLocationResult(lastKnown, "缓存位置", result)
                return
            }
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "获取缓存位置失败: ${e.message}")
        }

        try {
            val allProviders = locationManager.allProviders
            android.util.Log.d("LocationService", "可用定位服务: $allProviders")
            
            val enabledProviders = locationManager.getProviders(true)
            android.util.Log.d("LocationService", "已启用定位服务: $enabledProviders")
            
            var requested = false
            
            val providersToUse = mutableListOf<String>()
            if (enabledProviders.contains(LocationManager.GPS_PROVIDER)) {
                providersToUse.add(LocationManager.GPS_PROVIDER)
            }
            if (enabledProviders.contains(LocationManager.NETWORK_PROVIDER)) {
                providersToUse.add(LocationManager.NETWORK_PROVIDER)
            }
            if (enabledProviders.contains(LocationManager.PASSIVE_PROVIDER)) {
                providersToUse.add(LocationManager.PASSIVE_PROVIDER)
            }
            
            for (provider in enabledProviders) {
                if (!providersToUse.contains(provider)) {
                    providersToUse.add(provider)
                }
            }

            for (provider in providersToUse) {
                try {
                    locationManager.requestLocationUpdates(
                        provider,
                        0L,
                        0f,
                        this,
                        Looper.getMainLooper()
                    )
                    requested = true
                    android.util.Log.d("LocationService", "请求 $provider 定位")
                } catch (e: Exception) {
                    android.util.Log.e("LocationService", "请求 $provider 失败: ${e.message}")
                }
            }

            if (!requested) {
                android.util.Log.w("LocationService", "没有可用的定位服务")
                val lastKnown = getBestLastKnownLocation()
                if (lastKnown != null) {
                    isRequesting = false
                    pendingResult = null
                    sendLocationResult(lastKnown, "缓存位置", result)
                } else {
                    isRequesting = false
                    pendingResult = null
                    sendDefaultLocation(result, "没有可用的定位服务")
                }
            } else {
                timeoutHandler = android.os.Handler(Looper.getMainLooper())
                timeoutRunnable = Runnable {
                    if (isRequesting && pendingResult != null) {
                        android.util.Log.w("LocationService", "定位超时")
                        stopLocationUpdates()
                        val lastKnown = getBestLastKnownLocation()
                        if (lastKnown != null) {
                            sendLocationResult(lastKnown, "缓存位置", pendingResult!!)
                        } else {
                            sendDefaultLocation(pendingResult!!, "定位超时")
                        }
                        isRequesting = false
                        pendingResult = null
                    }
                }
                timeoutHandler?.postDelayed(timeoutRunnable!!, TIMEOUT_MS)
            }
        } catch (e: SecurityException) {
            isRequesting = false
            pendingResult = null
            sendDefaultLocation(result, "定位权限被拒绝")
        } catch (e: Exception) {
            android.util.Log.e("LocationService", "定位失败: ${e.message}")
            isRequesting = false
            pendingResult = null
            sendDefaultLocation(result, "定位失败: ${e.message}")
        }
    }

    private fun getBestLastKnownLocation(): Location? {
        if (!hasLocationPermission()) return null

        try {
            val providers = locationManager.allProviders
            var bestLocation: Location? = null
            var bestTime: Long = 0

            for (provider in providers) {
                try {
                    val location = locationManager.getLastKnownLocation(provider)
                    if (location != null) {
                        android.util.Log.d("LocationService", "$provider 缓存: ${location.latitude}, ${location.longitude}, time=${location.time}")
                        if (location.time > bestTime) {
                            bestTime = location.time
                            bestLocation = location
                        }
                    }
                } catch (e: SecurityException) {
                }
            }

            return bestLocation
        } catch (e: SecurityException) {
            return null
        }
    }

    override fun onLocationChanged(location: Location) {
        android.util.Log.d("LocationService", "收到位置更新: ${location.latitude}, ${location.longitude}, provider=${location.provider}")
        if (isRequesting && pendingResult != null) {
            cancelTimeout()
            stopLocationUpdates()
            sendLocationResult(location, location.provider ?: "实时定位", pendingResult!!)
            isRequesting = false
            pendingResult = null
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
        android.util.Log.d("LocationService", "定位服务状态变化: $provider, status=$status")
    }

    override fun onProviderEnabled(provider: String) {
        android.util.Log.d("LocationService", "定位服务启用: $provider")
    }

    override fun onProviderDisabled(provider: String) {
        android.util.Log.d("LocationService", "定位服务禁用: $provider")
    }

    private fun cancelTimeout() {
        timeoutRunnable?.let {
            timeoutHandler?.removeCallbacks(it)
        }
        timeoutHandler = null
        timeoutRunnable = null
    }

    private fun stopLocationUpdates() {
        try {
            locationManager.removeUpdates(this)
        } catch (e: SecurityException) {
        }
    }

    private fun hasLocationPermission(): Boolean {
        val fineLocation = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarseLocation = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        return fineLocation || coarseLocation
    }

    private fun sendLocationResult(location: Location, provider: String, result: MethodChannel.Result) {
        val locationData = mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to location.accuracy,
            "address" to "",
            "province" to "",
            "city" to "",
            "district" to "",
            "street" to "",
            "provider" to provider
        )
        result.success(locationData)
    }

    private fun sendDefaultLocation(result: MethodChannel.Result, reason: String) {
        android.util.Log.w("LocationService", "使用默认位置: $reason")
        val locationData = mapOf(
            "latitude" to DEFAULT_LATITUDE,
            "longitude" to DEFAULT_LONGITUDE,
            "accuracy" to 0.0,
            "address" to "北京市东城区",
            "province" to "北京市",
            "city" to "北京市",
            "district" to "东城区",
            "street" to "",
            "provider" to "默认位置($reason)"
        )
        result.success(locationData)
    }

    fun dispose() {
        cancelTimeout()
        stopLocationUpdates()
        methodChannel.setMethodCallHandler(null)
    }
}
