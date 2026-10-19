package com.kingjvk.pocket_pcr

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
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
        
        // ఆండ్రాయిడ్ సిస్టమ్ సర్వీస్ కిల్ చేయకుండా నోటిఫికేషన్ (Foreground Service)
        startForeground(notificationId, createNotification())

        if (intent != null) {
            val resultCode = intent.getIntExtra("resultCode", -1)
            val data = intent.getParcelableExtra<Intent>("data")
            val rtmpUrl = intent.getStringExtra("rtmpUrl")

            if (resultCode != -1 && data != null && !rtmpUrl.isNullOrEmpty()) {
                rtmpDisplay?.setIntentResult(resultCode, data)

                // వీడియో (1080p) మరియు ఆడియో సిద్ధం చేస్తున్నాం
                if (rtmpDisplay?.prepareVideo(1920, 1080, 30, 2500 * 1024, 0) == true &&
                    rtmpDisplay?.prepareAudio(128 * 1024, 44100, true, true, true) == true) {
                    
                    // లైవ్ స్ట్రీమింగ్ స్టార్ట్
                    rtmpDisplay?.startStream(rtmpUrl)
                    Log.i("ScreenStreamService", "Streaming started to $rtmpUrl")
                } else {
                    Log.e("ScreenStreamService", "Error preparing stream")
                    stopSelf()
                }
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
        return null // We don't need bound service
    }

    // --- ConnectCheckerRtmp Interfaces (స్ట్రీమ్ కనెక్షన్ స్టేటస్ కోసం) ---
    override fun onConnectionSuccessRtmp() {
        Log.i("ScreenStreamService", "Connection Success")
    }

    override fun onConnectionFailedRtmp(reason: String) {
        Log.e("ScreenStreamService", "Connection Failed: $reason")
        rtmpDisplay?.stopStream()
        stopSelf()
    }

    override fun onNewBitrateRtmp(bitrate: Long) { }
    
    override fun onDisconnectRtmp() {
        Log.i("ScreenStreamService", "Disconnected")
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
            .setSmallIcon(android.R.drawable.ic_menu_camera) // మీరు మీ సొంత యాప్ ఐకాన్ వాడుకోవచ్చు (ఉదా: R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
