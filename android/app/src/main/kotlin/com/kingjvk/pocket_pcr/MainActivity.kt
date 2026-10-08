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
// --- RTMP లైబ్రరీలు ---
import com.pedro.rtmp.utils.ConnectCheckerRtmp
import com.pedro.library.rtmp.RtmpDisplay

class MainActivity: FlutterActivity(), ConnectCheckerRtmp {
    private val CHANNEL = "com.kingjvk.pocket_pcr/stream"
    private val SCREEN_RECORD_REQUEST_CODE = 1001
    
    private var currentCableRtmp: String? = null
    private var currentCableRtmps: String? = null
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
                    currentCableRtmps = call.argument<String>("cableRtmps")
                    currentSatSrt = call.argument<String>("satelliteSrt")

                    // కనీసం ఏదో ఒక లింక్ ఉండాలి
                    val activeStreamUrl = if (!currentCableRtmp.isNullOrEmpty()) currentCableRtmp 
                                          else if (!currentCableRtmps.isNullOrEmpty()) currentCableRtmps 
                                          else currentSatSrt

                    if (activeStreamUrl.isNullOrEmpty()) {
                        result.error("INVALID_URL", "Streaming URL is missing", null)
                        return@setMethodCallHandler
                    }

                    // స్క్రీన్ క్యాప్చర్ పర్మిషన్ డైలాగ్
                    try {
                        val captureIntent = mediaProjectionManager.createScreenCaptureIntent()
                        startActivityForResult(captureIntent, SCREEN_RECORD_REQUEST_CODE)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PROJECTION_ERROR", "Cannot start screen capture", null)
                    }
                }
                "stopScreenCaptureStreaming" -> {
                    if (rtmpDisplay?.isStreaming == true) {
                        rtmpDisplay?.stopStream()
                        Toast.makeText(this, "Live Broadcast Stopped!", Toast.LENGTH_SHORT).show()
                    }
                    result.success(true)
                }
                "pauseScreenCaptureStreaming" -> {
                    Toast.makeText(this, "Live Broadcast Paused!", Toast.LENGTH_SHORT).show()
                    result.success(true)
                }
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                Toast.makeText(this, "లైవ్‌కి కనెక్ట్ అవుతోంది...", Toast.LENGTH_LONG).show()

                rtmpDisplay = RtmpDisplay(this, true, this)
                rtmpDisplay?.setIntentResult(resultCode, data)

                // 720p HD క్వాలిటీ సెట్టింగ్స్
                if (rtmpDisplay?.prepareVideo(1280, 720, 30, 2500 * 1024, 0, 320, null) == true &&
                    rtmpDisplay?.prepareAudio(64 * 1024, 32000, true, false, false) == true) {
                    
                    // ప్రాధాన్యత క్రమంలో లింక్ తీసుకోవడం (RTMP -> RTMPS)
                    val targetUrl = if (!currentCableRtmp.isNullOrEmpty()) currentCableRtmp 
                                    else currentCableRtmps

                    if (!targetUrl.isNullOrEmpty()) {
                        rtmpDisplay?.startStream(targetUrl)
                    }
                } else {
                    Toast.makeText(this, "ఎన్‌కోడర్ సెటప్ విఫలమైంది.", Toast.LENGTH_LONG).show()
                }
            } else {
                Toast.makeText(this, "స్క్రీన్ రికార్డింగ్ పర్మిషన్ రిజెక్ట్ చేయబడింది", Toast.LENGTH_SHORT).show()
            }
        }
    }

    override fun onConnectionSuccessRtmp() {
        runOnUiThread { Toast.makeText(this@MainActivity, "మీరు ఇప్పుడు లైవ్‌లో ఉన్నారు!", Toast.LENGTH_SHORT).show() }
    }

    override fun onConnectionFailedRtmp(reason: String) {
        runOnUiThread {
            Toast.makeText(this@MainActivity, "లైవ్ కనెక్షన్ ఫెయిల్ అయ్యింది: $reason", Toast.LENGTH_LONG).show()
            rtmpDisplay?.stopStream()
        }
    }

    override fun onNewBitrateRtmp(bitrate: Long) {}

    override fun onDisconnectRtmp() {
        runOnUiThread { Toast.makeText(this@MainActivity, "లైవ్ కట్ అయ్యింది.", Toast.LENGTH_SHORT).show() }
    }

    override fun onAuthErrorRtmp() {
        runOnUiThread { Toast.makeText(this@MainActivity, "యూట్యూబ్ ఆథరైజేషన్ ఎర్రర్.", Toast.LENGTH_SHORT).show() }
    }

    override fun onAuthSuccessRtmp() {}
}
