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
                "startScreenStream" -> { 
                    val url = call.argument<String>("rtmpUrl")?.trim()
                    
                    if (url.isNullOrEmpty()) {
                        result.error("NO_URL", "దయచేసి RTMP లింక్ ఇవ్వండి", null)
                        return@setMethodCallHandler
                    }

                    currentRtmpUrl = url
                    pendingResult = result

                    try {
                        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        // ముందు పాప్-అప్ పిలుస్తున్నాం (సర్వీస్ ఇంకా స్టార్ట్ చేయలేదు)
                        startActivityForResult(projectionManager.createScreenCaptureIntent(), SCREEN_RECORD_REQUEST_CODE)
                    } catch (e: Exception) {
                        pendingResult?.error("PROJECTION_FAIL", e.message, null)
                        pendingResult = null
                    }
                }
                
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
            // యూజర్ "Start Now" నొక్కితేనే (RESULT_OK) సర్వీస్ స్టార్ట్ అవుతుంది
            if (resultCode == Activity.RESULT_OK && data != null) {
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
