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
            val resultCode = intent.getIntExtra("resultCode", -1) // డీఫాల్ట్‌గా -1 తీసుకుందాం
            val data = intent.getParcelableExtra<Intent>("data")

            // resultCode చెకింగ్ తీసేసి, కేవలం data మరియు url ఉన్నాయా లేదా అని మాత్రమే చూస్తున్నాం
            if (data != null && url.isNotEmpty()) {
                startNotification()
                
                val display = rtmpDisplay 
                if (display != null) {
                    display.setIntentResult(resultCode, data)
                    
                    Thread {
                        try {
                            // ఫోన్ స్క్రీన్ సైజును డైనమిక్ గా తీసుకోవడం
                            val displayMetrics = resources.displayMetrics
                            var width = displayMetrics.widthPixels
                            var height = displayMetrics.heightPixels
                            
                            // రిజల్యూషన్ మరీ ఎక్కువగా ఉంటే, సగానికి (లేదా సరైన రేషియోకి) తగ్గించడం
                            if (width > 1080 || height > 1920) {
                                width /= 2
                                height /= 2
                            }
                            
                            // ఆండ్రాయిడ్ ఎన్‌కోడర్‌లకు width మరియు height సరిసంఖ్యలో (even numbers) ఉండాలి
                            if (width % 2 != 0) width -= 1
                            if (height % 2 != 0) height -= 1

                            // టెస్టింగ్ మెసేజ్: సైజు ఎంత తీసుకుందో స్క్రీన్ పై చూడటానికి
                            showMessage("⚙️ సైజు: ${width}x${height} తీసుకుంది...")

                            val fps = 30
                            val bitrate = 2500 * 1024
                            val rotation = 0
                            val dpi = displayMetrics.densityDpi
                            
                            if (display.prepareVideo(width, height, fps, bitrate, rotation, dpi) && display.prepareAudio()) {
                                display.startStream(url)
                                showMessage("⏳ సర్వర్‌కి సిగ్నల్ వెళ్తోంది...")
                            } else {
                                showMessage("❌ ఎన్‌కోడర్ ఫెయిల్.")
                            }
                        } catch (e: Exception) {
                            showMessage("❌ క్రాష్: ${e.message}")
                        }
                    }.start()
                }
            } else {
                showMessage("❌ లింక్ లేదా పర్మిషన్ ఫెయిల్. (Data/URL missing)")
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
