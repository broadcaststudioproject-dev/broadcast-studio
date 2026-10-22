
package com.kingjvr.pocket_pcr

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

    private var streamWidth = 0
    private var streamHeight = 0

    private fun showToast(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(
                applicationContext,
                message,
                Toast.LENGTH_LONG
            ).show()
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        rtmpDisplay = RtmpDisplay(applicationContext, true, this)
        rtmpDisplay?.glInterface?.setForceRender(true)
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {
        Log.i("ScreenStreamService", "Service Started")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                notificationId,
                createNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(notificationId, createNotification())
        }

        if (intent != null) {
            val resultCode = intent.getIntExtra("resultCode", -1)

            @Suppress("DEPRECATION")
            val data = intent.getParcelableExtra<Intent>("data")

            val cableRtmp = intent.getStringExtra("cableRtmp")
            val restreamRtmp = intent.getStringExtra("restreamRtmp")
            val rtmpUrl = intent.getStringExtra("rtmpUrl")

            val finalStreamUrl =
                cableRtmp?.takeIf { it.isNotBlank() }
                    ?: restreamRtmp?.takeIf { it.isNotBlank() }
                    ?: rtmpUrl?.takeIf { it.isNotBlank() }

            // URLను Logcatలో చూపించవద్దు; అందులో Stream Key ఉండవచ్చు.
            Log.i(
                "PCR_RTMP",
                "Capture result valid=${resultCode == -1 && data != null}, " +
                    "URL supplied=${!finalStreamUrl.isNullOrBlank()}"
            )

            if (resultCode == -1 &&
                data != null &&
                !finalStreamUrl.isNullOrBlank()
            ) {
                rtmpDisplay?.setIntentResult(resultCode, data)

                val metrics = resources.displayMetrics
                var width = metrics.widthPixels
                var height = metrics.heightPixels
                val screenDpi = metrics.densityDpi

                if (width % 2 != 0) width -= 1
                if (height % 2 != 0) height -= 1

                streamWidth = width
                streamHeight = height

                Log.i(
                    "PCR_RTMP",
                    "Preparing stream: ${width}x${height}, dpi=$screenDpi"
                )

                if (rtmpDisplay?.prepareVideo(
                        width,
                        height,
                        30,
                        2500 * 1024,
                        screenDpi
                    ) == true
                ) {
                    if (rtmpDisplay?.prepareAudio(
                            128 * 1024,
                            44100,
                            true,
                            true,
                            true
                        ) == true
                    ) {
                        Log.i("PCR_RTMP", "Encoders prepared; starting stream")
                        rtmpDisplay?.startStream(finalStreamUrl)
                        showToast("ఇంజిన్ స్టార్ట్ అయ్యింది... వీడియో పంపుతోంది!")
                    } else {
                        Log.e("PCR_RTMP", "Audio encoder preparation failed")
                        showToast("❌ ఆడియో ఎన్‌కోడర్ ఫెయిల్. మైక్ పర్మిషన్ చెక్ చేయండి.")
                        stopSelf()
                    }
                } else {
                    Log.e(
                        "PCR_RTMP",
                        "Video encoder preparation failed: ${width}x${height}"
                    )
                    showToast(
                        "❌ వీడియో ఎన్‌కోడర్ ఫెయిల్. " +
                            "రిజల్యూషన్ ($width x $height) సపోర్ట్ చేయట్లేదు."
                    )
                    stopSelf()
                }
            } else {
                Log.e(
                    "PCR_RTMP",
                    "Missing screen permission result, data, or stream URL"
                )
                showToast("❌ దయచేసి సరైన Live లింక్ ఇవ్వండి.")
                stopSelf()
            }
        } else {
            Log.e("PCR_RTMP", "Service received a null Intent")
            stopSelf()
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        if (rtmpDisplay?.isStreaming == true) {
            rtmpDisplay?.stopStream()
        }
        rtmpDisplay = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onConnectionSuccessRtmp() {
        Log.i(
            "PCR_RTMP",
            "RTMP connection succeeded: ${streamWidth}x${streamHeight}"
        )
        showToast("✅ సక్సెస్! (${streamWidth}x${streamHeight} వీడియో వెళుతోంది)")
    }

    override fun onConnectionFailedRtmp(reason: String) {
        // అసలు కనెక్షన్ వైఫల్య కారణాన్ని Logcatలో నమోదు చేస్తుంది.
        Log.e("PCR_RTMP_ERROR", "RTMP connection failed: $reason")
        showToast("❌ కనెక్షన్ ఫెయిల్: $reason")
        rtmpDisplay?.stopStream()
        stopSelf()
    }

    override fun onNewBitrateRtmp(bitrate: Long) {
        Log.d("PCR_RTMP", "Current bitrate: $bitrate")
    }

    override fun onDisconnectRtmp() {
        Log.w("PCR_RTMP", "RTMP disconnected")
        showToast("⚠️ లైవ్ ఆగిపోయింది (Disconnected)")
    }

    override fun onAuthErrorRtmp() {
        Log.e("PCR_RTMP_ERROR", "RTMP authentication error")
        showToast("❌ లింక్ పాస్‌వర్డ్/ఆథరైజేషన్ తప్పు")
    }

    override fun onAuthSuccessRtmp() {
        Log.i("PCR_RTMP", "RTMP authentication succeeded")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Live Stream Service",
                NotificationManager.IMPORTANCE_LOW
            )

            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val appName = applicationContext.applicationInfo
            .loadLabel(applicationContext.packageManager)
            .toString()

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("$appName - Live")
            .setContentText("లైవ్ బ్రాడ్‌కాస్ట్ అవుతోంది...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
