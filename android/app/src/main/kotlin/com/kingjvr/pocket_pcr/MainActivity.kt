
package com.kingjvr.pocket_pcr

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kingjvr.pocket_pcr/stream"
    private val SCREEN_RECORD_REQUEST_CODE = 1000

    private var currentRtmpUrl: String? = null
    private var cableRtmp: String? = null
    private var restreamRtmp: String? = null
    private var satelliteSrt: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenStream", "startScreenCaptureStreaming" -> {
                    currentRtmpUrl =
                        call.argument<String>("rtmpUrl")?.trim()
                    cableRtmp =
                        call.argument<String>("cableRtmp")?.trim()
                    restreamRtmp =
                        call.argument<String>("restreamRtmp")?.trim()
                    satelliteSrt =
                        call.argument<String>("satelliteSrt")?.trim()

                    pendingResult = result

                    try {
                        val projectionManager =
                            getSystemService(
                                Context.MEDIA_PROJECTION_SERVICE
                            ) as MediaProjectionManager

                        val captureIntent =
                            projectionManager.createScreenCaptureIntent()

                        // GO LIVE నుంచి అనుమతి విండో వరకు వచ్చినట్లు నిర్ధారించడానికి
                        Log.d(
                            "PCR_DEBUG",
                            "Screen capture permission requested"
                        )

                        startActivityForResult(
                            captureIntent,
                            SCREEN_RECORD_REQUEST_CODE
                        )
                    } catch (e: Exception) {
                        Log.e(
                            "PCR_DEBUG",
                            "Failed to launch screen capture permission",
                            e
                        )
                        pendingResult?.error(
                            "INTENT_ERROR",
                            e.message,
                            null
                        )
                        pendingResult = null
                    }
                }

                "stopScreenStream", "stopScreenCaptureStreaming" -> {
                    stopService(
                        Intent(this, ScreenStreamService::class.java)
                    )
                    result.success(true)
                }

                "pauseScreenStream", "pauseScreenCaptureStreaming" -> {
                    stopService(
                        Intent(this, ScreenStreamService::class.java)
                    )
                    result.success(true)
                }

                "startUsbCamera" ->
                    result.error(
                        "NOT_IMPLEMENTED",
                        "USB Not Implemented",
                        null
                    )

                "stopUsbCamera" -> result.success(true)
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Use Activity Result API for new implementations")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            Log.d(
                "PCR_DEBUG",
                "Screen capture resultCode=$resultCode, dataPresent=${data != null}"
            )

            if (resultCode == Activity.RESULT_OK && data != null) {
                val serviceIntent =
                    Intent(this, ScreenStreamService::class.java).apply {
                        putExtra("resultCode", resultCode)
                        putExtra("data", data)
                        putExtra("rtmpUrl", currentRtmpUrl)
                        putExtra("cableRtmp", cableRtmp)
                        putExtra("restreamRtmp", restreamRtmp)
                        putExtra("satelliteSrt", satelliteSrt)
                    }

                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    pendingResult?.success(true)
                } catch (e: Exception) {
                    Log.e(
                        "PCR_DEBUG",
                        "Failed to start ScreenStreamService",
                        e
                    )
                    pendingResult?.error(
                        "SERVICE_START_FAILED",
                        e.message,
                        null
                    )
                }
            } else {
                pendingResult?.success(false)
            }

            pendingResult = null
        }
    }
}
