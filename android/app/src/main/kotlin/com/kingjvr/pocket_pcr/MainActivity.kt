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
    // 🔴 ఫ్లట్టర్ సైడ్ ఛానల్ పేరుకు సరిగ్గా మ్యాచ్ చేయబడింది
    private val CHANNEL = "com.kingjvr.pocket_pcr/stream"
    private val REQUEST_CODE_SCREEN_CAPTURE = 100
    
    private var pendingRtmpUrl: String = ""
    private var pendingCableRtmp: String = ""
    private var pendingRestreamRtmp: String = ""
    private var pendingSatelliteSrt: String = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startScreenCaptureStreaming" || call.method == "startScreenStream") {
                // 🔴 మల్టీ-స్ట్రీమ్ లింక్‌లను ఫ్లట్టర్ నుండి రిసీవ్ చేసుకోవడం
                pendingRtmpUrl = call.argument<String>("rtmpUrl") ?: ""
                pendingCableRtmp = call.argument<String>("cableRtmp") ?: ""
                pendingRestreamRtmp = call.argument<String>("restreamRtmp") ?: ""
                pendingSatelliteSrt = call.argument<String>("satelliteSrt") ?: ""

                startScreenCapture()
                result.success(true)
            } else if (call.method == "stopScreenCaptureStreaming" || call.method == "stopScreenStream") {
                stopScreenCapture()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startScreenCapture() {
        try {
            // 1. ఆండ్రాయిడ్ క్రాష్ అవ్వకుండా ముందుగా బ్యాక్‌గ్రౌండ్ సర్వీస్ ని ఆపేయడం
            stopScreenCapture()
            
            // 2. పర్మిషన్ డైలాగ్ కోసం కొద్దిగా టైమ్ ఇవ్వడం
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
                        putExtra("EXTRA_CABLE_RTMP", pendingCableRtmp)
                        putExtra("EXTRA_RESTREAM_RTMP", pendingRestreamRtmp)
                        putExtra("EXTRA_SATELLITE_SRT", pendingSatelliteSrt)
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
