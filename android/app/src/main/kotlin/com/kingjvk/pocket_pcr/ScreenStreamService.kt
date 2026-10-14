package com.kingjvk.pocket_pcr

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.pedro.common.ConnectChecker
import com.pedro.library.rtmp.RtmpDisplay

class ScreenStreamService : Service(), ConnectChecker {

    private var rtmpDisplay: RtmpDisplay? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, "PocketPCR_Channel")
            .setContentTitle("SS YATRA PCR")
            .setContentText("లైవ్ ప్రసారం అవుతోంది...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .build()
        startForeground(1, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            val resultCode = intent.getIntExtra("resultCode", -1)
            val data = intent.getParcelableExtra<Intent>("data")
            val rtmpUrl = intent.getStringExtra("rtmpUrl")

            if (resultCode != -1 && data != null && rtmpUrl != null) {
                rtmpDisplay = RtmpDisplay(baseContext, true, this)
                rtmpDisplay?.setIntentResult(resultCode, data)

                // వీడియో మరియు ఆడియో ప్రిపేర్ చేయడం
                if (rtmpDisplay?.prepareVideo() == true && rtmpDisplay?.prepareAudio() == true) {
                    rtmpDisplay?.startStream(rtmpUrl)
                }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        rtmpDisplay?.stopStream()
        rtmpDisplay = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "PocketPCR_Channel",
                "Pocket PCR Live",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    // ConnectChecker ఇంటర్ఫేస్ ఫంక్షన్స్
    override fun onConnectionStarted(url: String) {}
    override fun onConnectionSuccess() {}
    override fun onConnectionFailed(reason: String) {
        rtmpDisplay?.stopStream()
    }
    override fun onNewBitrate(bitrate: Long) {}
    override fun onDisconnect() {}
    override fun onAuthError() {}
    override fun onAuthSuccess() {}
}
