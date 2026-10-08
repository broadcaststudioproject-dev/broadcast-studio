package com.kingjvk.pocket_pcr

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.kingjvk.pocket_pcr/stream"
    private val SCREEN_RECORD_REQUEST_CODE = 1001
    
    private var currentCableRtmp: String? = null
    private var currentSatSrt: String? = null

    private lateinit var mediaProjectionManager: MediaProjectionManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenCaptureStreaming" -> {
                    currentCableRtmp = call.argument<String>("cableRtmp")
                    currentSatSrt = call.argument<String>("satelliteSrt")

                    val activeStreamUrl = if (!currentCableRtmp.isNullOrEmpty()) currentCableRtmp else currentSatSrt

                    if (activeStreamUrl.isNullOrEmpty()) {
                        result.error("INVALID_URL", "RTMP URL is missing", null)
                        return@setMethodCallHandler
                    }

                    // మొబైల్ మెయిన్ థ్రెడ్ మీద పాపప్ ఫోర్స్ చేయడం
                    runOnUiThread {
                        try {
                            val captureIntent = mediaProjectionManager.createScreenCaptureIntent()
                            startActivityForResult(captureIntent, SCREEN_RECORD_REQUEST_CODE)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("PROJECTION_ERROR", "Cannot start screen capture", null)
                        }
                    }
                }
                "stopScreenCaptureStreaming" -> {
                    runOnUiThread {
                        // బ్యాక్‌గ్రౌండ్ సర్వీస్‌ను ఆపేయడం
                        val serviceIntent = Intent(this, ScreenStreamService::class.java)
                        stopService(serviceIntent)
                        Toast.makeText(this, "Live Broadcast Stopped!", Toast.LENGTH_SHORT).show()
                    }
                    result.success(true)
                }
                "pauseScreenCaptureStreaming" -> {
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // యూజర్ 'Start Now' నొక్కిన వెంటనే ఆండ్రాయిడ్ ఈ ఫంక్షన్ రన్ చేస్తుంది
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                Toast.makeText(this, "స్క్రీన్ రికార్డింగ్ మొదలైంది! (Background Service స్టార్ట్ అవుతోంది...)", Toast.LENGTH_LONG).show()

                val targetUrl = if (!currentCableRtmp.isNullOrEmpty()) currentCableRtmp else currentSatSrt

                // డేటాను ScreenStreamService కి పంపి బ్యాక్ గ్రౌండ్ లో స్టార్ట్ చేయడం
                val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
                    putExtra("resultCode", resultCode)
                    putExtra("data", data)
                    putExtra("rtmpUrl", targetUrl)
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
            } else {
                Toast.makeText(this, "స్క్రీన్ రికార్డింగ్ పర్మిషన్ ఇవ్వలేదు, కాబట్టి లైవ్ ఆగిపోయింది.", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
