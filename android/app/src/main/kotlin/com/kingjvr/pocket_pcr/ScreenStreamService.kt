package com.kingjvr.pocket_pcr

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.pedro.rtplibrary.rtmp.RtmpDisplay
import com.pedro.rtmp.utils.ConnectCheckerRtmp

class ScreenStreamService : Service(), ConnectCheckerRtmp {
    private var rtmpDisplay: RtmpDisplay? = null
    private val channelId = "ScreenStreamChannel"

    companion object {
        const val ACTION_START = "START_STREAM"
        const val ACTION_STOP = "STOP_STREAM"
        const val EXTRA_URL = "rtmpUrl" // MainActivity లో పంపుతున్న పేరు ఇదే
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"
    }

    private fun showMessage(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_LONG).show()
        }
    }

    override fun onCreate() {
        super.onCreate()
        try {
            rtmpDisplay = RtmpDisplay(applicationContext, true, this)
            rtmpDisplay?.setReTries(3)
        } catch (e: Exception) {
            showMessage("Library Crash: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY
        
        // గమనిక: MainActivity నుండి వస్తున్న action null అయితే, దాన్ని START_STREAM గానే పరిగణించాలి
        val action = intent.action ?: ACTION_START 

        if (action == ACTION_START) {
            // సర్వీస్ స్టార్ట్ అయిన వెంటనే నోటిఫికేషన్ మొదలుపెట్టాలి
            startNotification()

            val url = intent.getStringExtra(EXTRA_URL) ?: ""
            val cableRtmp = intent.getStringExtra("EXTRA_CABLE_RTMP") ?: ""
            val restreamRtmp = intent.getStringExtra("EXTRA_RESTREAM_RTMP") ?: ""
            val satelliteSrt = intent.getStringExtra("EXTRA_SATELLITE_SRT") ?: ""

            val targetUrl = if (cableRtmp.isNotEmpty()) cableRtmp else if (restreamRtmp.isNotEmpty()) restreamRtmp else if (satelliteSrt.isNotEmpty()) satelliteSrt else url

            val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)
            
            val data = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Intent>(EXTRA_DATA)
            }

            if (data != null && targetUrl.isNotEmpty() && !targetUrl.contains("YOUR_STREAM_KEY_HERE")) {
                val display = rtmpDisplay
                if (display != null) {
                    display.setIntentResult(resultCode, data)
                    Thread {
                        try {
                            val isPortrait = resources.configuration.orientation == Configuration.ORIENTATION_PORTRAIT
                            val width = if (isPortrait) 720 else 1280
                            val height = if (isPortrait) 1280 else 720

                            val fps = 30
                            val bitrate = 2000 * 1024 
                            val dpi = resources.displayMetrics.densityDpi
                            
                            val videoReady = display.prepareVideo(width, height, fps, bitrate, 0, dpi)
                            val audioReady = display.prepareAudio(128 * 1024, 44100, true, false, false)

                            if (videoReady && audioReady) {
                                display.startStream(targetUrl)
                                showMessage("లైవ్ సర్వర్‌కు కనెక్ట్ అవుతోంది...")
                            } else {
                                showMessage("ఎన్‌కోడర్ విఫలమైంది! Video: $videoReady, Audio: $audioReady")
                            }
                        } catch (e: Exception) {
                            showMessage("Stream Crash: ${e.message}")
                        }
                    }.start()
                }
            } else {
                showMessage("స్ట్రీమ్ లింక్ లేదా కీ సరిగ్గా లేదు.")
            }
        } else if (action == ACTION_STOP) {
            try { rtmpDisplay?.stopStream() } catch (e: Exception) {}
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            showMessage("లైవ్ ఆగిపోయింది.")
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
            .setContentText("లైవ్ బ్రాడ్‌కాస్ట్ బ్యాక్‌గ్రౌండ్‌లో నడుస్తోంది...")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // Android 14 (API 34) & Android 15
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
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

    override fun onConnectionSuccessRtmp() {
        showMessage("లైవ్ సక్సెస్! (Online)")
    }
    
    override fun onConnectionFailedRtmp(reason: String) {
        showMessage("కనెక్షన్ ఎర్రర్: $reason")
    }
    
    override fun onNewBitrateRtmp(bitrate: Long) {}
    
    override fun onDisconnectRtmp() { 
        showMessage("లైవ్ డిస్కనెక్ట్ అయింది.") 
    }
    
    override fun onAuthErrorRtmp() { 
        showMessage("లైవ్ కీ ఎర్రర్.") 
    }
    
    override fun onAuthSuccessRtmp() {}
    
    override fun onConnectionStartedRtmp(rtmpUrl: String) {}
}
