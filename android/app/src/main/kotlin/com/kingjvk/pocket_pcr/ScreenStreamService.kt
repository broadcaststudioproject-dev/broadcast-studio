package com.kingjvk.pocket_pcr

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.pedro.library.rtmp.RtmpDisplay
import com.pedro.rtmp.utils.ConnectCheckerRtmp

class ScreenStreamService : Service(), ConnectCheckerRtmp {
    private var rtmpDisplay: RtmpDisplay? = null
    private val NOTIFICATION_ID = 2026
    private val CHANNEL_ID = "PocketPCR_LiveChannel"
    
    // బ్యాక్‌గ్రౌండ్ నుండి UI కు మెసేజ్‌లు పంపడానికి హ్యాండ్లర్
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        
        // ఫోన్‌ నోటిఫికేషన్ బార్‌లో లైవ్ నడుస్తున్నట్లు చూపించే నోటిఫికేషన్
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Pocket PCR Studio")
            .setContentText("స్క్రీన్ బ్యాక్‌గ్రౌండ్‌లో ప్రసారం అవుతోంది (Live On-Air)")
            .setSmallIcon(android.R.drawable.ic_media_play) 
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        
        startForeground(NOTIFICATION_ID, notification)
        
        // ఆడియోతో సహా స్క్రీన్ రికార్డ్ చేయడానికి ఎన్‌కోడర్ ఇనిషియలైజ్ 
        rtmpDisplay = RtmpDisplay(baseContext, true, this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            val resultCode = intent.getIntExtra("resultCode", -1)
            val data = intent.getParcelableExtra<Intent>("data")
            val rtmpUrl = intent.getStringExtra("rtmpUrl")

            if (resultCode != -1 && data != null && !rtmpUrl.isNullOrEmpty()) {
                rtmpDisplay?.setIntentResult(resultCode, data)
                
                // HD (720p) వీడియో మరియు ఆడియో క్వాలిటీ సెట్టింగ్స్
                if (rtmpDisplay?.prepareVideo(1280, 720, 30, 2500 * 1024, 0, 320, null) == true &&
                    rtmpDisplay?.prepareAudio(64 * 1024, 32000, true, false, false) == true) {
                    
                    // స్ట్రీమింగ్ ప్రారంభం
                    rtmpDisplay?.startStream(rtmpUrl)
                } else {
                    mainHandler.post {
                        Toast.makeText(this, "సెటప్ విఫలమైంది. మీ మొబైల్ ఈ రిజల్యూషన్ సపోర్ట్ చేయట్లేదు.", Toast.LENGTH_LONG).show()
                    }
                    stopSelf()
                }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        if (rtmpDisplay?.isStreaming == true) {
            rtmpDisplay?.stopStream()
        }
        rtmpDisplay = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // --- ConnectCheckerRtmp Callbacks (స్ట్రీమ్ స్టేటస్ తెలుసుకోవడానికి) ---
    override fun onConnectionSuccessRtmp() {
        mainHandler.post { Toast.makeText(this, "SUCCESS: మీరు లైవ్‌లో ఉన్నారు!", Toast.LENGTH_LONG).show() }
    }

    override fun onConnectionFailedRtmp(reason: String) {
        mainHandler.post { 
            Toast.makeText(this, "FAILED: లైవ్ ఫెయిల్ అయ్యింది: $reason", Toast.LENGTH_LONG).show() 
        }
        rtmpDisplay?.stopStream()
        stopSelf()
    }

    override fun onNewBitrateRtmp(bitrate: Long) { }

    override fun onDisconnectRtmp() {
        mainHandler.post { Toast.makeText(this, "లైవ్ కట్ అయ్యింది.", Toast.LENGTH_SHORT).show() }
    }

    override fun onAuthErrorRtmp() {
        mainHandler.post { Toast.makeText(this, "ఆథరైజేషన్ ఎర్రర్.", Toast.LENGTH_SHORT).show() }
    }

    override fun onAuthSuccessRtmp() { }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "PCR Live Stream", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
