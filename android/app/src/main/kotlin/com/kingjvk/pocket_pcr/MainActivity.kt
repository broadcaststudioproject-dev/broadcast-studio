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

    companion object {
        private const val CHANNEL = "com.kingjvk.pocket_pcr/stream"
        private const val SCREEN_RECORD_REQUEST_CODE = 1000
    }

    private lateinit var projectionManager: MediaProjectionManager
    private var pendingResult: MethodChannel.Result? = null
    private var currentRtmpUrl: String? = null
    private var requestInProgress = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenCaptureStreaming" -> {
                    if (requestInProgress || pendingResult != null) {
                        result.error("REQUEST_IN_PROGRESS", "స్క్రీన్ క్యాప్చర్ అభ్యర్థన ఇప్పటికే కొనసాగుతోంది.", null)
                        return@setMethodCallHandler
                    }

                    // ఏ లింక్ ఇచ్చినా తీసుకునేలా మార్పు (Cable లేదా Restream లేదా SRT)
                    val cableRtmp = call.argument<String>("cableRtmp")?.trim() ?: ""
                    val restreamRtmp = call.argument<String>("restreamRtmp")?.trim() ?: ""
                    val satelliteSrt = call.argument<String>("satelliteSrt")?.trim() ?: ""

                    val rtmpUrl = listOf(cableRtmp, restreamRtmp, satelliteSrt).firstOrNull { it.isNotEmpty() }

                    if (rtmpUrl.isNullOrBlank()) {
                        result.error("INVALID_URL", "RTMP లింక్ ఏదీ ఇవ్వలేదు.", null)
                        return@setMethodCallHandler
                    }

                    currentRtmpUrl = rtmpUrl
                    pendingResult = result
                    requestInProgress = true

                    try {
                        val captureIntent = projectionManager.createScreenCaptureIntent()
                        // ఇక్కడే సిస్టమ్ స్క్రీన్ రికార్డింగ్ పర్మిషన్ అడుగుతుంది
                        startActivityForResult(captureIntent, SCREEN_RECORD_REQUEST_CODE)
                    } catch (e: Exception) {
                        requestInProgress = false
                        pendingResult = null
                        result.error("PROJECTION_ERROR", e.message ?: "స్క్రీన్ అనుమతి అభ్యర్థన విఫలమైంది.", null)
                    }
                }

                "stopScreenCaptureStreaming" -> {
                    try {
                        stopService(Intent(this, ScreenStreamService::class.java))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", e.message ?: "లైవ్ ఆపడం విఫలమైంది.", null)
                    }
                }

                "startUsbCamera" -> result.error("NOT_IMPLEMENTED", "USB కెమెరా అమలు చేయలేదు.", null)
                "stopUsbCamera" -> result.success(true)
                else -> result.notImplemented()
            }
        }
    }

    // పర్మిషన్ ఇచ్చిన వెంటనే లైవ్ స్టార్ట్ చేసే కోడ్ ఇది
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            val callback = pendingResult
            pendingResult = null
            requestInProgress = false

            if (resultCode != Activity.RESULT_OK || data == null) {
                callback?.error("PERMISSION_DENIED", "స్క్రీన్ క్యాప్చర్ అనుమతి ఇవ్వలేదు.", null)
                return
            }

            try {
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

                callback?.success(true)

            } catch (e: Exception) {
                callback?.error("SERVICE_START_ERROR", e.message ?: "లైవ్ సర్వీస్ ప్రారంభం కాలేదు.", null)
            }
        }
    }

    override fun onDestroy() {
        pendingResult?.error("ACTIVITY_DESTROYED", "యాప్ Activity మూసివేయబడింది.", null)
        pendingResult = null
        requestInProgress = false
        super.onDestroy()
    }
}
