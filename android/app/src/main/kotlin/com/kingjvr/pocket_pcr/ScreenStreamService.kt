Package com.kingjvr.pocket_pcr

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
import android.util.Log
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.pedro.library.rtmp.RtmpDisplay
import com.pedro.rtmp.utils.ConnectCheckerRtmp

class ScreenStreamService : Service(), ConnectCheckerRtmp {

    private val channelId = "PocketPCRLiveChannel"
    private val notificationId = 12345

    private var rtmpDisplay: RtmpDisplay? = null
    private var streamWidth = 0
    private var streamHeight = 0
    private var started = false

    private fun showToast(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(
                applicationContext,
                message,
                Toast.LENGTH_LONG
            ).show()
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()

        rtmpDisplay = RtmpDisplay(applicationContext, true, this)
        rtmpDisplay?.glInterface?.setForceRender(true)
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {
        if (started) {
            Log.w("PCR_RTMP", "Stream service already started")
            return START_NOT_STICKY
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                notificationId,
                createNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(notificationId, createNotification())
        }

        if (intent == null) {
            fail("Service intent లేదు")
            return START_NOT_STICKY
        }

        val resultCode = intent.getIntExtra("resultCode", -1)

        @Suppress("DEPRECATION")
        val data = intent.getParcelableExtra<Intent>("data")

        val cableUrl = intent.getStringExtra("cableRtmp")?.trim().orEmpty()
        val restreamUrl = intent.getStringExtra("restreamRtmp")?.trim().orEmpty()
        val fallbackUrl = intent.getStringExtra("rtmpUrl")?.trim().orEmpty()

        val outputUrl = sequenceOf(cableUrl, restreamUrl, fallbackUrl)
            .firstOrNull { it.startsWith("rtmp://") || it.startsWith("rtmps://") }
            .orEmpty()

        Log.i(
            "PCR_RTMP",
            "Permission valid=${resultCode == -1 && data != null}, " +
                "RTMP output supplied=${outputUrl.isNotBlank()}"
        )

        if (resultCode != android.app.Activity.RESULT_OK || data == null) {
            fail("స్క్రీన్ క్యాప్చర్ అనుమతి రాలేదు")
            return START_NOT_STICKY
        }

        if (outputUrl.isBlank()) {
            fail("సరైన RTMP/RTMPS స్ట్రీమ్ URL ఇవ్వండి")
            return START_NOT_STICKY
        }

        try {
            rtmpDisplay?.setIntentResult(resultCode, data)

            val metrics = resources.displayMetrics
            val dpi = metrics.densityDpi

            // 🔴 రిజల్యూషన్ మరియు బిట్‌రేట్ తగ్గించబడింది (720p & 1.5 Mbps)
            var width = 1280
            var height = 720

            if (width % 2 != 0) width--
            if (height % 2 != 0) height--

            streamWidth = width
            streamHeight = height

            val videoReady = rtmpDisplay?.prepareVideo(
                width,
                height,
                30,
                1500 * 1024, // 1.5 Mbps బిట్‌రేట్ (నెట్‌వర్క్ ఒత్తిడి తగ్గించడానికి)
                dpi
            ) == true

            if (!videoReady) {
                fail("వీడియో ఎన్‌కోడర్ సిద్ధం కాలేదు")
                return START_NOT_STICKY
            }

            val audioReady = rtmpDisplay?.prepareAudio(
                128 * 1024,
                44100,
                true,
                true,
                true
            ) == true

            if (!audioReady) {
                fail("ఆడియో ఎన్‌కోడర్ సిద్ధం కాలేదు")
                return START_NOT_STICKY
            }

            rtmpDisplay?.startStream(outputUrl)
            started = true

            Log.i(
                "PCR_RTMP",
                "Stream start requested: ${width}x${height}"
            )

            showToast("లైవ్ కనెక్షన్ ప్రారంభమవుతోంది...")

        } catch (e: Exception) {
            Log.e("PCR_RTMP_ERROR", "Stream start exception", e)
            fail("లైవ్ ప్రారంభించడంలో లోపం: ${e.message ?: "తెలియని లోపం"}")
        }

        return START_NOT_STICKY
    }

    private fun fail(message: String) {
        Log.e("PCR_RTMP_ERROR", message)
        showToast("❌ $message")
        stopSelf()
    }

    override fun onConnectionSuccessRtmp() {
        Log.i("PCR_RTMP", "RTMP connection succeeded")
        showToast("✅ లైవ్ కనెక్షన్ విజయవంతమైంది (${streamWidth}x${streamHeight})")
    }

    override fun onConnectionFailedRtmp(reason: String) {
        Log.e("PCR_RTMP_ERROR", "Connection failed: $reason")
        showToast("❌ RTMP కనెక్షన్ విఫలమైంది: $reason")

        Handler(Looper.getMainLooper()).post {
            stopSelf()
        }
    }

    override fun onDisconnectRtmp() {
        Log.w("PCR_RTMP", "RTMP disconnected")
        showToast("⚠️ లైవ్ కనెక్షన్ తెగిపోయింది")
    }

    override fun onAuthErrorRtmp() {
        Log.e("PCR_RTMP_ERROR", "RTMP authentication failed")
        showToast("❌ స్ట్రీమ్ కీ లేదా అనుమతి తప్పుగా ఉండవచ్చు")
    }

    override fun onAuthSuccessRtmp() {
        Log.i("PCR_RTMP", "RTMP authentication succeeded")
    }

    override fun onDestroy() {
        try {
            rtmpDisplay?.let { display ->
                if (display.isStreaming) {
                    display.stopStream()
                }
            }
        } catch (e: Exception) {
            Log.e("PCR_RTMP_ERROR", "Stop stream error", e)
        }

        rtmpDisplay = null
        started = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Live Stream Service",
                NotificationManager.IMPORTANCE_LOW
            )

            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val appName = applicationInfo
            .loadLabel(packageManager)
            .toString()

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("$appName - Live")
            .setContentText("లైవ్ ప్రసార సేవ ప్రారంభమైంది")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }
}
