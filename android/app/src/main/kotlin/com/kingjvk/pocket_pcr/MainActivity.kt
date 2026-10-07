package com.kingjvk.pocket_pcr

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.kingjvk.pocket_pcr/stream"
    private val SCREEN_RECORD_REQUEST_CODE = 1001
    
    // యూట్యూబ్ / లోకల్ లింక్స్ సేవ్ చేసుకోవడానికి 
    private var currentCableRtmp: String? = null
    private var currentSatSrt: String? = null

    private lateinit var mediaProjectionManager: MediaProjectionManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // ఆండ్రాయిడ్ స్క్రీన్ రికార్డింగ్ సిస్టమ్‌ను యాక్టివేట్ చేయడం
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // ఫ్లట్టర్ నుండి వచ్చే కరెక్ట్ కమాండ్ ఇదే
                "startScreenCaptureStreaming" -> {
                    // ఫ్లట్టర్ నుండి లింక్స్ తీసుకోవడం
                    currentCableRtmp = call.argument<String>("cableRtmp")
                    currentSatSrt = call.argument<String>("satelliteSrt")

                    if (currentCableRtmp.isNullOrEmpty() && currentSatSrt.isNullOrEmpty()) {
                        result.error("INVALID_URL", "RTMP URL is missing", null)
                        return@setMethodCallHandler
                    }

                    // స్టెప్ 1: మొబైల్ స్క్రీన్ రికార్డింగ్ పర్మిషన్ అడగటం (Popup వస్తుంది)
                    try {
                        val captureIntent = mediaProjectionManager.createScreenCaptureIntent()
                        startActivityForResult(captureIntent, SCREEN_RECORD_REQUEST_CODE)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PROJECTION_ERROR", "Cannot start screen capture", null)
                    }
                }
                "stopScreenCaptureStreaming" -> {
                    // TODO: స్ట్రీమింగ్ ఆపడానికి ఇక్కడ లాజిక్ రన్ అవుతుంది
                    Toast.makeText(this, "Live Broadcast Stopped!", Toast.LENGTH_SHORT).show()
                    result.success(true)
                }
                "pauseScreenCaptureStreaming" -> {
                    Toast.makeText(this, "Live Broadcast Paused!", Toast.LENGTH_SHORT).show()
                    result.success(true)
                }
                // మీ పాత USB కెమెరా కోడ్ అలాగే ఉంచాను
                "startUsbCamera" -> {
                    try {
                        val textureRegistry = flutterEngine.renderer
                        val surfaceEntry = textureRegistry.createSurfaceTexture()
                        result.success(surfaceEntry.id())
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

    // పర్మిషన్ పాపప్‌లో యూజర్ 'Start Now' నొక్కగానే ఈ ఫంక్షన్ రన్ అవుతుంది
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                Log.d("RTMP_STREAM", "Permission Granted. Starting stream to: $currentCableRtmp")
                Toast.makeText(this, "స్క్రీన్ రికార్డింగ్ అనుమతించబడింది! YouTube కి కనెక్ట్ అవుతోంది...", Toast.LENGTH_LONG).show()

                // --------------------------------------------------------
                // ఇక్కడే ఆండ్రాయిడ్ RTMP లైబ్రరీ ద్వారా స్క్రీన్‌ను యూట్యూబ్‌కు పంపాలి
                // ఉదాహరణకి: rtmpCamera.startStream(currentCableRtmp) 
                // --------------------------------------------------------
                
            } else {
                Toast.makeText(this, "స్క్రీన్ రికార్డింగ్ పర్మిషన్ రిజెక్ట్ చేయబడింది", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
