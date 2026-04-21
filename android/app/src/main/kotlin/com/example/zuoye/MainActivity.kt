package com.example.zuoye

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var locationService: TencentLocationService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "tencent_map_view",
                TencentMapFactory(application, flutterEngine.dartExecutor.binaryMessenger)
            )

        locationService = TencentLocationService(
            application,
            flutterEngine.dartExecutor.binaryMessenger
        )
    }

    override fun onDestroy() {
        locationService?.dispose()
        super.onDestroy()
    }
}
