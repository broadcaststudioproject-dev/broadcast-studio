package com.kingjvk.pocket_pcr

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.pedro.library.rtmp.RtmpDisplay
import com.pedro.rtmp.utils.ConnectCheckerRtmp

class ScreenStreamService : Service(), ConnectCheckerRtmp {

    private var rtmpDisplay: RtmpDisplay? = null
    private val channelId = "PocketPCRLiveChannel"
    private val notificationId = 12345

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        // RTMP Display (Screen + Audio రికార్డింగ్ కోసం)
        rtmpDisplay = RtmpDisplay(applicationContext, true, this)
        rtmpDisplay?.glInterface?.setForceRender(true)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i("ScreenStreamService", "Service Started")
        
        // 🔴 Android 14 (API 34+) సపోర్ట్ కోసం Foreground Service Type యాడ్ చేసాం
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(notificationId, createNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(notificationId, createNotification())
        }

        if (intent != null) {
            val resultCode = intent.getIntExtra("resultCode", -1)
            val data = intent.getParcelableExtra<Intent>("data")
            
            // UI నుండి వచ్చిన లింకులను తీసుకుంటున్నాం
            val cableRtmp = intent.getStringExtra("cableRtmp")
            val restreamRtmp = intent.getStringExtra("restreamRtmp")
            val rtmpUrl = intent.getStringExtra("rtmpUrl")
            
            // ఏదైనా ఒక యాక్టివ్ లింక్ ని తీసుకుంటుంది (Restream వాడితే అన్ని ఛానెల్స్ కి వెళ్తుంది)
            val finalStreamUrl = cableRtmp?.takeIf { it.isNotEmpty() } 
                ?: restreamRtmp?.takeIf { it.isNotEmpty() } 
                ?: rtmpUrl

            if (resultCode != -1 && data != null && !finalStreamUrl.isNullOrEmpty()) {
                rtmpDisplay?.setIntentResult(resultCode, data)

                // 🔴 పవర్ ఫుల్ ఫిక్స్: DPI 0 కి బదులు, సిస్టమ్ ఒరిజినల్ DPI ని తీసుకుంటున్నాం.
                val screenDpi = resources.displayMetrics.densityDpi

                // వీడియో (1080p) మరియు ఆడియో సిద్ధం చేస్తున్నాం (DPI సెట్ చేసాం)
                if (rtmpDisplay?.prepareVideo(1920, 1080, 30, 2500 * 1024, screenDpi) == true &&
                    rtmpDisplay?.prepareAudio(128 * 1024, 44100, true, true, true) == true) {
                    
                    // లైవ్ స్ట్రీమింగ్ స్టార్ట్
                    rtmpDisplay?.startStream(finalStreamUrl)
                    Log.i("ScreenStreamService", "Streaming successfully started to $finalStreamUrl")
                } else {
                    Log.e("ScreenStreamService", "Error preparing stream. Hardware encoder failed.")
                    stopSelf()
                }
            } else {
                Log.e("ScreenStreamService", "No Valid URL provided.")
                stopSelf()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i("ScreenStreamService", "Service Stopped")
        if (rtmpDisplay?.isStreaming == true) {
            rtmpDisplay?.stopStream()
        }
        rtmpDisplay = null
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null 
    }

    // --- ConnectCheckerRtmp Interfaces (స్ట్రీమ్ కనెక్షన్ స్టేటస్ కోసం) ---
    override fun onConnectionSuccessRtmp() {
        Log.i("ScreenStreamService", "Connection Success!")
    }

    override fun onConnectionFailedRtmp(reason: String) {
        Log.e("ScreenStreamService", "Connection Failed: $reason")
        rtmpDisplay?.stopStream()
        stopSelf()
    }

    override fun onNewBitrateRtmp(bitrate: Long) { }
    
    override fun onDisconnectRtmp() {
        Log.i("ScreenStreamService", "Disconnected from server")
    }

    override fun onAuthErrorRtmp() { }
    
    override fun onAuthSuccessRtmp() { }

    // --- Foreground Notification Setup ---
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, 
                "Live Stream Service", 
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("SS YATRA TV - Live")
            .setContentText("మీ స్క్రీన్ బ్రాడ్ కాస్ట్ అవుతోంది...")
            .setSmallIcon(android.R.drawable.ic_menu_camera) 
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
