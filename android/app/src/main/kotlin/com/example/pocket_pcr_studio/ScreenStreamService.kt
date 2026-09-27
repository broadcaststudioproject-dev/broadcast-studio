package com.example.pocket_pcr_studio

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
import android.os.PowerManager
import android.util.Log
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.pedro.rtplibrary.rtmp.RtmpDisplay
import com.pedro.rtmp.utils.ConnectCheckerRtmp

class ScreenStreamService : Service(), ConnectCheckerRtmp {

    private var rtmpDisplay: RtmpDisplay? = null
    private var currentUrl: String = ""
    private var triedAltProtocol = false
    private var wakeLock: PowerManager.WakeLock? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        try {
            rtmpDisplay = RtmpDisplay(this, true, this)
            rtmpDisplay?.setReTries(8)
        } catch (e: Exception) {
            Log.e(TAG, "RtmpDisplay create failed", e)
            toast("Library error: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startNotification()

        when (intent?.action) {
            ACTION_START -> startStream(intent)
            ACTION_STOP -> stopEverything()
        }
        return START_NOT_STICKY
    }

    private fun startStream(intent: Intent) {
        val rawUrl = intent.getStringExtra(EXTRA_URL)?.trim().orEmpty()
        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)
        val data = extractResultIntent(intent)

        if (rawUrl.isEmpty() || rawUrl.contains("YOUR_STREAM_KEY")) {
            toast("Restream stream key paste చేయండి")
            return
        }
        if (data == null || resultCode != android.app.Activity.RESULT_OK) {
            toast("Screen permission data రాలేదు. Malli try చేయండి.")
            Log.e(TAG, "Missing projection data resultCode=$resultCode data=$data")
            return
        }

        currentUrl = normalizeUrl(rawUrl)
        triedAltProtocol = false
        toast("Connecting: $currentUrl")
        acquireWakeLock()

        try {
            rtmpDisplay?.setIntentResult(resultCode, data)
        } catch (e: Exception) {
            toast("Projection error: ${e.message}")
            Log.e(TAG, "setIntentResult failed", e)
            return
        }

        Thread {
            try {
                if (!prepareEncoders()) {
                    toast("Video encoder start కాలేదు")
                    return@Thread
                }
                rtmpDisplay?.startStream(currentUrl)
            } catch (e: Exception) {
                Log.e(TAG, "startStream thread failed", e)
                toast("Start crash: ${e.message}")
            }
        }.start()
    }

    private fun prepareEncoders(): Boolean {
        val dpi = resources.displayMetrics.densityDpi.coerceAtLeast(160)
        val sizes = arrayOf(
            intArrayOf(720, 1280, 30, 1_800_000),
            intArrayOf(1280, 720, 30, 1_800_000),
            intArrayOf(720, 1280, 25, 1_200_000),
            intArrayOf(640, 1136, 25, 1_000_000),
            intArrayOf(640, 480, 25, 800_000)
        )

        var videoOk = false
        for (s in sizes) {
            try {
                if (rtmpDisplay?.prepareVideo(s[0], s[1], s[2], s[3], 0, dpi) == true) {
                    videoOk = true
                    Log.i(TAG, "Video prepared \( {s[0]}x \){s[1]} @${s[2]}")
                    break
                }
            } catch (e: Exception) {
                Log.w(TAG, "prepareVideo \( {s[0]}x \){s[1]} failed", e)
            }
        }
        if (!videoOk) {
            try {
                videoOk = rtmpDisplay?.prepareVideo() == true
            } catch (e: Exception) {
                Log.e(TAG, "prepareVideo default failed", e)
            }
        }
        if (!videoOk) return false

        var audioOk = false
        try {
            audioOk = rtmpDisplay?.prepareAudio(44100, true, 128 * 1024) == true
        } catch (e: Exception) {
            Log.w(TAG, "prepareAudio custom failed", e)
        }
        if (!audioOk) {
            try {
                audioOk = rtmpDisplay?.prepareAudio() == true
            } catch (e: Exception) {
                Log.w(TAG, "prepareAudio default failed", e)
            }
        }
        if (!audioOk) {
            toast("Mic prepare fail — video only")
        }
        return true
    }

    private fun normalizeUrl(url: String): String {
        var u = url.trim()
        if (!u.contains("://")) {
            u = "rtmp://live.restream.io/live/$u"
        }
        return u
    }

    private fun alternateUrl(url: String): String? {
        return when {
            url.startsWith("rtmps://") -> "rtmp://" + url.removePrefix("rtmps://")
            url.startsWith("rtmp://") -> "rtmps://" + url.removePrefix("rtmp://")
            else -> null
        }
    }

    private fun extractResultIntent(intent: Intent): Intent? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(EXTRA_DATA)
            }
        } catch (e: Exception) {
            Log.e(TAG, "extractResultIntent", e)
            null
        }
    }

    private fun startNotification() {
        val channelId = "ScreenStreamChannel"
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
            .setContentText("Live streaming…")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    1,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
            } else {
                startForeground(1, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            try {
                startForeground(1, notification)
            } catch (e2: Exception) {
                toast("Notification block: ${e2.message}")
            }
        }
    }

    private fun stopEverything() {
        try {
            rtmpDisplay?.stopStream()
        } catch (_: Exception) {
        }
        releaseWakeLock()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock?.isHeld == true) return
            wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "pcr:stream")
            wakeLock?.setReferenceCounted(false)
            wakeLock?.acquire(4 * 60 * 60 * 1000L)
        } catch (e: Exception) {
            Log.w(TAG, "wakeLock", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
    }

    private fun toast(message: String) {
        Log.i(TAG, message)
        mainHandler.post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_LONG).show()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopEverything()
        super.onDestroy()
    }

    override fun onConnectionStartedRtmp(rtmpUrl: String) {
        toast("Restream కి connect అవుతోంది…")
    }

    override fun onConnectionSuccessRtmp() {
        toast("Restream ONLINE ✅")
    }

    override fun onConnectionFailedRtmp(reason: String) {
        Log.e(TAG, "onConnectionFailedRtmp $reason")
        try {
            if (rtmpDisplay?.shouldRetry(reason) == true) {
                toast("Retry: $reason")
                rtmpDisplay?.reTry(4000, reason)
                return
            }
        } catch (e: Exception) {
            Log.w(TAG, "shouldRetry", e)
        }

        val alt = alternateUrl(currentUrl)
        if (!triedAltProtocol && alt != null) {
            triedAltProtocol = true
            toast("Protocol change: $alt")
            try {
                rtmpDisplay?.stopStream()
            } catch (_: Exception) {
            }
            currentUrl = alt
            mainHandler.postDelayed({
                try {
                    rtmpDisplay?.startStream(currentUrl)
                } catch (e: Exception) {
                    toast("Alt start fail: ${e.message}")
                }
            }, 1200)
            return
        }
        toast("Restream fail: $reason")
    }

    override fun onNewBitrateRtmp(bitrate: Long) {}

    override fun onDisconnectRtmp() {
        toast("Restream disconnect")
    }

    override fun onAuthErrorRtmp() {
        toast("Stream key తప్పు (auth error)")
    }

    override fun onAuthSuccessRtmp() {}

    companion object {
        private const val TAG = "PCRStream"
        const val ACTION_START = "START_STREAM"
        const val ACTION_STOP = "STOP_STREAM"
        const val EXTRA_URL = "url"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"
    }
}
