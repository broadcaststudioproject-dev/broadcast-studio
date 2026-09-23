package com.example.pocket_pcr_studio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.pedro.rtplibrary.rtmp.RtmpDisplay
import com.pedro.rtmp.utils.ConnectCheckerRtmp
import java.io.File

class ScreenStreamService : Service(), ConnectCheckerRtmp {

    private var rtmpDisplay: RtmpDisplay? = null
    private val channelId = "ScreenStreamChannel"
    private var currentRecordPath: String = ""

    private fun showMessage(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_LONG).show()
        }
    }

    override fun onCreate() {
        super.onCreate()
        rtmpDisplay = RtmpDisplay(applicationContext, true, this)
        rtmpDisplay?.setReTries(10)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY
        val action = intent.action ?: return START_NOT_STICKY

        if (action == "START_STREAM") {
            val url = intent.getStringExtra("url") ?: ""
            val resultCode = intent.getIntExtra("resultCode", 0)
            val data = intent.getParcelableExtra<Intent>("data")

            // ఇక్కడే అసలు సమస్య ఉండింది! RESULT_OK అంటే ఆండ్రాయిడ్ లో -1. పాత కోడ్‌లో ఇది రివర్స్ లో ఉంది.
            if (resultCode == -1 && data != null) {
                startNotification()
                
                val display = rtmpDisplay 
                if (display != null) {
                    display.setIntentResult(resultCode, data)
                    
                    if (display.prepareAudio() && display.prepareVideo()) {
                        
                        if (url.isNotEmpty()) {
                            display.startStream(url)
                            showMessage("⏳ లైవ్ కనెక్ట్ అవుతోంది...")
                        } else {
                            showMessage("❌ లైవ్ లింక్ (URL) ఖాళీగా ఉంది!")
                        }
                        
                        try {
                            var folder = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
                            var pcrFolder = File(folder, "PocketPCR")
                            if (!pcrFolder.exists() && !pcrFolder.mkdirs()) {
                                pcrFolder = File(getExternalFilesDir(Environment.DIRECTORY_MOVIES), "PocketPCR")
                                if (!pcrFolder.exists()) pcrFolder.mkdirs()
                            }
                            
                            val file = File(pcrFolder, "PCR_Live_${System.currentTimeMillis()}.mp4")
                            val absolutePath = file.absolutePath ?: ""
                            currentRecordPath = absolutePath
                            
                            if (absolutePath.isNotEmpty()) {
                                display.startRecord(absolutePath)
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    } else {
                        showMessage("❌ ఆడియో/వీడియో సపోర్ట్ ఫెయిల్ అయింది.")
                    }
                }
            } else {
                showMessage("⚠️ స్క్రీన్ రికార్డింగ్ పర్మిషన్ ఇవ్వలేదు!")
            }
        } else if (action == "STOP_STREAM") {
            stopAndSave()
            stopForeground(true)
            stopSelf()
            showMessage("⏹️ లైవ్ ఆపబడింది.")
        }
        return START_NOT_STICKY
    }
    
    private fun stopAndSave() {
        try {
            rtmpDisplay?.stopRecord()
            rtmpDisplay?.stopStream()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        val pathToSave = currentRecordPath
        if (pathToSave.isNotEmpty()) {
            try {
                MediaScannerConnection.scanFile(baseContext, arrayOf(pathToSave), arrayOf("video/mp4"), null)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
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
        stopAndSave()
    }

    override fun onConnectionStartedRtmp(rtmpUrl: String) {}
    
    override fun onConnectionSuccessRtmp() {
        showMessage("✅ లైవ్ సక్సెస్! YouTube చెక్ చేయండి.")
    }
    
    override fun onConnectionFailedRtmp(reason: String) {
        showMessage("❌ లైవ్ ఫెయిల్: $reason")
        stopAndSave()
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
