package com.kingjvr.pocket_pcr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity: FlutterActivity() {
    // మీరు ఫ్లట్టర్ లో వాడిన రెండు ఛానెల్స్ పేర్లు ఇవే
    private val STREAM_CHANNEL = "com.kingjvr.pocket_pcr/stream"
    private val UVC_CHANNEL = "com.kingjvr.pocket_pcr/uvc"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 1. లైవ్ స్ట్రీమింగ్ (Screen Capture & RTMP) కనెక్షన్
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenCaptureStreaming" -> {
                    Log.d("PocketPCR", "Live Stream Started")
                    // భవిష్యత్తులో ఇక్కడ RTMP బ్రాడ్కాస్టింగ్ లైబ్రరీ కోడ్ రాయాలి
                    
                    // ఫ్లట్టర్ యాప్‌కి ఎర్రర్ రాకుండా true అని పంపుతున్నాం
                    result.success(true)
                }
                "stopScreenCaptureStreaming" -> {
                    Log.d("PocketPCR", "Live Stream Stopped")
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 2. USB కెమెరా (UVC) కనెక్షన్
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UVC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startUsbCamera" -> {
                    Log.d("PocketPCR", "USB Camera Started")
                    // డమ్మీ టెక్స్చర్ ID 1 పంపుతున్నాం
                    result.success(1)
                }
                "stopUsbCamera" -> {
                    Log.d("PocketPCR", "USB Camera Stopped")
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
