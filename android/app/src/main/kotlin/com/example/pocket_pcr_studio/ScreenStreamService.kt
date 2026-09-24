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
        try {
            rtmpDisplay = RtmpDisplay(applicationContext, true, this)
            rtmpDisplay?.setReTries(10)
        } catch (e: Exception) {
            showMessage("❌ సర్వీస్ ఎర్రర్: \${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY
        val action = intent.action ?: return START_NOT_STICKY

        if (action == "START_STREAM") {
            val url = intent.getStringExtra("url") ?: ""
            val resultCode = intent.getIntExtra("resultCode", 0)
            val data = intent.getParcelableExtra<Intent>("data")

            if (resultCode == -1 && data != null) {
                startNotification()
                
                val display = rtmpDisplay 
                if (display != null) {
                    display.setIntentResult(resultCode, data)
                    
                    // కెమెరా ఫ్రీజ్ అవ్వకుండా బ్యాక్‌గ్రౌండ్ థ్రెడ్ వాడాం
                    Thread {
                        try {
                            // పాత లైబ్రరీకి తగ్గట్టు ఆర్గ్యుమెంట్స్ లేకుండా మార్చబడింది
                            val isVideoPrepared = display.prepareVideo() 
                            val isAudioPrepared = display.prepareAudio()

                            if (isVideoPrepared && isAudioPrepared) {
                                if (url.isNotEmpty()) {
                                    display.startStream(url)
                                    showMessage("⏳ లైవ్ సర్వర్ కి వెళ్తోంది...")
                                }
                            } else {
                                showMessage("❌ ఫోన్ ఆడియో/వీడియో సెట్టింగ్స్ ఫెయిల్ అయ్యాయి.")
                            }
                        } catch (e: Exception) {
                            showMessage("❌ లైవ్ క్రాష్: \${e.message}")
                        }
                    }.start()
                }
            }
        } else if (action == "STOP_STREAM") {
            try {
                rtmpDisplay?.stopStream()
            } catch (e: Exception) {}
            stopForeground(true)
            stopSelf()
            showMessage("⏹️ లైవ్ ఆపబడింది.")
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
        try {
            rtmpDisplay?.stopStream()
        } catch (e: Exception) {}
    }

    override fun onConnectionStartedRtmp(rtmpUrl: String) {}
    
    override fun onConnectionSuccessRtmp() {
        showMessage("✅ లైవ్ సక్సెస్! Restream ఆన్‌లైన్ చెక్ చేయండి.")
    }
    
    override fun onConnectionFailedRtmp(reason: String) {
        showMessage("❌ లైవ్ ఫెయిల్: \$reason")
    }
    
    override fun onNewBitrateRtmp(bitrate: Long) {}
    
    override fun onDisconnectRtmp() {
        showMessage("⚠️ కనెక్షన్ కట్ అయింది.")
    }
    
    override fun onAuthErrorRtmp() {
        showMessage("❌ కీ (Key) తప్పుగా ఉంది.")
    }
    
    override fun onAuthSuccessRtmp() {}
}
