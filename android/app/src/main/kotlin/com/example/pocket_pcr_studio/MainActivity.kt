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
            val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            startActivityForResult(mediaProjectionManager.createScreenCaptureIntent(), REQUEST_CODE_SCREEN_CAPTURE)
        } catch (e: Exception) {
            showToast("❌ పాపప్ ఓపెన్ అవ్వడంలో ఎర్రర్: \${e.message}")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        // పర్మిషన్ వచ్చాక సిగ్నల్ ఇక్కడికే వస్తుంది
        if (requestCode == REQUEST_CODE_SCREEN_CAPTURE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                showToast("✅ పర్మిషన్ సక్సెస్! సర్వీస్ స్టార్ట్ అవుతోంది...")
                
                try {
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
                } catch (e: Exception) {
                    showToast("❌ సర్వీస్ బ్లాక్ అయింది: \${e.message}")
                }
            } else {
                showToast("⚠️ రికార్డింగ్ పర్మిషన్ క్యాన్సిల్ అయింది! కోడ్: \$resultCode")
            }
        }
    }

    private fun stopScreenCapture() {
        val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
            action = "STOP_STREAM"
        }
        startService(serviceIntent)
    }
    
    private fun showToast(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        }
    }
}
