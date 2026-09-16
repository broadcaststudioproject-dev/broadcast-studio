package com.ssyatratv.pocket_pcr_studio

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ssyatratv.pocket_pcr/stream"
    private val REQUEST_CODE_SCREEN_CAPTURE = 1000
    private var pendingRtmpUrl: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenStream" -> {
                    val rtmpUrl = call.argument<String>("rtmpUrl")
                    if (rtmpUrl != null) {
                        pendingRtmpUrl = rtmpUrl
                        requestScreenCapture()
                        result.success(true)
                    } else {
                        result.error("INVALID_URL", "RTMP URL is null", null)
                    }
                }
                "stopScreenStream" -> {
                    stopScreenService()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun requestScreenCapture() {
        val projectionManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val intent = projectionManager.createScreenCaptureIntent()
        startActivityForResult(intent, REQUEST_CODE_SCREEN_CAPTURE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_SCREEN_CAPTURE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
                    putExtra("RESULT_CODE", resultCode)
                    putExtra("DATA", data)
                    putExtra("RTMP_URL", pendingRtmpUrl)
                }
                startForegroundService(serviceIntent)
            }
        }
    }

    private fun stopScreenService() {
        val serviceIntent = Intent(this, ScreenStreamService::class.java)
        stopService(serviceIntent)
    }
}
