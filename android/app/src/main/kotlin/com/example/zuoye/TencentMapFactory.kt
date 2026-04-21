package com.example.zuoye

import android.app.Application
import android.content.Context
import com.tencent.tencentmap.mapsdk.maps.MapView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class TencentMapFactory(
    private val application: Application,
    private val messenger: BinaryMessenger
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
        val mapView = MapView(context ?: application)
        return TencentMapController(application, mapView, viewId, messenger)
    }
}
