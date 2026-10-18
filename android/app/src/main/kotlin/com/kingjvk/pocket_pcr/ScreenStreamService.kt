package com.kingjvk.pocket_pcr

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
import com.pedro.common.ConnectChecker
import com.pedro.library.rtmp.RtmpDisplay

class ScreenStreamService : Service(), ConnectChecker {

    private var rtmpDisplay: RtmpDisplay? = null
    private val TAG = "ScreenStreamService"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        
        val notification = NotificationCompat.Builder(this, "PocketPCR_Channel")
            .setContentTitle("SS YATRA PCR")
            .setContentText("లైవ్ ప్రసారం అవుతోంది...")
            .setSmallIcon(android.R.drawable.ic_dialog_info) // ఇక్కడ మీ యాప్ ఐకాన్ పెట్టుకోవచ్చు (ఉదా: R.mipmap.ic_launcher)
            .build()

        // 🔴 CRITICAL FIX: Android 10 (Q) మరియు అంతకంటే పై వెర్షన్ల కోసం MEDIA_PROJECTION టైప్ తప్పనిసరి
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                1, 
                notification, 
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(1, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            val resultCode = intent.getIntExtra("resultCode", -1)
            
            // 🔴 CRITICAL FIX: Android 13+ (TIRAMISU) లో getParcelableExtra పద్ధతి మారింది
            val data: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra("data", Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra("data")
            }
            
            val rtmpUrl = intent.getStringExtra("rtmpUrl")

            if (resultCode != -1 && data != null && rtmpUrl != null) {
                rtmpDisplay = RtmpDisplay(baseContext, true, this)
                rtmpDisplay?.setIntentResult(resultCode, data)

                // వీడియో మరియు ఆడియో ప్రిపేర్ చేయడం (1280x720, 30fps డిఫాల్ట్ క్వాలిటీతో స్టెబిలిటీ కోసం)
                val videoPrepared = rtmpDisplay?.prepareVideo(1280, 720, 30, 2500 * 1024, 0) ?: rtmpDisplay?.prepareVideo() == true
                val audioPrepared = rtmpDisplay?.prepareAudio() == true

                if (videoPrepared && audioPrepared) {
                    rtmpDisplay?.startStream(rtmpUrl)
                    Log.d(TAG, "Live Stream Started to: $rtmpUrl")
                } else {
                    Log.e(TAG, "Error: Video/Audio Preparation Failed.")
                    stopSelf() // ప్రిపరేషన్ ఫెయిల్ అయితే సర్వీస్ క్లోజ్ చేయాలి
                }
            }
        }
        // క్రాష్ అయినప్పుడు ఆటోమేటిక్ గా ఫెయిల్ అయిన డేటాతో స్టార్ట్ అవ్వకుండా START_NOT_STICKY వాడుతున్నాం
        return START_NOT_STICKY 
    }

    override fun onDestroy() {
        super.onDestroy()
        if (rtmpDisplay?.isStreaming == true) {
            rtmpDisplay?.stopStream()
        }
        rtmpDisplay = null
        Log.d(TAG, "Live Stream Stopped and Service Destroyed.")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "PocketPCR_Channel",
                "Pocket PCR Live",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    // =========================================================
    // ConnectChecker ఇంటర్ఫేస్ ఫంక్షన్స్ (మెరుగైన ఎర్రర్ హ్యాండ్లింగ్)
    // =========================================================
    
    override fun onConnectionStarted(url: String) {
        Log.d(TAG, "Connection Started...")
    }

    override fun onConnectionSuccess() {
        Log.d(TAG, "Connection Success! Now Live.")
    }

    override fun onConnectionFailed(reason: String) {
        Log.e(TAG, "Connection Failed: $reason")
        rtmpDisplay?.stopStream()
        stopSelf() // సర్వర్ కి కనెక్ట్ అవ్వకపోతే సర్వీస్ బ్యాక్ గ్రౌండ్ లో రన్ అవ్వకుండా ఆపేయాలి
    }

    override fun onNewBitrate(bitrate: Long) {
        // ఇక్కడ బిట్‌రేట్ మారుతున్నప్పుడు లాగ్ చూసుకోవచ్చు
    }

    override fun onDisconnect() {
        Log.d(TAG, "Disconnected from Server")
        stopSelf()
    }

    override fun onAuthError() {
        Log.e(TAG, "RTMP Auth Error (Wrong Stream Key/Username)")
        rtmpDisplay?.stopStream()
        stopSelf()
    }

    override fun onAuthSuccess() {
        Log.d(TAG, "Auth Success")
    }
}
