package com.example.pocket_pcr_studio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.pedro.rtplibrary.rtmp.RtmpDisplay
import com.pedro.common.ConnectChecker

class ScreenStreamService : Service(), ConnectChecker {

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
                
                // కంపైలేషన్ ఎర్రర్ రాకుండా లోకల్ వేరియబుల్ వాడుతున్నాం
                val display = rtmpDisplay 
                if (display != null) {
                    display.setIntentResult(resultCode, data)
                    // ఇక్కడ prepareAudio() మరియు prepareVideo() కు ఎర్రర్ రాదు
                    if (display.prepareAudio() && display.prepareVideo()) {
                        display.startStream(url)
                    }
                }
            }
        } else if (action == "STOP_STREAM") {
            // సేఫ్ కాల్ (?.) వాడుతున్నాం కాబట్టి ఇక్కడ ఎర్రర్ రాదు
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
        // ఇక్కడ మీ ఛానల్ పేరుకి తగ్గట్టు మార్చుకోవచ్చు
        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Pocket PCR Studio")
            .setContentText("Live streaming is active...")
            .setSmallIcon(android.R.drawable.ic_media_play) 
            .build()
        startForeground(1, notification)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        rtmpDisplay?.stopStream()
    }

    // ConnectChecker ఇంటర్‌ఫేస్ మెథడ్స్
    override fun onConnectionStartedRtp(rtpUrl: String) {}
    
    override fun onConnectionSuccessRtp() {}
    
    override fun onConnectionFailedRtp(reason: String) {
        // ఇక్కడ కూడా సేఫ్ కాల్ (?.) వాడాలి
        rtmpDisplay?.stopStream()
    }
    
    override fun onNewBitrateRtp(bitrate: Long) {}
    
    override fun onDisconnectRtp() {}
    
    override fun onAuthErrorRtp() {}
    
    override fun onAuthSuccessRtp() {}
}
