package com.kingjvr.pocket_pcr

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kingjvr.pocket_pcr/stream"
    private val SCREEN_RECORD_REQUEST_CODE = 1000

    private var currentRtmpUrl: String? = null
    private var cableRtmp: String? = null
    private var restreamRtmp: String? = null
    private var satelliteSrt: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenStream", "startScreenCaptureStreaming" -> { 
                    currentRtmpUrl = call.argument<String>("rtmpUrl")?.trim()
                    cableRtmp = call.argument<String>("cableRtmp")?.trim()
                    restreamRtmp = call.argument<String>("restreamRtmp")?.trim()
                    satelliteSrt = call.argument<String>("satelliteSrt")?.trim()

                    // ఫ్లట్టర్‌ని వెయిట్ చేయిస్తున్నాం (పాప్-అప్ కోసం)
                    pendingResult = result

                    try {
                        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        val captureIntent = projectionManager.createScreenCaptureIntent()
                        // 🔴 ఇక్కడే ఆండ్రాయిడ్ సిస్టమ్ "Start Recording" పాప్-అప్‌ని పిలుస్తుంది!
                        startActivityForResult(captureIntent, SCREEN_RECORD_REQUEST_CODE)
                    } catch (e: Exception) {
                        pendingResult?.error("INTENT_ERROR", e.message, null)
                        pendingResult = null
                    }
                }
                "stopScreenStream", "stopScreenCaptureStreaming" -> {
                    stopService(Intent(this, ScreenStreamService::class.java))
                    result.success(true)
                }
                "pauseScreenStream", "pauseScreenCaptureStreaming" -> {
                    stopService(Intent(this, ScreenStreamService::class.java))
                    result.success(true)
                }
                "startUsbCamera" -> result.error("NOT_IMPLEMENTED", "USB Not Implemented", null)
                "stopUsbCamera" -> result.success(true)
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            // 🔴 యూజర్ పాప్-అప్‌లో "Start Now" నొక్కిన వెంటనే సర్వీస్ స్టార్ట్ అవుతుంది
            if (resultCode == Activity.RESULT_OK && data != null) {
                
                val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
                    putExtra("resultCode", resultCode)
                    putExtra("data", data)
                    putExtra("rtmpUrl", currentRtmpUrl)
                    putExtra("cableRtmp", cableRtmp)
                    putExtra("restreamRtmp", restreamRtmp)
                    putExtra("satelliteSrt", satelliteSrt)
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
                pendingResult?.success(true)
            } else {
                // యూజర్ పాప్-అప్ ని కాన్సిల్ చేస్తే..
                pendingResult?.success(false) 
            }
            pendingResult = null
        }
    }
}
