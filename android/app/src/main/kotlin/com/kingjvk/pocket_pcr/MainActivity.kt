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
    // ఎగ్జాక్ట్‌గా అక్టోబర్ 4 నాటి ఛానల్ పేరు ఇక్కడ వాడాము!
    private val CHANNEL = "com.kingjvk.pocket_pcr/stream"
    private val SCREEN_RECORD_REQUEST_CODE = 1001
    
    private var currentCableRtmp: String? = null

    private lateinit var mediaProjectionManager: MediaProjectionManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Toast.makeText(this, "✅ Pocket PCR Engine Started!", Toast.LENGTH_LONG).show()
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenStream" -> {
                    currentCableRtmp = call.argument<String>("rtmpUrl")

                    if (currentCableRtmp.isNullOrEmpty()) {
                        result.error("INVALID_URL", "Streaming URL is missing", null)
                        return@setMethodCallHandler
                    }

                    try {
                        // ఈ కోడే మీకు 'Entire Screen' పాపప్ తెస్తుంది!
                        val captureIntent = mediaProjectionManager.createScreenCaptureIntent()
                        startActivityForResult(captureIntent, SCREEN_RECORD_REQUEST_CODE)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PROJECTION_ERROR", e.message ?: "Cannot start screen capture", null)
                    }
                }
                "stopScreenStream" -> {
                    val serviceIntent = Intent(this, ScreenStreamService::class.java)
                    stopService(serviceIntent)
                    Toast.makeText(this, "Live Broadcast Stopped!", Toast.LENGTH_SHORT).show()
                    result.success(true)
                }
                "startUsbCamera" -> {
                    try {
                        val textureRegistry = flutterEngine.renderer
                        val surfaceEntry = textureRegistry.createSurfaceTexture()
                        result.success(surfaceEntry.id().toInt()) 
                    } catch (e: Exception) {
                        result.error("UVC_ERROR", "OTG Permission denied", null)
                    }
                }
                "stopUsbCamera" -> {
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                Toast.makeText(this, "లైవ్‌కి కనెక్ట్ అవుతోంది...", Toast.LENGTH_LONG).show()

                val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
                    putExtra("resultCode", resultCode)
                    putExtra("data", data)
                    putExtra("rtmpUrl", currentCableRtmp)
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
            } else {
                Toast.makeText(this, "స్క్రీన్ రికార్డింగ్ పర్మిషన్ రిజెక్ట్ చేయబడింది", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
