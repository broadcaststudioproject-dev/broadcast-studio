package com.kingjvk.pocket_pcr

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
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
                "startScreenCaptureStreaming" -> {
                    val cable = call.argument<String>("cableRtmp")?.trim() ?: ""
                    val restream = call.argument<String>("restreamRtmp")?.trim() ?: ""
                    val srt = call.argument<String>("satelliteSrt")?.trim() ?: ""
                    
                    val url = listOf(cable, restream, srt).firstOrNull { it.isNotEmpty() }
                    
                    if (url.isNullOrEmpty()) {
                        result.error("NO_URL", "దయచేసి RTMP లింక్ ఇవ్వండి", null)
                        return@setMethodCallHandler
                    }

                    currentRtmpUrl = url
                    pendingResult = result

                    try {
                        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        startActivityForResult(projectionManager.createScreenCaptureIntent(), SCREEN_RECORD_REQUEST_CODE)
                    } catch (e: Exception) {
                        pendingResult?.error("PROJECTION_FAIL", e.message, null)
                        pendingResult = null
                    }
                }
                "stopScreenCaptureStreaming" -> {
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
