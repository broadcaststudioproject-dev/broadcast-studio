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
        private const val EXTRA_RESULT_CODE = "resultCode"
        private const val EXTRA_DATA = "data"
        private const val EXTRA_RTMP_URL = "rtmpUrl"
        private const val EXTRA_RTMPS_URL = "rtmpsUrl"
        private const val EXTRA_SRT_URL = "srtUrl"
        // నాయిస్ క్యాన్సిలేషన్ కోసం కీ యాడ్ చేసాము
        private const val EXTRA_NOISE_CANCELLATION = "noiseCancellation"
    }

    private lateinit var mediaProjectionManager: MediaProjectionManager
    private var currentCableRtmp: String? = null
    private var currentCableRtmps: String? = null
    private var currentSatSrt: String? = null
    private var isNoiseCancelEnabled: Boolean = false // కొత్త వేరియబుల్
    private var pendingResult: MethodChannel.Result? = null
    private var screenCaptureRequestInProgress = false

    private val screenCaptureLauncher = registerForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.StartActivityForResult()
    ) { activityResult ->
        screenCaptureRequestInProgress = false
        val callbackResult = pendingResult
        pendingResult = null

        if (activityResult.resultCode != Activity.RESULT_OK || activityResult.data == null) {
            Toast.makeText(this, "స్క్రీన్ రికార్డింగ్ అనుమతి ఇవ్వలేదు", Toast.LENGTH_SHORT).show()
            callbackResult?.error("DENIED", "User denied screen capture permission", null)
            return@registerForActivityResult
        }

        val rtmpUrl = if (!currentCableRtmp.isNullOrBlank()) currentCableRtmp else currentCableRtmps
        if (rtmpUrl.isNullOrBlank()) {
            callbackResult?.error("INVALID_URL", "Streaming URL is missing", null)
            return@registerForActivityResult
        }

        try {
            val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
                putExtra(EXTRA_RESULT_CODE, activityResult.resultCode)
                putExtra(EXTRA_DATA, activityResult.data)
                putExtra(EXTRA_RTMP_URL, rtmpUrl)
                putExtra(EXTRA_RTMPS_URL, currentCableRtmps ?: "")
                putExtra(EXTRA_SRT_URL, currentSatSrt ?: "")
                // ఇక్కడ సర్వీస్‌కి నాయిస్ క్యాన్సిలేషన్ డేటా పంపుతున్నాం
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenCaptureStreaming" -> {
                    if (screenCaptureRequestInProgress || pendingResult != null) {
                        result.error("REQUEST_IN_PROGRESS", "A request is already in progress", null)
                        return@setMethodCallHandler
                    }

                    currentCableRtmp = call.argument<String>("cableRtmp")?.trim()
                    currentCableRtmps = call.argument<String>("cableRtmps")?.trim()
                    currentSatSrt = call.argument<String>("satelliteSrt")?.trim()
                    // ఫ్లట్టర్ నుండి నాయిస్ క్యాన్సిలేషన్ డేటా రిసీవ్ చేసుకుంటున్నాం
                    isNoiseCancelEnabled = call.argument<Boolean>("noiseCancellation") ?: false

                    if (currentCableRtmp.isNullOrBlank() && currentCableRtmps.isNullOrBlank() && currentSatSrt.isNullOrBlank()) {
                        result.error("INVALID_URL", "Streaming URLs are missing", null)
                        return@setMethodCallHandler
                    }

                    pendingResult = result
                    screenCaptureRequestInProgress = true

                    try {
                        val captureIntent = mediaProjectionManager.createScreenCaptureIntent()
                        screenCaptureLauncher.launch(captureIntent)
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

    override fun onDestroy() {
        pendingResult?.error("ACTIVITY_DESTROYED", "Activity was destroyed", null)
        pendingResult = null
        screenCaptureRequestInProgress = false
        super.onDestroy()
    }
}
