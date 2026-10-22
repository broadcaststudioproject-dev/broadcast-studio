package com.kingjvk.pocket_pcr

import android.app.Notification
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
import android.util.Log
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.pedro.library.rtmp.RtmpDisplay
import com.pedro.rtmp.utils.ConnectCheckerRtmp

class ScreenStreamService : Service(), ConnectCheckerRtmp {

    private var rtmpDisplay: RtmpDisplay? = null
    private val channelId = "PocketPCRLiveChannel"
    private val notificationId = 12345
    
    // వీడియో సైజ్ చూపించడానికి
    private var streamWidth = 0
    private var streamHeight = 0

    private fun showToast(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_LONG).show()
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        rtmpDisplay = RtmpDisplay(applicationContext, true, this)
        rtmpDisplay?.glInterface?.setForceRender(true)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i("ScreenStreamService", "Service Started")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(notificationId, createNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(notificationId, createNotification())
        }

        if (intent != null) {
            val resultCode = intent.getIntExtra("resultCode", -1)
            val data = intent.getParcelableExtra<Intent>("data")
            
            val cableRtmp = intent.getStringExtra("cableRtmp")
            val restreamRtmp = intent.getStringExtra("restreamRtmp")
            val rtmpUrl = intent.getStringExtra("rtmpUrl")
            
            val finalStreamUrl = cableRtmp?.takeIf { it.isNotEmpty() } 
                ?: restreamRtmp?.takeIf { it.isNotEmpty() } 
                ?: rtmpUrl

            if (resultCode != -1 && data != null && !finalStreamUrl.isNullOrEmpty()) {
                rtmpDisplay?.setIntentResult(resultCode, data)

                val metrics = resources.displayMetrics
                
                // 🔴 పవర్ ఫుల్ ఫిక్స్: ఫోన్ స్క్రీన్ సైజును ఆటోమెటిక్‌గా తీసుకుంటున్నాం
                var width = metrics.widthPixels
                var height = metrics.heightPixels
                val screenDpi = metrics.densityDpi

                // వీడియో ఎన్‌కోడర్ కచ్చితంగా సరిసంఖ్య (Even Number) రిజల్యూషన్ మాత్రమే సపోర్ట్ చేస్తుంది
                if (width % 2 != 0) width -= 1
                if (height % 2 != 0) height -= 1
                
                streamWidth = width
                streamHeight = height

                if (rtmpDisplay?.prepareVideo(width, height, 30, 2500 * 1024, screenDpi) == true) {
                    if (rtmpDisplay?.prepareAudio(128 * 1024, 44100, true, true, true) == true) {
                        rtmpDisplay?.startStream(finalStreamUrl)
                        showToast("ఇంజిన్ స్టార్ట్ అయ్యింది... వీడియో పంపుతోంది!")
                    } else {
                        showToast("❌ ఆడియో ఎన్‌కోడర్ ఫెయిల్. మైక్ పర్మిషన్ చెక్ చేయండి.")
                        stopSelf()
                    }
                } else {
                    showToast("❌ వీడియో ఎన్‌కోడర్ ఫెయిల్. రిజల్యూషన్ ($width x $height) సపోర్ట్ చేయట్లేదు.")
                    stopSelf()
                }
            } else {
                showToast("❌ దయచేసి సరైన Live లింక్ ఇవ్వండి.")
                stopSelf()
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

    override fun onBind(intent: Intent?): IBinder? {
        return null 
    }

    override fun onConnectionSuccessRtmp() {
        showToast("✅ సక్సెస్! (${streamWidth}x${streamHeight} వీడియో వెళుతోంది)")
    }

    override fun onConnectionFailedRtmp(reason: String) {
        showToast("❌ కనెక్షన్ ఫెయిల్: $reason")
        rtmpDisplay?.stopStream()
        stopSelf()
    }

    override fun onNewBitrateRtmp(bitrate: Long) { }
    
    override fun onDisconnectRtmp() {
        showToast("⚠️ లైవ్ ఆగిపోయింది (Disconnected)")
    }

    override fun onAuthErrorRtmp() { 
        showToast("❌ లింక్ పాస్‌వర్డ్/ఆథరైజేషన్ తప్పు")
    }
    
    override fun onAuthSuccessRtmp() { }

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
        val appName = applicationContext.applicationInfo.loadLabel(applicationContext.packageManager).toString()

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("$appName - Live")
            .setContentText("లైవ్ బ్రాడ్‌కాస్ట్ అవుతోంది...")
            .setSmallIcon(android.R.drawable.ic_menu_camera) 
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
