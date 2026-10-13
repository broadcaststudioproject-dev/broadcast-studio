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
        private const val REQUEST_RESULT_CODE = "resultCode"
        private const val REQUEST_DATA = "data"
        private const val REQUEST_RTMP_URL = "rtmpUrl"
        private const val REQUEST_RECORD_AUDIO = "recordAudio"
    }

    private lateinit var projectionManager: MediaProjectionManager

    private var currentRtmpUrl: String? = null
    private var pendingResult: MethodChannel.Result? = null
    private var requestInProgress = false

    private val screenCaptureLauncher =
        registerForActivityResult(
            androidx.activity.result.contract.ActivityResultContracts.StartActivityForResult()
        ) { result ->

            requestInProgress = false

            val callback = pendingResult
            pendingResult = null

            if (result.resultCode != Activity.RESULT_OK || result.data == null) {
                callback?.error(
                    "PERMISSION_DENIED",
                    "స్క్రీన్ క్యాప్చర్ అనుమతి ఇవ్వలేదు.",
                    null
                )
                return@registerForActivityResult
            }

            val rtmpUrl = currentRtmpUrl

            if (rtmpUrl.isNullOrBlank()) {
                callback?.error(
                    "INVALID_URL",
                    "RTMP URL ఖాళీగా ఉంది.",
                    null
                )
                return@registerForActivityResult
            }

            try {
                val serviceIntent = Intent(
                    this,
                    ScreenStreamService::class.java
                ).apply {
                    putExtra(REQUEST_RESULT_CODE, result.resultCode)
                    putExtra(REQUEST_DATA, result.data)
                    putExtra(REQUEST_RTMP_URL, rtmpUrl)
                    putExtra(REQUEST_RECORD_AUDIO, true)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }

                callback?.success(true)

            } catch (e: Exception) {
                callback?.error(
                    "SERVICE_START_ERROR",
                    e.message ?: "లైవ్ సర్వీస్ ప్రారంభం కాలేదు.",
                    null
                )
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        projectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                    as MediaProjectionManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "startScreenCaptureStreaming" -> {

                    if (requestInProgress || pendingResult != null) {
                        result.error(
                            "REQUEST_IN_PROGRESS",
                            "స్క్రీన్ క్యాప్చర్ అభ్యర్థన ఇప్పటికే కొనసాగుతోంది.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val url = call.argument<String>("cableRtmp")?.trim()

                    if (url.isNullOrBlank()) {
                        result.error(
                            "INVALID_URL",
                            "YouTube RTMP URL మరియు Stream Key నమోదు చేయండి.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    currentRtmpUrl = url
                    pendingResult = result
                    requestInProgress = true

                    try {
                        val captureIntent =
                            projectionManager.createScreenCaptureIntent()

                        screenCaptureLauncher.launch(captureIntent)

                    } catch (e: Exception) {
                        requestInProgress = false
                        pendingResult = null

                        result.error(
                            "PROJECTION_ERROR",
                            e.message ?: "స్క్రీన్ క్యాప్చర్ అనుమతి అడగలేకపోయింది.",
                            null
                        )
                    }
                }

                "stopScreenCaptureStreaming" -> {
                    try {
                        stopService(
                            Intent(this, ScreenStreamService::class.java)
                        )
                        result.success(true)

                    } catch (e: Exception) {
                        result.error(
                            "STOP_ERROR",
                            e.message ?: "లైవ్ ఆపలేకపోయింది.",
                            null
                        )
                    }
                }

                "startUsbCamera" -> {
                    result.error(
                        "NOT_IMPLEMENTED",
                        "USB కెమెరా కోసం ప్రత్యేక అమలు అవసరం.",
                        null
                    )
                }

                "stopUsbCamera" -> {
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        pendingResult?.error(
            "ACTIVITY_DESTROYED",
            "యాప్ Activity మూసివేయబడింది.",
            null
        )

        pendingResult = null
        requestInProgress = false

        super.onDestroy()
    }
}
