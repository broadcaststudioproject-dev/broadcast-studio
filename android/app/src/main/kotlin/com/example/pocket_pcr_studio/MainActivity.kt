package com.example.pocket_pcr_studio

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.Toast
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
        try {
            // 1. ఆండ్రాయిడ్ 14 క్రాష్ అవ్వకుండా ముందుగా బ్యాక్‌గ్రౌండ్ సర్వీస్ ని ఫోర్స్‌గా ఆపేస్తున్నాం
            stopScreenCapture()
            
            // 2. పాత పర్మిషన్ పూర్తిగా క్లియర్ అవ్వడానికి ఒక అర సెకను (500ms) ఆగి కొత్త పర్మిషన్ అడుగుతున్నాం
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    startActivityForResult(mediaProjectionManager.createScreenCaptureIntent(), REQUEST_CODE_SCREEN_CAPTURE)
                } catch (e: Exception) {
                    showToast("Popup Error: ${e.message}")
                }
            }, 500)
        } catch (e: Exception) {
            showToast("Error: ${e.message}")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == REQUEST_CODE_SCREEN_CAPTURE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                try {
                    val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
                        action = ScreenStreamService.ACTION_START
                        putExtra(ScreenStreamService.EXTRA_URL, pendingRtmpUrl)
                        putExtra(ScreenStreamService.EXTRA_RESULT_CODE, resultCode)
                        putExtra(ScreenStreamService.EXTRA_DATA, data)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                } catch (e: Exception) {
                    showToast("Service Error: ${e.message}")
                }
            } else {
                showToast("Recording permission cancelled!")
            }
        }
    }

    private fun stopScreenCapture() {
        try {
            val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
                action = ScreenStreamService.ACTION_STOP
            }
            startService(serviceIntent)
        } catch (e: Exception) {
            // Ignore if service is already stopped
        }
    }
    
    private fun showToast(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        }
    }
}
