package com.kingjvr.pocket_pcr

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.media.projection.MediaProjection
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.pedro.common.ConnectChecker
import com.pedro.library.rtmp.RtmpDisplay

class ScreenStreamService : Service(), ConnectChecker {
    private var rtmpDisplay: RtmpDisplay? = null
    private var encoderThread: HandlerThread? = null
    private val channelId = "ScreenStreamChannel"

    companion object {
        const val ACTION_START = "START_STREAM"
        const val ACTION_STOP = "STOP_STREAM"
        const val EXTRA_URL = "rtmpUrl"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"

        // MainActivity uses this callback to forward stream status to Flutter.
        var streamStatusListener: ((String) -> Unit)? = null
    }

    private fun showMessage(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_LONG).show()
            streamStatusListener?.invoke(message)
        }
    }

    override fun onCreate() {
        super.onCreate()
        try {
            rtmpDisplay = RtmpDisplay(applicationContext, true, this)
            rtmpDisplay?.streamClient?.setReTries(3)
        } catch (e: Exception) {
            showMessage("Library Crash: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        when (intent.action ?: ACTION_START) {
            ACTION_START -> startStreaming(intent)
            ACTION_STOP -> stopStreaming()
        }
        return START_NOT_STICKY
    }

    private fun startStreaming(intent: Intent) {
        startNotification()

        val url = intent.getStringExtra(EXTRA_URL) ?: ""
        val cableRtmp = intent.getStringExtra("EXTRA_CABLE_RTMP") ?: ""
        val restreamRtmp = intent.getStringExtra("EXTRA_RESTREAM_RTMP") ?: ""
        val satelliteSrt = intent.getStringExtra("EXTRA_SATELLITE_SRT") ?: ""
        // RootEncoder RtmpDisplay supports RTMP, not SRT. Prefer an RTMP target.
        val targetUrl = cableRtmp.ifEmpty { restreamRtmp.ifEmpty { url } }

        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)
        val data = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra<Intent>(EXTRA_DATA)
        }

        if (data == null || resultCode != android.app.Activity.RESULT_OK || targetUrl.isBlank() ||
            targetUrl.contains("YOUR_STREAM_KEY_HERE")) {
            showMessage("స్ట్రీమ్ లింక్ లేదా కీ సరిగ్గా లేదు. RTMP URL/కీ తనిఖీ చేయండి.")
            stopForegroundCompat()
            stopSelf()
            return
        }

        val display = rtmpDisplay
        if (display == null) {
            showMessage("స్ట్రీమ్ ఎన్‌కోడర్ ప్రారంభం కాలేదు.")
            stopForegroundCompat()
            stopSelf()
            return
        }

        try {
            // Avoid requesting the same MediaProjection token twice on Android 14+.
            display.setMediaProjectionCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    super.onStop()
                    try {
                        display.stopStream()
                    } catch (_: Exception) {
                    }
                }
            })
            display.setIntentResult(resultCode, data)
        } catch (e: Exception) {
            showMessage("MediaProjection பிழை: ${e.message}")
            stopForegroundCompat()
            stopSelf()
            return
        }

        // RootEncoder can use the current thread's Looper. HandlerThread guarantees one exists.
        encoderThread?.quitSafely()
        val thread = HandlerThread("ScreenStreamEncoder")
        encoderThread = thread
        thread.start()
        Handler(thread.looper).post {
            try {
                val isPortrait =
                    resources.configuration.orientation == Configuration.ORIENTATION_PORTRAIT
                val width = if (isPortrait) 720 else 1280
                val height = if (isPortrait) 1280 else 720
                val dpi = resources.displayMetrics.densityDpi

                val videoReady = display.prepareVideo(width, height, 30, 2000 * 1024, 0, dpi)
                val audioReady = display.prepareAudio(128 * 1024, 44100, true, false, false)

                if (videoReady && audioReady) {
                    display.startStream(targetUrl)
                    showMessage("లైవ్ సర్వర్‌కు కనెక్ట్ అవుతోంది...")
                    if (satelliteSrt.isNotBlank()) {
                        showMessage("గమనిక: SRT గమ్యస్థానం ఈ RTMP ఎన్‌కోడర్ ద్వారా ప్రసారం కాదు.")
                    }
                } else {
                    showMessage("ఎన్‌కోడర్ విఫలమైంది! Video: $videoReady, Audio: $audioReady")
                }
            } catch (e: Exception) {
                showMessage("Stream Crash: ${e.message}")
            }
        }
    }

    private fun stopStreaming() {
        try {
            rtmpDisplay?.stopStream()
        } catch (_: Exception) {
        }
        encoderThread?.quitSafely()
        encoderThread = null
        stopForegroundCompat()
        stopSelf()
        showMessage("లైవ్ ఆగిపోయింది.")
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun startNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Screen Stream",
                NotificationManager.IMPORTANCE_LOW
            )
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Pocket PCR Studio")
            .setContentText("లైవ్ బ్రాడ్‌కాస్ట్ బ్యాక్‌గ్రౌండ్‌లో నడుస్తోంది...")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                1,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(1, notification)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        encoderThread?.quitSafely()
        encoderThread = null
        try {
            rtmpDisplay?.stopStream()
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    override fun onConnectionStarted(url: String) {}

    override fun onConnectionSuccess() {
        showMessage("లైవ్ సక్సెస్! (Online)")
    }

    override fun onConnectionFailed(reason: String) {
        showMessage("కనెక్షన్ ఎర్రర్: $reason")
    }

    override fun onNewBitrate(bitrate: Long) {}

    override fun onDisconnect() {
        showMessage("లైవ్ డిస్కనెక్ట్ అయింది.")
    }

    override fun onAuthError() {
        showMessage("లైవ్ కీ ఎర్రర్.")
    }

    override fun onAuthSuccess() {}
}
