package com.kingjvk.pocket_pcr

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.pedro.library.rtmp.RtmpDisplay
import com.pedro.rtmp.utils.ConnectCheckerRtmp

class ScreenStreamService : Service(), ConnectCheckerRtmp {

    companion object {
        private const val NOTIFICATION_ID = 2026
        private const val CHANNEL_ID = "PocketPCR_LiveChannel"

        private const val EXTRA_RESULT_CODE = "resultCode"
        private const val EXTRA_DATA = "data"
        private const val EXTRA_RTMP_URL = "rtmpUrl"
        private const val EXTRA_RECORD_AUDIO = "recordAudio"
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private var rtmpDisplay: RtmpDisplay? = null
    private var streamStarted = false

    override fun onCreate() {
        super.onCreate()

        createNotificationChannel()

        val notification = createNotification(
            "స్క్రీన్ ప్రసారం ప్రారంభమవుతోంది..."
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }

            rtmpDisplay = RtmpDisplay(
                applicationContext,
                true,
                this
            )

        } catch (e: Exception) {
            showToast("సర్వీస్ ప్రారంభ లోపం: ${e.message}")
            stopSelf()
        }
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {

        if (intent == null) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        if (streamStarted) {
            return START_NOT_STICKY
        }

        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)

        val projectionData: Intent? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(EXTRA_DATA)
            }

        val rtmpUrl = intent.getStringExtra(EXTRA_RTMP_URL)?.trim()

        val recordAudio = intent.getBooleanExtra(
            EXTRA_RECORD_AUDIO,
            true
        )

        if (resultCode != android.app.Activity.RESULT_OK ||
            projectionData == null ||
            rtmpUrl.isNullOrBlank()
        ) {
            showToast("స్క్రీన్ అనుమతి లేదా RTMP URL అందలేదు.")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        try {
            val display = rtmpDisplay

            if (display == null) {
                showToast("RTMP ఇంజిన్ ప్రారంభం కాలేదు.")
                stopSelf(startId)
                return START_NOT_STICKY
            }

            display.setIntentResult(resultCode, projectionData)

            val metrics = resources.displayMetrics

            var width = metrics.widthPixels
            var height = metrics.heightPixels

            val maxResolution = 1280
            val largestSide = maxOf(width, height)

            if (largestSide > maxResolution) {
                val scale = maxResolution.toFloat() / largestSide

                width = (width * scale).toInt()
                height = (height * scale).toInt()
            }

            if (width % 2 != 0) width--
            if (height % 2 != 0) height--

            if (width < 2 || height < 2) {
                showToast("స్క్రీన్ పరిమాణం సరైనది కాదు.")
                stopSelf(startId)
                return START_NOT_STICKY
            }

            val videoPrepared = display.prepareVideo(
                width,
                height,
                30,
                2500 * 1024,
                0,
                metrics.densityDpi
            )

            val audioPrepared = if (recordAudio) {
                display.prepareAudio(
                    64 * 1024,
                    32000,
                    true,
                    false,
                    false
                )
            } else {
                true
            }

            if (!videoPrepared || !audioPrepared) {
                showToast(
                    "వీడియో/ఆడియో సిద్ధం కాలేదు. " +
                    "Video=$videoPrepared, Audio=$audioPrepared"
                )
                stopSelf(startId)
                return START_NOT_STICKY
            }

            display.startStream(rtmpUrl)
            streamStarted = true

            updateNotification("YouTube RTMP కనెక్షన్ కోసం వేచి ఉంది...")

            return START_NOT_STICKY

        } catch (e: Exception) {
            showToast("లైవ్ ప్రారంభ లోపం: ${e.message}")
            stopSelf(startId)
            return START_NOT_STICKY
        }
    }

    override fun onConnectionSuccessRtmp() {
        updateNotification("లైవ్ ప్రసారం కనెక్ట్ అయింది.")
        showToast("YouTube RTMP కనెక్షన్ విజయవంతమైంది.")
    }

    override fun onConnectionFailedRtmp(reason: String) {
        updateNotification("కనెక్షన్ విఫలమైంది.")
        showToast("లైవ్ కనెక్ట్ కాలేదు: $reason")

        stopStreaming()
        stopSelf()
    }

    override fun onDisconnectRtmp() {
        updateNotification("లైవ్ కనెక్షన్ నిలిచిపోయింది.")
        showToast("లైవ్ కనెక్షన్ నిలిచిపోయింది.")
    }

    override fun onNewBitrateRtmp(bitrate: Long) {
        // అవసరమైతే ఇక్కడ బిట్‌రేట్‌ను చూపించవచ్చు.
    }

    override fun onAuthErrorRtmp() {
        showToast("RTMP authentication విఫలమైంది. Stream Key తనిఖీ చేయండి.")
    }

    override fun onAuthSuccessRtmp() {
        showToast("RTMP authentication విజయవంతమైంది.")
    }

    override fun onDestroy() {
        stopStreaming()
        rtmpDisplay = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }

        super.onDestroy()
    }

    private fun stopStreaming() {
        try {
            val display = rtmpDisplay

            if (display?.isStreaming == true) {
                display.stopStream()
            }
        } catch (_: Exception) {
        }

        streamStarted = false
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Pocket PCR Live",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Pocket PCR Studio live streaming status"
                setShowBadge(false)
            }

            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE)
                        as NotificationManager

            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(message: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SS YATRA TV — Pocket PCR Studio")
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(message: String) {
        mainHandler.post {
            try {
                val manager =
                    getSystemService(Context.NOTIFICATION_SERVICE)
                            as NotificationManager

                manager.notify(
                    NOTIFICATION_ID,
                    createNotification(message)
                )
            } catch (_: Exception) {
            }
        }
    }

    private fun showToast(message: String) {
        mainHandler.post {
            Toast.makeText(
                applicationContext,
                message,
                Toast.LENGTH_LONG
            ).show()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
