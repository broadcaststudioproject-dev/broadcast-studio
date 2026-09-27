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
        showMessage("1️⃣ సర్వీస్ స్టార్ట్ అయ్యింది!")
        try {
            rtmpDisplay = RtmpDisplay(applicationContext, true, this)
            rtmpDisplay?.setReTries(5)
            showMessage("2️⃣ లైబ్రరీ రెడీ!")
        } catch (e: Exception) {
            showMessage("❌ లైబ్రరీ ఎర్రర్: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY
        val action = intent.action ?: return START_NOT_STICKY

        if (action == "START_STREAM") {
            val url = intent.getStringExtra("url") ?: ""
            val resultCode = intent.getIntExtra("resultCode", -1)
            val data = intent.getParcelableExtra<Intent>("data")

            if (data != null && url.isNotEmpty()) {
                try {
                    startNotification()
                } catch (e: Exception) {
                    showMessage("❌ నోటిఫికేషన్ బ్లాక్ అయింది")
                }
                
                val display = rtmpDisplay 
                if (display != null) {
                    display.setIntentResult(resultCode, data)
                    
                    Thread {
                        try {
                            val displayMetrics = resources.displayMetrics
                            var width = displayMetrics.widthPixels
                            var height = displayMetrics.heightPixels
                            
                            if (width > 1080 || height > 1920) {
                                width /= 2
                                height /= 2
                            }
                            
                            if (width % 2 != 0) width -= 1
                            if (height % 2 != 0) height -= 1

                            showMessage("3️⃣ ⚙️ సైజు: ${width}x${height}")

                            val fps = 30
                            val bitrate = 2500 * 1024
                            val rotation = 0
                            val dpi = displayMetrics.densityDpi
                            
                            if (display.prepareVideo(width, height, fps, bitrate, rotation, dpi) && display.prepareAudio()) {
                                display.startStream(url)
                                showMessage("4️⃣ ⏳ సర్వర్‌కి సిగ్నల్ వెళ్తోంది...")
                            } else {
                                showMessage("❌ ఎన్‌కోడర్ ఫెయిల్.")
                            }
                        } catch (e: Exception) {
                            showMessage("❌ త్రెడ్ క్రాష్: ${e.message}")
                        }
                    }.start()
                } else {
                    // లైబ్రరీ null అయితే ఇక్కడ మనకు కచ్చితంగా మెసేజ్ చూపిస్తుంది!
                    showMessage("❌ డిస్‌ప్లే లైబ్రరీ క్రియేట్ కాలేదు (Null).") 
                }
            } else {
                showMessage("❌ లింక్ లేదా పర్మిషన్ డేటా రాలేదు.")
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
