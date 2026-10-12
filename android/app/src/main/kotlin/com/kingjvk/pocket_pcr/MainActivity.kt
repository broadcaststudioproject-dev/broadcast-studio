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
        private const val EXTRA_RECORD_AUDIO = "recordAudio"
    }

    private lateinit var mediaProjectionManager: MediaProjectionManager
    private var currentCableRtmp: String? = null
    private var isRecordAudioEnabled: Boolean = true
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

        val rtmpUrl = currentCableRtmp
        if (rtmpUrl.isNullOrBlank()) {
            callbackResult?.error("INVALID_URL", "Streaming URL is missing", null)
            return@registerForActivityResult
        }

        try {
            val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
                putExtra(EXTRA_RESULT_CODE, activityResult.resultCode)
                putExtra(EXTRA_DATA, activityResult.data)
                putExtra(EXTRA_RTMP_URL, rtmpUrl)
                putExtra(EXTRA_RECORD_AUDIO, isRecordAudioEnabled)
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
                // ఇక్కడే ఫ్లట్టర్ ఫైల్ కి మ్యాచ్ అయ్యేలా పేరు మార్చాము!
                "startScreenCaptureStreaming" -> {
                    if (screenCaptureRequestInProgress || pendingResult != null) {
                        result.error("REQUEST_IN_PROGRESS", "A request is already in progress", null)
                        return@setMethodCallHandler
                    }

                    val rtmpUrl = call.argument<String>("cableRtmp")?.trim()
                    if (rtmpUrl.isNullOrBlank()) {
                        result.error("INVALID_URL", "Streaming URL is missing", null)
                        return@setMethodCallHandler
                    }

                    currentCableRtmp = rtmpUrl
                    isRecordAudioEnabled = true
                    pendingResult = result
                    screenCaptureRequestInProgress = true

                    try {
                        Toast.makeText(this, "ఆండ్రాయిడ్ సిస్టమ్ కనెక్ట్ అయ్యింది..", Toast.LENGTH_SHORT).show()
                        
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
                "startUsbCamera" -> {
                    result.error("NOT_IMPLEMENTED", "USB Camera Native Code Required", null)
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

    override fun onDestroy() {
        pendingResult?.error("ACTIVITY_DESTROYED", "Activity was destroyed", null)
        pendingResult = null
        screenCaptureRequestInProgress = false
        super.onDestroy()
    }
}
