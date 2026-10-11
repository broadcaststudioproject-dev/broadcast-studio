package com.kingjvk.pocket_pcr

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.kingjvk.pocket_pcr/stream"
    private val SCREEN_RECORD_REQUEST_CODE = 1001
    
    private var currentCableRtmp: String? = null
    private var isNoiseCancellationEnabled: Boolean = false
    
    // ఇక్కడే మనం పాపప్ కోసం లాక్ వేస్తున్నాం! (pendingResult)
    private var pendingResult: MethodChannel.Result? = null
    private lateinit var mediaProjectionManager: MediaProjectionManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startScreenStream") {
                currentCableRtmp = call.argument<String>("rtmpUrl")
                isNoiseCancellationEnabled = call.argument<Boolean>("noiseCancellation") ?: false
                
                // రిజల్ట్‌ని పెండింగ్‌లో పెడుతున్నాం (యూజర్ Start now నొక్కే వరకు వెయిట్ చేస్తుంది)
                pendingResult = result

                if (currentCableRtmp.isNullOrEmpty()) {
                    pendingResult?.error("INVALID_URL", "Streaming URL is missing", null)
                    pendingResult = null
                    return@setMethodCallHandler
                }

                try {
                    val captureIntent = mediaProjectionManager.createScreenCaptureIntent()
                    startActivityForResult(captureIntent, SCREEN_RECORD_REQUEST_CODE)
                } catch (e: Exception) {
                    pendingResult?.error("PROJECTION_ERROR", e.message, null)
                    pendingResult = null
                }
            } else if (call.method == "stopScreenStream") {
                val serviceIntent = Intent(this, ScreenStreamService::class.java)
                stopService(serviceIntent)
                Toast.makeText(this, "లైవ్ ఆపబడింది!", Toast.LENGTH_SHORT).show()
                result.success(true)
            } else if (call.method == "startUsbCamera") {
                try {
                    val textureRegistry = flutterEngine.renderer
                    val surfaceEntry = textureRegistry.createSurfaceTexture()
                    result.success(surfaceEntry.id().toInt()) 
                } catch (e: Exception) {
                    result.error("UVC_ERROR", "OTG Denied", null)
                }
            } else if (call.method == "stopUsbCamera") {
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        // మీరు పాపప్‌లో 'Start now' నొక్కిన తర్వాతే ఈ కోడ్ రన్ అవుతుంది!
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                Toast.makeText(this, "లైవ్ స్టార్ట్ అవుతోంది...", Toast.LENGTH_SHORT).show()
                val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
                    putExtra("resultCode", resultCode)
                    putExtra("data", data)
                    putExtra("rtmpUrl", currentCableRtmp)
                    putExtra("noiseCancellation", isNoiseCancellationEnabled)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
                
                // ఇక్కడ సక్సెస్ పంపితేనే, ఫ్లట్టర్ యాప్ స్క్రీన్‌ని అడ్డంగా తిప్పుతుంది!
                pendingResult?.success(true)
            } else {
                Toast.makeText(this, "రికార్డింగ్ క్యాన్సిల్ చేశారు", Toast.LENGTH_SHORT).show()
                pendingResult?.error("DENIED", "User denied screen recording", null)
            }
            pendingResult = null
        }
    }
}
