package com.example.pocket_pcr_studio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import androidx.core.app.NotificationCompat

// పాత rtplibrary:2.2.2 కి సంబంధించిన కరెక్ట్ ఇంపోర్ట్స్
import com.pedro.rtplibrary.rtmp.RtmpDisplay
import com.pedro.rtmp.utils.ConnectCheckerRtmp

class ScreenStreamService : Service(), ConnectCheckerRtmp {

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
                            // ఫోన్ అడ్డంగా ఉందా నిలువుగా ఉందా చెక్ చేయడం
                            val isPortrait = resources.configuration.orientation == Configuration.ORIENTATION_PORTRAIT
                            val width = if (isPortrait) 720 else 1280
                            val height = if (isPortrait) 1280 else 720
                            val fps = 30
                            val bitrate = 2500 * 1024 // 2.5 Mbps
                            val rotation = 0
                            val dpi = 320
                            
                            // భారీ స్క్రీన్ సైజుని HD రిజల్యూషన్ కి మారుస్తున్నాం
                            if (display.prepareVideo(width, height, fps, bitrate, rotation, dpi) && display.prepareAudio()) {
                                display.startStream(url)
                                showMessage("⏳ లైవ్ సర్వర్ కి వెళ్తోంది...")
                            } else {
                                showMessage("❌ ఆడియో/వీడియో ఎన్‌కోడర్ ఫెయిల్.")
                            }
                        } catch (e: Exception) {
                            showMessage("❌ ఎర్రర్: ${e.message}")
                        }
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

    override fun onConnectionStartedRtmp(rtmpUrl: String) {}
    
    override fun onConnectionSuccessRtmp() {
        showMessage("✅ కనెక్ట్ అయ్యింది! Restream ఆన్‌లైన్ చూసుకోండి.")
    }
    
    override fun onConnectionFailedRtmp(reason: String) {
        showMessage("❌ కనెక్షన్ ఎర్రర్: $reason")
    }
    
    override fun onNewBitrateRtmp(bitrate: Long) {}
    
    override fun onDisconnectRtmp() { 
        showMessage("⚠️ కనెక్షన్ కట్ అయింది.") 
    }
    
    override fun onAuthErrorRtmp() { 
        showMessage("❌ RTMPS కీ తప్పుగా ఉంది.") 
    }
    
    override fun onAuthSuccessRtmp() {}
}
