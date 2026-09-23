package com.example.pocket_pcr_studio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
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
import java.io.ఫైల్
import android.content.pm.ServiceInfo

class ScreenStreamService : Service(), ConnectCheckerRtmp {

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
                android.media.MediaScannerConnection.scanFile(baseContext, arrayOf(pathToSave), arrayOf("video/mp4"), null)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun startNotification() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                channelId,
                "Screen Stream Service",
                android.app.NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            manager.createNotificationChannel(channel)
        }
        val notification: android.app.Notification = androidx.core.app.NotificationCompat.Builder(this, channelId)
            .setContentTitle("Pocket PCR Studio")
            .setContentText("Live Streaming is Active...")
            .setSmallIcon(android.R.drawable.ic_media_play) 
            .build()
            
        // ఆండ్రాయిడ్ సెక్యూరిటీ (Media Projection) ని దాటి వీడియో పంపడానికి సరైన కోడ్
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            startForeground(1, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(1, notification)
        }
    }

    override fun onBind(intent: android.content.Intent?): android.os.IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopAndSave()
    }

    override fun onConnectionStartedRtmp(rtmpUrl: String) {}
    
    override fun onConnectionSuccessRtmp() {
        showMessage("✅ లైవ్ సక్సెస్! YouTube చెక్ చేయండి.")
    }
    
    override fun onConnectionFailedRtmp(reason: String) {
        showMessage("❌ లైవ్ ఫెయిల్: \$reason")
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
