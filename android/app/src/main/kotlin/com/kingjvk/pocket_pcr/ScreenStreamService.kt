package com.kingjvk.pocket_pcr

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
    private var rtmpDisplay: RtmpDisplay? = null
    private val NOTIFICATION_ID = 2026
    private val CHANNEL_ID = "PocketPCR_LiveChannel"
    private lateinit var mainHandler: Handler

    override fun onCreate() {
        super.onCreate()
        mainHandler = Handler(Looper.getMainLooper())
        createNotificationChannel()

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SS YATRA TV - Live")
            .setContentText("స్క్రీన్ రికార్డింగ్ ద్వారా లైవ్ నడుస్తోంది...")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_HIGH) 
            .setOngoing(true)
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            mainHandler.post { Toast.makeText(this, "Notification Error: ${e.message}", Toast.LENGTH_LONG).show() }
        }

        rtmpDisplay = RtmpDisplay(baseContext, true, this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            val resultCode = intent.getIntExtra("resultCode", -1)
            val data = intent.getParcelableExtra<Intent>("data")
            val rtmpUrl = intent.getStringExtra("rtmpUrl")
            // నాయిస్ క్యాన్సిలేషన్ తీసుకునే లాజిక్
            val noiseCancel = intent.getBooleanExtra("noiseCancellation", false)

            if (resultCode != -1 && data != null && !rtmpUrl.isNullOrEmpty()) {
                rtmpDisplay?.setIntentResult(resultCode, data)

                // ఫోన్ ఒరిజినల్ స్క్రీన్ సైజును తీసుకోవడం (క్రాష్ అవ్వకుండా)
                val metrics = resources.displayMetrics
                var rawW = metrics.widthPixels
                var rawH = metrics.heightPixels

                var screenW = if (rawW > rawH) rawW else rawH
                var screenH = if (rawW > rawH) rawH else rawW

                val maxRes = 1280
                if (screenW > maxRes) {
                    screenH = (screenH * maxRes) / screenW
                    screenW = maxRes
                }

                if (screenW % 2 != 0) screenW -= 1
                if (screenH % 2 != 0) screenH -= 1

                val videoOk = rtmpDisplay?.prepareVideo(screenW, screenH, 30, 2500 * 1024, 0, metrics.densityDpi) == true
                // ఆడియోకి నాయిస్ క్యాన్సిలేషన్ అప్లై చేయడం
                val audioOk = rtmpDisplay?.prepareAudio(64 * 1024, 32000, true, noiseCancel, noiseCancel) == true

                if (videoOk && audioOk) {
                    rtmpDisplay?.startStream(rtmpUrl)
                } else {
                    mainHandler.post { Toast.makeText(this, "క్రాష్: Video=$videoOk, Audio=$audioOk. స్క్రీన్/ఆడియో సైజు సెట్ కాలేదు.", Toast.LENGTH_LONG).show() }
                    stopSelf()
                }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        if (rtmpDisplay?.isStreaming == true) {
            rtmpDisplay?.stopStream()
        }
        rtmpDisplay = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onConnectionSuccessRtmp() {
        mainHandler.post { Toast.makeText(this, "యూట్యూబ్ లైవ్‌ ప్రారంభమైంది!", Toast.LENGTH_LONG).show() }
    }

    override fun onConnectionFailedRtmp(reason: String) {
        mainHandler.post { Toast.makeText(this, "లైవ్ కనెక్ట్ కాలేదు: $reason", Toast.LENGTH_LONG).show() }
        rtmpDisplay?.stopStream()
        stopSelf()
    }

    override fun onNewBitrateRtmp(bitrate: Long) {}
    override fun onDisconnectRtmp() {
        mainHandler.post { Toast.makeText(this, "లైవ్ ఆగిపోయింది.", Toast.LENGTH_SHORT).show() }
    }
    override fun onAuthErrorRtmp() {}
    override fun onAuthSuccessRtmp() {}

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Pocket PCR Live", NotificationManager.IMPORTANCE_HIGH)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
