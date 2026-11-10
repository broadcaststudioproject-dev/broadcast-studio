package com.kingjvr.pocket_pcr

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val STREAM_CHANNEL = "com.kingjvr.pocket_pcr/stream"
    private val UVC_CHANNEL = "com.kingjvr.pocket_pcr/uvc"
    private val SCREEN_RECORD_REQUEST_CODE = 1001

    private var pendingResult: MethodChannel.Result? = null
    private var currentRtmpUrl: String? = null
    private var currentCableRtmp: String = ""
    private var currentRestreamRtmp: String = ""
    private var currentSatelliteSrt: String = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
        ScreenStreamService.streamStatusListener = { message ->
            Handler(Looper.getMainLooper()).post {
                methodChannel.invokeMethod("onStreamStatusUpdate", message)
            }
        }

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenCaptureStreaming" -> {
                    Log.d("PocketPCR", "Live Stream Request Received")
                    currentCableRtmp = call.argument<String>("cableRtmp")?.trim().orEmpty()
                    currentRestreamRtmp = call.argument<String>("restreamRtmp")?.trim().orEmpty()
                    currentSatelliteSrt = call.argument<String>("satelliteSrt")?.trim().orEmpty()
                    currentRtmpUrl = call.argument<String>("rtmpUrl")
                        ?: call.argument<String>("url")

                    if (currentCableRtmp.isBlank() && currentRestreamRtmp.isBlank() &&
                        currentSatelliteSrt.isBlank() && currentRtmpUrl.isNullOrBlank()) {
                        result.error("INVALID_STREAM_URL", "Provide an RTMP stream URL.", null)
                    } else {
                        pendingResult = result
                        startMediaProjectionRequest()
                    }
                }
                "stopScreenCaptureStreaming" -> {
                    Log.d("PocketPCR", "Live Stream Stopped")
                    val stopIntent = Intent(this, ScreenStreamService::class.java).apply {
                        action = ScreenStreamService.ACTION_STOP
                    }
                    startService(stopIntent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UVC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startUsbCamera" -> {
                        Log.d("PocketPCR", "USB Camera Started")
                        result.success(1)
                    }
                    "stopUsbCamera" -> {
                        Log.d("PocketPCR", "USB Camera Stopped")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        super.onDestroy()
        ScreenStreamService.streamStatusListener = null
    }

    private fun startMediaProjectionRequest() {
        val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(manager.createScreenCaptureIntent(), SCREEN_RECORD_REQUEST_CODE)
    }

    @Deprecated("Deprecated in Android, retained for Flutter MediaProjection permission result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SCREEN_RECORD_REQUEST_CODE) return

        val result = pendingResult
        pendingResult = null
        if (resultCode == Activity.RESULT_OK && data != null) {
            Log.d("PocketPCR", "MediaProjection Permission Granted")
            startScreenStreamService(resultCode, data)
            result?.success(true)
        } else {
            Log.e("PocketPCR", "MediaProjection Permission Denied")
            result?.error("PERMISSION_DENIED", "Screen capture permission denied", null)
        }
    }

    private fun startScreenStreamService(resultCode: Int, data: Intent) {
        val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
            action = ScreenStreamService.ACTION_START
            putExtra(ScreenStreamService.EXTRA_RESULT_CODE, resultCode)
            putExtra(ScreenStreamService.EXTRA_DATA, data)
            putExtra(ScreenStreamService.EXTRA_URL, currentRtmpUrl)
            putExtra("EXTRA_CABLE_RTMP", currentCableRtmp)
            putExtra("EXTRA_RESTREAM_RTMP", currentRestreamRtmp)
            putExtra("EXTRA_SATELLITE_SRT", currentSatelliteSrt)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }
}
