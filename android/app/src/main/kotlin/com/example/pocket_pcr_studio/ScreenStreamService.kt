package com.example.pocket_pcr_studio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.pedro.rtplibrary.rtmp.RtmpDisplay
import com.pedro.rtmp.utils.ConnectCheckerRtmp
import java.io.File

class ScreenStreamService : Service(), ConnectCheckerRtmp {

    private var rtmpDisplay: RtmpDisplay? = null
    private val channelId = "ScreenStreamChannel"

    override fun onCreate() {
        super.onCreate()
        rtmpDisplay = RtmpDisplay(baseContext, true, this)
        rtmpDisplay?.setReTries(10)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == "START_STREAM") {
            val url = intent.getStringExtra("url") ?: ""
            val resultCode = intent.getIntExtra("resultCode", -1)
            val data = intent.getParcelableExtra<Intent>("data")

            if (resultCode != -1 && data != null && url.isNotEmpty()) {
                startNotification()
                
                val display = rtmpDisplay 
                if (display != null) {
                    display.setIntentResult(resultCode, data)
                    if (display.prepareAudio() && display.prepareVideo()) {
                        // 1. లైవ్ స్టార్ట్
                        display.startStream(url)
                        
                        // 2. గ్యాలరీలో (Movies ఫోల్డర్) రికార్డింగ్ సేవ్ చేయడానికి
                        try {
                            val folder = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
                            if (!folder.exists()) {
                                folder.mkdirs()
                            }
                            // ఫైల్ పేరు ఉదాహరణకి: PCR_Live_168000000.mp4
                            val file = File(folder, "PCR_Live_${System.currentTimeMillis()}.mp4")
                            display.startRecord(file.absolutePath)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }
            }
        } else if (action == "STOP_STREAM") {
            // రికార్డింగ్ మరియు లైవ్ రెండూ ఆగిపోతాయి
            rtmpDisplay?.stopRecord()
            rtmpDisplay?.stopStream()
            stopForeground(true)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun startNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Screen Stream Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Pocket PCR Studio")
            .setContentText("🔴 Live & Recording is running...")
            .setSmallIcon(android.R.drawable.ic_media_play) 
            .build()
        startForeground(1, notification)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        rtmpDisplay?.stopRecord()
        rtmpDisplay?.stopStream()
    }

    override fun onConnectionStartedRtmp(rtmpUrl: String) {}
    override fun onConnectionSuccessRtmp() {}
    override fun onConnectionFailedRtmp(reason: String) {
        rtmpDisplay?.stopRecord()
        rtmpDisplay?.stopStream()
    }
    override fun onNewBitrateRtmp(bitrate: Long) {}
    override fun onDisconnectRtmp() {}
    override fun onAuthErrorRtmp() {}
    override fun onAuthSuccessRtmp() {}
}
