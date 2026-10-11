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
            .setContentTitle("Pocket PCR Studio")
            .setContentText("లైవ్ స్క్రీన్ రికార్డింగ్ నడుస్తోంది...")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_HIGH) // ఇక్కడ హై ప్రయారిటీకి మార్చబడింది
            .setOngoing(true)
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            mainHandler.post { Toast.makeText(this, "Service Error: ${e.message}", Toast.LENGTH_LONG).show() }
        }

        rtmpDisplay = RtmpDisplay(baseContext, true, this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            val resultCode = intent.getIntExtra("resultCode", -1)
            val data = intent.getParcelableExtra<Intent>("data")
            val rtmpUrl = intent.getStringExtra("rtmpUrl")
            val enableNoiseCancellation = intent.getBooleanExtra("noiseCancellation", false)

            if (resultCode != -1 && data != null && !rtmpUrl.isNullOrEmpty()) {
                rtmpDisplay?.setIntentResult(resultCode, data)

                // ఫోన్ సైజును ఆటోమేటిక్ గా కనుక్కొనే లాజిక్
                val metrics = resources.displayMetrics
                var screenW = metrics.widthPixels
                var screenH = metrics.heightPixels
                
                // ఆండ్రాయిడ్ ఎన్‌కోడర్ క్రాష్ అవ్వకుండా ఉండటానికి సైజులను ఈవెన్ నంబర్స్ లోకి మారుస్తున్నాం
                if (screenW % 2 != 0) screenW -= 1
                if (screenH % 2 != 0) screenH -= 1

                val videoOk = rtmpDisplay?.prepareVideo(screenW, screenH, 30, 2500 * 1024, 0, metrics.densityDpi) == true
                val audioOk = rtmpDisplay?.prepareAudio(64 * 1024, 32000, true, enableNoiseCancellation, enableNoiseCancellation) == true

                if (videoOk && audioOk) {
                    rtmpDisplay?.startStream(rtmpUrl)
                } else {
                    // ఒకవేళ ఎక్కడైనా ఫెయిల్ అయితే, ఏది (వీడియోనా/ఆడియోనా) ఫెయిల్ అయిందో స్క్రీన్ మీద చూపిస్తుంది
                    mainHandler.post { Toast.makeText(this, "సెటప్ ఫెయిల్. ఎర్రర్: Video=$videoOk, Audio=$audioOk", Toast.LENGTH_LONG).show() }
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
        mainHandler.post { Toast.makeText(this, "SUCCESS: మీరు లైవ్‌లో ఉన్నారు!", Toast.LENGTH_LONG).show() }
    }

    override fun onConnectionFailedRtmp(reason: String) {
        mainHandler.post { Toast.makeText(this, "FAILED: లైవ్ ఫెయిల్ అయ్యింది: $reason", Toast.LENGTH_LONG).show() }
        rtmpDisplay?.stopStream()
        stopSelf()
    }

    override fun onNewBitrateRtmp(bitrate: Long) {}

    override fun onDisconnectRtmp() {
        mainHandler.post { Toast.makeText(this, "లైవ్ కట్ అయ్యింది.", Toast.LENGTH_SHORT).show() }
    }

    override fun onAuthErrorRtmp() {
        mainHandler.post { Toast.makeText(this, "ఆథరైజేషన్ ఎర్రర్.", Toast.LENGTH_SHORT).show() }
    }

    override fun onAuthSuccessRtmp() {}

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // ఛానెల్ ప్రయారిటీని కూడా హై కు మార్చబడింది
            val channel = NotificationChannel(CHANNEL_ID, "PCR Live Stream", NotificationManager.IMPORTANCE_HIGH)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
