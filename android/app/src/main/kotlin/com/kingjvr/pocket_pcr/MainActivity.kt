package com.kingjvr.pocket_pcr

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val STREAM_CHANNEL = "com.kingjvr.pocket_pcr/stream"
    private val UVC_CHANNEL = "com.kingjvr.pocket_pcr/uvc"

    // అనుమతి కోసం రిక్వెస్ట్ కోడ్
    private val SCREEN_RECORD_REQUEST_CODE = 1001
    
    // ఫ్లట్టర్‌కు రిజల్ట్ పంపడానికి వేరియబుల్స్
    private var pendingResult: MethodChannel.Result? = null
    private var currentRtmpUrl: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 1. లైవ్ స్ట్రీమింగ్ (Screen Capture & RTMP) కనెక్షన్
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenCaptureStreaming" -> {
                    Log.d("PocketPCR", "Live Stream Request Received")
                    // ఫ్లట్టర్ నుండి వచ్చే RTMP URL ను తీసుకుంటున్నాం
                    currentRtmpUrl = call.argument<String>("rtmpUrl") ?: call.argument<String>("url")
                    
                    pendingResult = result
                    startMediaProjectionRequest()
                }
                "stopScreenCaptureStreaming" -> {
                    Log.d("PocketPCR", "Live Stream Stopped")
                    val stopIntent = Intent(this, ScreenStreamService::class.java).apply {
                        action = "STOP_STREAM"
                    }
                    startService(stopIntent)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 2. USB కెమెరా (UVC) కనెక్షన్ (మీ పాత కోడ్ యథాతథంగా ఉంచబడింది)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UVC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startUsbCamera" -> {
                    Log.d("PocketPCR", "USB Camera Started")
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

    // యూజర్‌ను స్క్రీన్ రికార్డింగ్ అనుమతి అడగడం
    private fun startMediaProjectionRequest() {
        val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(mediaProjectionManager.createScreenCaptureIntent(), SCREEN_RECORD_REQUEST_CODE)
    }

    // యూజర్ అనుమతి ఇచ్చాడా లేదా అని చెక్ చేయడం
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                Log.d("PocketPCR", "MediaProjection Permission Granted")
                startScreenStreamService(resultCode, data)
                pendingResult?.success(true)
            } else {
                Log.e("PocketPCR", "MediaProjection Permission Denied")
                pendingResult?.error("PERMISSION_DENIED", "Screen capture permission denied", null)
            }
            pendingResult = null
        }
    }

    // అనుమతి వచ్చిన తర్వాత సర్వీస్‌ను స్టార్ట్ చేయడం
    private fun startScreenStreamService(resultCode: Int, data: Intent) {
        val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
            putExtra("resultCode", resultCode)
            putExtra("data", data)
            putExtra("rtmpUrl", currentRtmpUrl)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
}
