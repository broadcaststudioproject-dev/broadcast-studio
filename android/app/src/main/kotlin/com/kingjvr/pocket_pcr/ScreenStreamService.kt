package com.kingjvr.pocket_pcr

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.pedro.rtplibrary.rtmp.RtmpDisplay
import com.pedro.rtmp.utils.ConnectCheckerRtmp

class ScreenStreamService : Service() {
    private var rtmpDisplay: RtmpDisplay? = null
    private val channelId = "ScreenStreamChannel"
    private var mMediaProjection: MediaProjection? = null 

    companion object {
        const val ACTION_START = "START_STREAM"
        const val ACTION_STOP = "STOP_STREAM"
        const val EXTRA_URL = "rtmpUrl" 
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"

        var streamStatusListener: ((String) -> Unit)? = null
    }

    private fun showMessage(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(applicationContext, message, Toast.LENGTH_LONG).show()
            streamStatusListener?.invoke(message)
        }
    }

    private fun stopLiveStreamSafely() {
        try { rtmpDisplay?.stopStream() } catch (e: Exception) {}
        try { mMediaProjection?.stop() } catch (e: Exception) {}
    }

    override fun onCreate() {
        super.onCreate()
        try {
            // ఆబ్జెక్ట్ క్రియేట్ చేసే విధానం మార్చాం, ఇక్కడ ప
