package com.kingjvk.pocket_pcr

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Bundle
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.pedro.rtmp.utils.ConnectCheckerRtmp
import com.pedro.library.rtmp.RtmpDisplay

class MainActivity: FlutterActivity(), ConnectCheckerRtmp {
    private val CHANNEL = "com.kingjvk.pocket_pcr/stream"
    private val SCREEN_RECORD_REQUEST_CODE = 1001
    
    private var currentCableRtmp: String? = null
    private var currentSatSrt: String? = null

    private lateinit var mediaProjectionManager: MediaProjectionManager
    private var rtmpDisplay: RtmpDisplay? = null 

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

                    if (currentCableRtmp.isNullOrEmpty()) {
                        result.error("INVALID_URL", "RTMP URL is missing", null)
                        return@setMethodCallHandler
                    }

                    // స్టెప్ 1: మొబైల్ మెయిన్ థ్రెడ్ మీద పాపప్ ఫోర్స్ చేయడం
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
                        if (rtmpDisplay?.isStreaming == true) {
                            rtmpDisplay?.stopStream()
                            Toast.makeText(this, "Live Broadcast Stopped!", Toast.LENGTH_SHORT).show()
                        }
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

    // స్టెప్ 2: యూజర్ 'Start Now' నొక్కిన వెంటనే ఆండ్రాయిడ్ ఈ ఫంక్షన్ రన్ చేస్తుంది
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                Toast.makeText(this, "స్క్రీన్ రికార్డింగ్ మొదలైంది! యూట్యూబ్‌కి కనెక్ట్ అవుతోంది...", Toast.LENGTH_LONG).show()

                // ఆండ్రాయిడ్ సిస్టమ్ ఎన్‌కోడర్ స్టార్ట్ అవుతుంది
                rtmpDisplay = RtmpDisplay(this, true, this)
                rtmpDisplay?.setIntentResult(resultCode, data)

                // HD (720p) వీడియో క్వాలిటీ సెట్టింగ్స్
                if (rtmpDisplay?.prepareVideo(1280, 720, 30, 2500 * 1024, 0, 320, null) == true &&
                    rtmpDisplay?.prepareAudio(64 * 1024, 32000, true, false, false) == true) {
                    
                    // యూట్యూబ్‌కి వీడియోను నెట్టడం స్టార్ట్
                    rtmpDisplay?.startStream(currentCableRtmp)
                } else {
                    Toast.makeText(this, "సెటప్ విఫలమైంది. మీ మొబైల్ ఈ రిజల్యూషన్ సపోర్ట్ చేయట్లేదు.", Toast.LENGTH_LONG).show()
                }
            } else {
                Toast.makeText(this, "స్క్రీన్ రికార్డింగ్ పర్మిషన్ ఇవ్వలేదు, కాబట్టి లైవ్ ఆగిపోయింది.", Toast.LENGTH_SHORT).show()
            }
        }
    }

    // --- యూట్యూబ్ కనెక్ట్ అయ్యిందో లేదో చెప్పే కంట్రోల్స్ ---
    override fun onConnectionSuccessRtmp() {
        runOnUiThread { Toast.makeText(this@MainActivity, "SUCCESS: మీరు యూట్యూబ్ లైవ్‌లో ఉన్నారు!", Toast.LENGTH_LONG).show() }
    }

    override fun onConnectionFailedRtmp(reason: String) {
        runOnUiThread {
            Toast.makeText(this@MainActivity, "FAILED: లైవ్ ఫెయిల్ అయ్యింది. లింక్ చెక్ చేయండి.", Toast.LENGTH_LONG).show()
            rtmpDisplay?.stopStream()
        }
    }

    override fun onNewBitrateRtmp(bitrate: Long) {}
    
    override fun onDisconnectRtmp() {
        runOnUiThread { Toast.makeText(this@MainActivity, "యూట్యూబ్ లైవ్ కట్ అయ్యింది.", Toast.LENGTH_SHORT).show() }
    }

    override fun onAuthErrorRtmp() {
        runOnUiThread { Toast.makeText(this@MainActivity, "యూట్యూబ్ ఆథరైజేషన్ ఎర్రర్.", Toast.LENGTH_SHORT).show() }
    }

    override fun onAuthSuccessRtmp() {}
}
