package com.example.pocket_pcr_studio

import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ssyatratv.pocket_pcr/stream"
    private val REQUEST_CODE_SCREEN_CAPTURE = 100
    private var pendingRtmpUrl: String = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startScreenStream") {
                pendingRtmpUrl = call.argument<String>("rtmpUrl") ?: ""
                startScreenCapture()
                result.success(true)
            } else if (call.method == "stopScreenStream") {
                stopScreenCapture()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startScreenCapture() {
        val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(mediaProjectionManager.createScreenCaptureIntent(), REQUEST_CODE_SCREEN_CAPTURE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // సిస్టమ్ పర్మిషన్ ఇస్తే, రికార్డింగ్ సర్వీస్ స్టార్ట్ అవుతుంది
        if (requestCode == REQUEST_CODE_SCREEN_CAPTURE && resultCode == RESULT_OK && data != null) {
            val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
                action = "START_STREAM"
                putExtra("url", pendingRtmpUrl)
                putExtra("resultCode", resultCode)
                putExtra("data", data)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        }
    }

    private fun stopScreenCapture() {
        val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
            action = "STOP_STREAM"
        }
        startService(serviceIntent)
    }
}
