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

    private var pendingResult: MethodChannel.Result? = null
    private var currentRtmpUrl: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // ఫ్లట్టర్ లో ఉన్న పేరుకు మ్యాచ్ అయ్యేలా 'startScreenStream' గా మార్చబడింది
                "startScreenStream" -> { 
                    // ఫ్లట్టర్ నుండి మనం నేరుగా 'rtmpUrl' అనే పారామీటర్ ని పంపుతున్నాము, కాబట్టి దాన్ని రిసీవ్ చేసుకోవాలి
                    val url = call.argument<String>("rtmpUrl")?.trim()
                    
                    if (url.isNullOrEmpty()) {
                        result.error("NO_URL", "దయచేసి RTMP లింక్ ఇవ్వండి", null)
                        return@setMethodCallHandler
                    }

                    currentRtmpUrl = url
                    pendingResult = result

                    try {
                        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        // స్క్రీన్ రికార్డింగ్ పాప్-అప్ ని పిలుస్తున్నాం
                        startActivityForResult(projectionManager.createScreenCaptureIntent(), SCREEN_RECORD_REQUEST_CODE)
                    } catch (e: Exception) {
                        pendingResult?.error("PROJECTION_FAIL", e.message, null)
                        pendingResult = null
                    }
                }
                
                // ఫ్లట్టర్ లో ఉన్న పేరుకు మ్యాచ్ అయ్యేలా 'stopScreenStream' గా మార్చబడింది
                "stopScreenStream" -> {
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
            if (resultCode == Activity.RESULT_OK && data != null) {
                // యూజర్ పాప్-అప్ ని అనుమతించిన తర్వాత సర్వీస్ స్టార్ట్ అవుతుంది
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
                
                pendingResult?.success(true)
            } else {
                pendingResult?.error("DENIED", "స్క్రీన్ రికార్డింగ్ పర్మిషన్ ఇవ్వలేదు", null)
            }
            pendingResult = null
        }
    }
}
