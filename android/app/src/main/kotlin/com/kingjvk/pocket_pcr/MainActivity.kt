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
        private const val EXTRA_NOISE_CANCELLATION = "noiseCancellation"
    }

    private lateinit var mediaProjectionManager: MediaProjectionManager

    private var currentCableRtmp: String? = null
    private var isNoiseCancellationEnabled: Boolean = false

    private var pendingResult: MethodChannel.Result? = null
    private var screenCaptureRequestInProgress = false

    /*
     * ఆధునిక Android Activity Result API.
     * వినియోగదారు Screen Capture అనుమతి ఇచ్చినప్పుడు
     * లేదా నిరాకరించినప్పుడు ఈ callback అమలవుతుంది.
     */
    private val screenCaptureLauncher =
        registerForActivityResult(
            androidx.activity.result.contract.ActivityResultContracts
                .StartActivityForResult()
        ) { activityResult ->

            screenCaptureRequestInProgress = false

            val callbackResult = pendingResult
            pendingResult = null

            if (activityResult.resultCode != Activity.RESULT_OK ||
                activityResult.data == null
            ) {
                Toast.makeText(
                    this,
                    "స్క్రీన్ రికార్డింగ్ అనుమతి ఇవ్వలేదు",
                    Toast.LENGTH_SHORT
                ).show()

                callbackResult?.error(
                    "DENIED",
                    "User denied screen capture permission",
                    null
                )
                return@registerForActivityResult
            }

            val rtmpUrl = currentCableRtmp

            if (rtmpUrl.isNullOrBlank()) {
                callbackResult?.error(
                    "INVALID_URL",
                    "Streaming URL is missing",
                    null
                )
                return@registerForActivityResult
            }

            try {
                val serviceIntent = Intent(
                    this,
                    ScreenStreamService::class.java
                ).apply {
                    putExtra(EXTRA_RESULT_CODE, activityResult.resultCode)
                    putExtra(EXTRA_DATA, activityResult.data)
                    putExtra(EXTRA_RTMP_URL, rtmpUrl)
                    putExtra(
                        EXTRA_NOISE_CANCELLATION,
                        isNoiseCancellationEnabled
                    )
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }

                Toast.makeText(
                    this,
                    "స్క్రీన్ స్ట్రీమింగ్ ప్రారంభించడానికి అభ్యర్థన పంపబడింది",
                    Toast.LENGTH_SHORT
                ).show()

                /*
                 * ఇది Service ప్రారంభించడానికి అభ్యర్థన విజయవంతంగా
                 * పంపబడిందని మాత్రమే సూచిస్తుంది.
                 * నిజమైన RTMP లైవ్ స్థితిని ScreenStreamService
                 * వేరుగా నిర్ధారించాలి.
                 */
                callbackResult?.success(true)

            } catch (e: Exception) {

                callbackResult?.error(
                    "SERVICE_START_ERROR",
                    e.message ?: "Unable to start screen streaming service",
                    null
                )
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        mediaProjectionManager =
            getSystemService(
                Context.MEDIA_PROJECTION_SERVICE
            ) as MediaProjectionManager
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "startScreenStream" -> {

                    if (screenCaptureRequestInProgress ||
                        pendingResult != null
                    ) {
                        result.error(
                            "REQUEST_IN_PROGRESS",
                            "A screen capture request is already in progress",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val rtmpUrl =
                        call.argument<String>("rtmpUrl")?.trim()

                    if (rtmpUrl.isNullOrBlank()) {
                        result.error(
                            "INVALID_URL",
                            "Streaming URL is missing",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    if (!rtmpUrl.startsWith(
                            "rtmp://",
                            ignoreCase = true
                        ) &&
                        !rtmpUrl.startsWith(
                            "rtmps://",
                            ignoreCase = true
                        )
                    ) {
                        result.error(
                            "INVALID_URL",
                            "A valid RTMP or RTMPS URL is required",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    currentCableRtmp = rtmpUrl

                    isNoiseCancellationEnabled =
                        call.argument<Boolean>("noiseCancellation")
                            ?: false

                    pendingResult = result
                    screenCaptureRequestInProgress = true

                    try {
                        val captureIntent =
                            mediaProjectionManager
                                .createScreenCaptureIntent()

                        screenCaptureLauncher.launch(captureIntent)

                    } catch (e: Exception) {

                        screenCaptureRequestInProgress = false
                        pendingResult = null

                        result.error(
                            "PROJECTION_ERROR",
                            e.message ?: "Unable to request screen capture permission",
                            null
                        )
                    }
                }

                "stopScreenStream" -> {

                    try {
                        val serviceIntent = Intent(
                            this,
                            ScreenStreamService::class.java
                        )

                        val stopped = stopService(serviceIntent)

                        Toast.makeText(
                            this,
                            if (stopped) {
                                "లైవ్ స్ట్రీమింగ్ సర్వీస్ ఆపబడింది"
                            } else {
                                "స్ట్రీమింగ్ సర్వీస్ ప్రస్తుతం నడవడం లేదు"
                            },
                            Toast.LENGTH_SHORT
                        ).show()

                        result.success(stopped)

                    } catch (e: Exception) {

                        result.error(
                            "STOP_STREAM_ERROR",
                            e.message ?: "Unable to stop streaming service",
                            null
                        )
                    }
                }

                /*
                 * ఇది Texture ID మాత్రమే ఇస్తుంది.
                 * నిజమైన USB/UVC కెమెరా యాక్సెస్ కోసం
                 * కెమెరా డివైస్ నిర్వహణ కోడ్ అవసరం.
                 */
                "startUsbCamera" -> {

                    result.error(
                        "USB_CAMERA_NOT_IMPLEMENTED",
                        "Texture creation alone does not start a USB camera. Implement UVC camera initialization first.",
                        null
                    )
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
        /*
         * Activity నాశనం అవుతున్నప్పుడు పెండింగ్‌లో ఉన్న
         * Flutter Method Channel అభ్యర్థనను ముగిస్తాం.
         *
         * ఇక్కడ ScreenStreamService ను ఆపడం లేదు.
         * దాని జీవితకాలం Service మరియు Android నియమాలపై ఆధారపడి ఉంటుంది.
         */
        pendingResult?.error(
            "ACTIVITY_DESTROYED",
            "Activity was destroyed before the screen capture request completed",
            null
        )

        pendingResult = null
        screenCaptureRequestInProgress = false

        super.onDestroy()
    }
}
