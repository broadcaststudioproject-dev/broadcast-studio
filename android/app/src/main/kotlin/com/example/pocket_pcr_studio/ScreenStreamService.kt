package com.example.pocket_pcr_studio

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.pedro.rtplibrary.rtmp.RtmpDisplay
import com.pedro.rtmp.utils.ConnectCheckerRtmp

class ScreenStreamService : Service(), ConnectCheckerRtmp {

    private var rtmpDisplay: RtmpDisplay? = null

    override fun onCreate() {
        super.onCreate()
        rtmpDisplay = RtmpDisplay(applicationContext, true, this)
        rtmpDisplay?.setReTries(5)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "START_STREAM") {
            val url = intent.getStringExtra("url") ?: ""
            val resultCode = intent.getIntExtra("resultCode", -1)
            val data = intent.getParcelableExtra<Intent>("data")

            if (data != null && url.isNotEmpty()) {
                startNotification()
                
                rtmpDisplay?.setIntentResult(resultCode, data)
                
                // ఇక్కడే అసలు మ్యాజిక్: ఫోన్ సైజుతో సంబంధం లేకుండా 
                // Restream అంగీకరించే స్టాండర్డ్ HD (720p) కి ఫిక్స్ చేస్తున్నాం
                val width = 720
                val height = 1280
                val fps = 30
                val bitrate = 2500 * 1024 // 2.5 Mbps మంచి క్వాలిటీ కోసం
                val dpi = 320
                
                Thread {
                    if (rtmpDisplay?.prepareVideo(width, height, fps, bitrate, 0, dpi) == true && rtmpDisplay?.prepareAudio() == true) {
                        rtmpDisplay?.startStream(url)
                    }
                }.start()
            }
        } else if (intent?.action == "STOP_STREAM") {
            rtmpDisplay?.stopStream()
            stopForeground(true)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun startNotification() {
        val channelId = "ScreenStreamChannel"
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
        rtmpDisplay?.stopStream()
    }
    
    // Restream కి సిగ్నల్ వెళ్లడానికి కావాల్సిన ఫంక్షన్స్
    override fun onConnectionSuccessRtmp() {
        // సిగ్నల్ విజయవంతంగా Restream కి చేరింది!
    }
    
    override fun onConnectionFailedRtmp(reason: String) {}
    override fun onNewBitrateRtmp(bitrate: Long) {}
    override fun onDisconnectRtmp() {}
    override fun onAuthErrorRtmp() {}
    override fun onAuthSuccessRtmp() {}
    override fun onConnectionStartedRtmp(rtmpUrl: String) {}
}
