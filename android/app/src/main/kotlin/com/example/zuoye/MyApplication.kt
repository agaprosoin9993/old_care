package com.example.zuoye

import android.app.Application
import com.tencent.tencentmap.mapsdk.maps.TencentMapInitializer

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        
        TencentMapInitializer.setAgreePrivacy(true)
    }
}
