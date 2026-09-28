package com.example.pocket_pcr_studio

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
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

    // MainActivity కి కావాల్సిన కనెక్షన్ పేర్లు ఇక్కడే డిక్లేర్ చేశాను
    companion object {
        const val ACTION_START = "START_STREAM"
        const val ACTION_STOP = "STOP_STREAM"
        const val EXTRA_URL = "url"
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
            rtmpDisplay?.setReTries(5)
        } catch (e: Exception) {
            showMessage("Library Crash: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY
        val action = intent.action

        if (action == ACTION_START) {
            val url = intent.getStringExtra(EXTRA_URL) ?: ""
            val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)
            val data = intent.getParcelableExtra<Intent>(EXTRA_DATA)

            if (data != null && url.isNotEmpty() && !url.contains("YOUR_STREAM_KEY_HERE")) {
                startNotification()
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

                            val fps = 30
                            val bitrate = 2500 * 1024
                            val dpi = displayMetrics.densityDpi
                            
                            // Boolean ఎర్రర్ లేకుండా పక్కాగా 0, dpi (రెండు నంబర్లు) ఇస్తున్నాను
                            if (display.prepareVideo(width, height, fps, bitrate, 0, dpi) && display.prepareAudio()) {
                                display.startStream(url)
                                showMessage("Live Server Connecting...")
                            } else {
                                showMessage("Encoder Failed.")
                            }
                        } catch (e: Exception) {
                            showMessage("Stream Crash: ${e.message}")
                        }
                    }.start()
                }
            } else {
                showMessage("Stream link error. Please provide valid key.")
            }
        } else if (action == ACTION_STOP) {
            try { rtmpDisplay?.stopStream() } catch (e: Exception) {}
            stopForeground(true)
            stopSelf()
            showMessage("Live Stopped.")
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

    override fun onConnectionSuccessRtmp() {
        showMessage("Connected to Restream! (Online)")
    }
    
    override fun onConnectionFailedRtmp(reason: String) {
        showMessage("Connection Error: $reason")
    }
    
    override fun onNewBitrateRtmp(bitrate: Long) {}
    override fun onDisconnectRtmp() { showMessage("Connection Disconnected.") }
    override fun onAuthErrorRtmp() { showMessage("Password or Key Error.") }
    override fun onAuthSuccessRtmp() {}
    override fun onConnectionStartedRtmp(rtmpUrl: String) {}
}
