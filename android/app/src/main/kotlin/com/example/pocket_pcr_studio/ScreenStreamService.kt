package com.example.pocket_pcr_studio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import androidx.core.app.NotificationCompat

// కొత్త RootEncoder కు సంబంధించిన ఇంపోర్ట్స్
import com.pedro.library.rtmp.RtmpDisplay
import com.pedro.common.ConnectChecker

class ScreenStreamService : Service(), ConnectChecker {

    private var rtmpDisplay: RtmpDisplay? = null
    private val channelId = "ScreenStreamChannel"

    private fun showMessage(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_LONG).show()
        }
    }

    override fun onCreate() {
        super.onCreate()
        try {
            rtmpDisplay = RtmpDisplay(applicationContext, true, this)
            rtmpDisplay?.setReTries(5)
        } catch (e: Exception) {}
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY
        val action = intent.action ?: return START_NOT_STICKY

        if (action == "START_STREAM") {
            val url = intent.getStringExtra("url") ?: ""
            val resultCode = intent.getIntExtra("resultCode", 0)
            val data = intent.getParcelableExtra<Intent>("data")

            if (resultCode == -1 && data != null && url.isNotEmpty()) {
                startNotification()
                
                val display = rtmpDisplay 
                if (display != null) {
                    display.setIntentResult(resultCode, data)
                    
                    Thread {
                        try {
                            if (display.prepareVideo() && display.prepareAudio()) {
                                display.startStream(url)
                                showMessage("⏳ లైవ్ సర్వర్ కి వెళ్తోంది...")
                            } else {
                                showMessage("❌ ఆడియో/వీడియో ఎన్‌కోడర్ ఫెయిల్.")
                            }
                        } catch (e: Exception) {}
                    }.start()
                }
            } else {
                showMessage("❌ లింక్ లేదా పర్మిషన్ ఫెయిల్.")
            }
        } else if (action == "STOP_STREAM") {
            try { rtmpDisplay?.stopStream() } catch (e: Exception) {}
            stopForeground(true)
            stopSelf()
            showMessage("⏹️ లైవ్ ఆపబడింది.")
        }
        return START_NOT_STICKY
    }

    private fun startNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Screen Stream", NotificationManager.IMPORTANCE_LOW)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Pocket PCR Studio")
            .setContentText("Live Streaming is Active...")
            .setSmallIcon(android.R.drawable.ic_media_play) 
            .build()
            
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(1, notification)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        try { rtmpDisplay?.stopStream() } catch (e: Exception) {}
    }

    // పాత వర్షన్ లో ఉన్న "Rtmp" అనే పదం ఇక్కడ తొలగించబడింది (RootEncoder నిబంధనల ప్రకారం)
    override fun onConnectionStarted(rtmpUrl: String) {}
    
    override fun onConnectionSuccess() {
        showMessage("✅ కనెక్ట్ అయ్యింది! Restream ఆన్‌లైన్ చూసుకోండి.")
    }
    
    override fun onConnectionFailed(reason: String) {
        showMessage("❌ కనెక్షన్ ఎర్రర్: $reason")
    }
    
    override fun onNewBitrate(bitrate: Long) {}
    
    override fun onDisconnect() { 
        showMessage("⚠️ కనెక్షన్ కట్ అయింది.") 
    }
    
    override fun onAuthError() { 
        showMessage("❌ RTMPS కీ తప్పుగా ఉంది.") 
    }
    
    override fun onAuthSuccess() {}
}
