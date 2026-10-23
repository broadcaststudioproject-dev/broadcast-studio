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

                "startScreenStream",
                "startScreenCaptureStreaming" -> {

                    if (pendingResult != null) {
                        result.error(
                            "REQUEST_IN_PROGRESS",
                            "స్క్రీన్ క్యాప్చర్ అభ్యర్థన ఇప్పటికే కొనసాగుతోంది",
                            null
                        )
                        return@setMethodCallHandler
                    }

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

                        Log.i(
                            "PCR_DEBUG",
                            "Requesting screen capture permission"
                        )

                        startActivityForResult(
                            captureIntent,
                            SCREEN_RECORD_REQUEST_CODE
                        )

                    } catch (e: Exception) {
                        Log.e(
                            "PCR_DEBUG",
                            "Screen capture request failed",
                            e
                        )

                        pendingResult?.error(
                            "INTENT_ERROR",
                            e.message ?: "స్క్రీన్ క్యాప్చర్ అభ్యర్థన విఫలమైంది",
                            null
                        )

                        pendingResult = null
                    }
                }

                "stopScreenStream",
                "stopScreenCaptureStreaming" -> {
                    stopService(
                        Intent(this, ScreenStreamService::class.java)
                    )
                    result.success(true)
                }

                "pauseScreenStream",
                "pauseScreenCaptureStreaming" -> {
                    stopService(
                        Intent(this, ScreenStreamService::class.java)
                    )
                    result.success(true)
                }

                "startUsbCamera" -> {
                    result.error(
                        "NOT_IMPLEMENTED",
                        "USB కెమెరా ప్రారంభం ఇంకా అమలు కాలేదు",
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

    @Deprecated("Use Activity Result API for new implementations")
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != SCREEN_RECORD_REQUEST_CODE) {
            return
        }

        Log.i(
            "PCR_DEBUG",
            "Screen capture result=$resultCode, dataPresent=${data != null}"
        )

        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingResult?.success(false)
            pendingResult = null
            Log.w("PCR_DEBUG", "Screen capture permission denied")
            return
        }

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

            // This confirms that the service start was requested,
            // not that the streaming server has connected successfully.
            pendingResult?.success(true)

            Log.i(
                "PCR_DEBUG",
                "ScreenStreamService start requested"
            )

        } catch (e: Exception) {
            Log.e(
                "PCR_DEBUG",
                "Failed to start ScreenStreamService",
                e
            )

            pendingResult?.error(
                "SERVICE_START_FAILED",
                e.message ?: "లైవ్ సేవ ప్రారంభం కాలేదు",
                null
            )
        } finally {
            pendingResult = null
        }
    }
}
