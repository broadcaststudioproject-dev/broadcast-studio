package com.kingjvk.pocket_pcr

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
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
                    val url = call.argument<String>("rtmpUrl")?.trim()
                    
                    if (url.isNullOrEmpty()) {
                        result.error("NO_URL", "దయచేసి RTMP లింక్ ఇవ్వండి", null)
                        return@setMethodCallHandler
                    }

                    // ఫ్లట్టర్ నుండి వచ్చే అన్ని లింకులను తీసుకుంటున్నాం (Multi-streaming కోసం)
                    currentRtmpUrl = url
                    cableRtmp = call.argument<String>("cableRtmp")?.trim()
                    restreamRtmp = call.argument<String>("restreamRtmp")?.trim()
                    satelliteSrt = call.argument<String>("satelliteSrt")?.trim()

                    try {
                        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        
                        // 🔴 పవర్ ఫుల్ ఫిక్స్: Flutter కమాండ్ కోసం వెయిట్ చేయకుండా వెంటనే Success అని చెప్పేస్తున్నాం
                        // దీనివల్ల UI హ్యాంగ్ అవ్వదు, కంట్రోల్ రూమ్ వెనుక మెసేజ్‌లు ఆగిపోవు!
                        result.success(true)

                        // వెంటనే స్క్రీన్ రికార్డింగ్ పర్మిషన్ పాప్-అప్ ను పిలుస్తున్నాం
                        startActivityForResult(projectionManager.createScreenCaptureIntent(), SCREEN_RECORD_REQUEST_CODE)
                        
                    } catch (e: Exception) {
                        // ఒకవేళ పర్మిషన్ మేనేజర్ ఫెయిల్ అయితే ఎర్రర్ పంపుతాం
                        result.error("PROJECTION_FAIL", e.message, null)
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
            // యూజర్ పాప్-అప్ లో "Start Now" నొక్కితేనే సర్వీస్ స్టార్ట్ అవుతుంది
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
            }
        }
    }
}
