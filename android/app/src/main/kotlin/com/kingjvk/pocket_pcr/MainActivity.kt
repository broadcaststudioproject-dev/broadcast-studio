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

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.kingjvk.pocket_pcr/stream"
        // పాప్-అప్ కోసం వాడే పక్కా కోడ్
        private const val REQUEST_CODE_SCREEN_CAPTURE = 10001
        private const val EXTRA_RESULT_CODE = "resultCode"
        private const val EXTRA_DATA = "data"
        private const val EXTRA_RTMP_URL = "rtmpUrl"
        private const val EXTRA_RTMPS_URL = "rtmpsUrl"
        private const val EXTRA_SRT_URL = "srtUrl"
        private const val EXTRA_NOISE_CANCELLATION = "noiseCancellation"
    }

    private lateinit var mediaProjectionManager: MediaProjectionManager
    private var currentCableRtmp: String? = null
    private var currentCableRtmps: String? = null
    private var currentSatSrt: String? = null
    private var isNoiseCancelEnabled: Boolean = false
    private var pendingResult: MethodChannel.Result? = null
    private var screenCaptureRequestInProgress = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenCaptureStreaming" -> {
                    // ఫ్లట్టర్ నుండి సిగ్నల్ రాగానే ఈ మెసేజ్ వస్తుంది
                    Toast.makeText(this, "లైవ్ సిగ్నల్ అందుతోంది..", Toast.LENGTH_SHORT).show()

                    if (screenCaptureRequestInProgress || pendingResult != null) {
                        result.error("REQUEST_IN_PROGRESS", "A request is already in progress", null)
                        return@setMethodCallHandler
                    }

                    currentCableRtmp = call.argument<String>("cableRtmp")?.trim()
                    currentCableRtmps = call.argument<String>("cableRtmps")?.trim()
                    currentSatSrt = call.argument<String>("satelliteSrt")?.trim()
                    isNoiseCancelEnabled = call.argument<Boolean>("noiseCancellation") ?: false

                    if (currentCableRtmp.isNullOrBlank() && currentCableRtmps.isNullOrBlank() && currentSatSrt.isNullOrBlank()) {
                        result.error("INVALID_URL", "Streaming URLs are missing", null)
                        return@setMethodCallHandler
                    }

                    pendingResult = result
                    screenCaptureRequestInProgress = true

                    try {
                        // స్క్రీన్ రికార్డింగ్ పాప్-అప్ ని బలవంతంగా లాంచ్ చేసే పాత & స్ట్రాంగ్ పద్ధతి
                        val captureIntent = mediaProjectionManager.createScreenCaptureIntent()
                        startActivityForResult(captureIntent, REQUEST_CODE_SCREEN_CAPTURE)
                    } catch (e: Exception) {
                        screenCaptureRequestInProgress = false
                        pendingResult = null
                        result.error("PROJECTION_ERROR", e.message ?: "Cannot request screen capture", null)
                    }
                }
                "stopScreenCaptureStreaming" -> {
                    try {
                        val serviceIntent = Intent(this, ScreenStreamService::class.java)
                        stopService(serviceIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", e.message, null)
                    }
                }
                "startUsbCamera" -> { result.error("NOT_IMPLEMENTED", "USB Camera Native Code Required", null) }
                "stopUsbCamera" -> { result.success(true) }
                else -> { result.notImplemented() }
            }
        }
    }

    // "Start Now" నొక్కిన వెంటనే ఈ బ్లాక్ రన్ అవుతుంది (ఇది ఎప్పటికీ ఫెయిల్ అవ్వదు)
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_SCREEN_CAPTURE) {
            screenCaptureRequestInProgress = false
            val callbackResult = pendingResult
            pendingResult = null

            if (resultCode != Activity.RESULT_OK || data == null) {
                Toast.makeText(this, "స్క్రీన్ రికార్డింగ్ అనుమతి ఇవ్వలేదు", Toast.LENGTH_SHORT).show()
                callbackResult?.error("DENIED", "User denied screen capture permission", null)
                return
            }

            val rtmpUrl = if (!currentCableRtmp.isNullOrBlank()) currentCableRtmp else currentCableRtmps
            
            try {
                val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
                    putExtra(EXTRA_RESULT_CODE, resultCode)
                    putExtra(EXTRA_DATA, data)
                    putExtra(EXTRA_RTMP_URL, rtmpUrl)
                    putExtra(EXTRA_RTMPS_URL, currentCableRtmps ?: "")
                    putExtra(EXTRA_SRT_URL, currentSatSrt ?: "")
                    putExtra(EXTRA_NOISE_CANCELLATION, isNoiseCancelEnabled)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }

                callbackResult?.success(true)
            } catch (e: Exception) {
                callbackResult?.error("SERVICE_START_ERROR", e.message ?: "Unable to start streaming", null)
            }
        }
    }

    override fun onDestroy() {
        pendingResult?.error("ACTIVITY_DESTROYED", "Activity was destroyed", null)
        pendingResult = null
        screenCaptureRequestInProgress = false
        super.onDestroy()
    }
}
