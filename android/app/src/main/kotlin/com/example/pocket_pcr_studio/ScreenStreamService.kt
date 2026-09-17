package com.example.pocket_pcr_studio

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import com.pedro.library.rtmp.RtmpDisplay
import com.pedro.encoder.input.video.CameraHelper

class ScreenStreamService : Service() {
    private var rtmpDisplay: RtmpDisplay? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val resultCode = intent?.getIntExtra("RESULT_CODE", Activity.RESULT_CANCELED) ?: Activity.RESULT_CANCELED
        val data = intent?.getParcelableExtra<Intent>("DATA")
        val rtmpUrl = intent?.getStringExtra("RTMP_URL")

        createNotificationChannel()
        val notification: Notification = Notification.Builder(this, "screen_stream_channel")
            .setContentTitle("Pocket PCR Studio")
            .setContentText("లైవ్ బ్రాడ్‌కాస్ట్ రన్నింగ్‌లో ఉంది...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .build()

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            } else {
                startForeground(1, notification)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        if (resultCode == Activity.RESULT_OK && data != null && rtmpUrl != null) {
            rtmpDisplay = RtmpDisplay(baseContext, true, object : com.pedro.common.ConnectChecker {
                override fun onConnectionSuccess() {
                    // లైవ్ కనెక్ట్ అయినప్పుడు
                }
                override fun onConnectionFailed(reason: String) {
                    // కనెక్షన్ ఫెయిల్ అయినప్పుడు
                }
                override fun onDisconnect() {
                    // డిస్‌కనెక్ట్ అయినప్పుడు
                }
                override fun onAuthError() {}
                override fun onAuthSuccess() {}
            })

            if (rtmpDisplay!!.prepareAudio() && rtmpDisplay!!.prepareVideo(1280, 720, 30, 2000 * 1024, false, 0)) {
                rtmpDisplay!!.startStream(rtmpUrl)
                rtmpDisplay!!.setScreenResolution(1280, 720)
                rtmpDisplay!!.startStream(resultCode, data)
            }
        }

        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            "screen_stream_channel",
            "Screen Streaming Service",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    override fun onDestroy() {
        super.onDestroy()
        rtmpDisplay?.stopStream()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
