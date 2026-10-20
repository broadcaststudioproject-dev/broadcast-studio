package com.kingjvk.pocket_pcr

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kingjvk.pocket_pcr/stream"
    private val SCREEN_RECORD_REQUEST_CODE = 1000

    private var currentRtmpUrl: String? = null
    private var cableRtmp: String? = null
    private var restreamRtmp: String? = null
    private var satelliteSrt: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenStream", "startScreenCaptureStreaming" -> { 
                    
                    // 1. ఫ్లట్టర్ యాప్ కంట్రోల్ రూమ్ నుండి వస్తున్న లింకులన్నింటినీ క్యాచ్ చేస్తున్నాం
                    currentRtmpUrl = call.argument<String>("rtmpUrl")?.trim()
                    cableRtmp = call.argument<String>("cableRtmp")?.trim()
                    restreamRtmp = call.argument<String>("restreamRtmp")?.trim()
                    satelliteSrt = call.argument<String>("satelliteSrt")?.trim()

                    // ఫ్లట్టర్ యాప్ హ్యాంగ్ అవ్వకుండా వెంటనే సక్సెస్ సిగ్నల్ ఇచ్చేస్తున్నాం
                    result.success(true)

                    // 2. 🔴 కచ్చితంగా పాప్-అప్ స్క్రీన్ మీదకు రావడానికి Main Thread (UI) ని వాడుతున్నాం
                    Handler(Looper.getMainLooper()).post {
                        try {
                            val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                            val captureIntent = projectionManager.createScreenCaptureIntent()
                            // ఇక్కడ ఆండ్రాయిడ్ సిస్టమ్ "Start recording?" పాప్-అప్ ను పిలుస్తుంది
                            startActivityForResult(captureIntent, SCREEN_RECORD_REQUEST_CODE)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
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
            // 3. యూజర్ పాప్-అప్ లో "Start Now" నొక్కిన వెంటనే...
            if (resultCode == Activity.RESULT_OK && data != null) {
                
                // అన్ని లింకులను ఒకేసారి బ్యాక్‌గ్రౌండ్ వీడియో సర్వీస్ (ScreenStreamService) కి పంపుతున్నాం
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
            }
        }
    }
}
