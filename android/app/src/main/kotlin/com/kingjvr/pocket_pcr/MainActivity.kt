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
import io.flutter.plugins.GeneratedPluginRegistrant // 🔴 వీడియో ప్లగిన్స్ కోసం

class MainActivity: FlutterActivity() {
    private val STREAM_CHANNEL = "com.kingjvr.pocket_pcr/stream"
    private val UVC_CHANNEL = "com.kingjvr.pocket_pcr/uvc"

    private val SCREEN_RECORD_REQUEST_CODE = 1001
    
    private var pendingResult: MethodChannel.Result? = null
    private var currentRtmpUrl: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 🔴 వీడియో ప్లేయర్స్ (VLC, YouTube, VideoPlayer) పనిచేయడానికి ఇది తప్పనిసరి 🔴
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
        
        // 🔴 ఫ్లట్టర్‌కి మెసేజ్ పంపే సింపుల్ లిజినర్ (ఎటువంటి ఎర్రర్స్ రావు) 🔴
        ScreenStreamService.streamStatusListener = { message ->
            methodChannel.invokeMethod("onStreamStatusUpdate", message)
        }
        
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenCaptureStreaming" -> {
                    Log.d("PocketPCR", "Live Stream Request Received")
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UVC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startUsbCamera" -> {
                    result.success(1)
                }
                "stopUsbCamera" -> {
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // మెమరీ లీక్ అవ్వకుండా లిజినర్‌ని తీసేస్తున్నాం
        ScreenStreamService.streamStatusListener = null
    }

    private fun startMediaProjectionRequest() {
        val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(mediaProjectionManager.createScreenCaptureIntent(), SCREEN_RECORD_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                startScreenStreamService(resultCode, data)
                pendingResult?.success(true)
            } else {
                pendingResult?.error("PERMISSION_DENIED", "Screen capture permission denied", null)
            }
            pendingResult = null
        }
    }

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
