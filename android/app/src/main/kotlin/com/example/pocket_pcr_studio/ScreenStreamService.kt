package com.ssyatratv.pocket_pcr_studio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.IBinder
import android.view.Surface
import java.nio.ByteBuffer

class ScreenStreamService : Service() {
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var mediaCodec: MediaCodec? = null
    private var isRunning = false

    private val WIDTH = 1280
    private val HEIGHT = 720
    private val DPI = 1
    private val BITRATE = 2000000 // 2 Mbps
    private val FPS = 30

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val resultCode = intent?.getIntExtra("RESULT_CODE", Activity.RESULT_CANCELED) ?: Activity.RESULT_CANCELED
        val data = intent?.getParcelableExtra<Intent>("DATA")
        val rtmpUrl = intent?.getStringExtra("RTMP_URL")

        createNotificationChannel()
        val notification: Notification = Notification.Builder(this, "screen_stream_channel")
            .setContentTitle("Pocket PCR Studio")
            .setContentText("లైవ్ బ్రాడ్‌కాస్ట్ రన్నింగ్‌లో ఉంది...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .build()
        startForeground(1, notification)

        if (resultCode == Activity.RESULT_OK && data != null && rtmpUrl != null) {
            val projectionManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = projectionManager.getMediaProjection(resultCode, data)
            
            startStreaming(rtmpUrl)
        }

        return START_NOT_STICKY
    }

    private fun startStreaming(rtmpUrl: String) {
        isRunning = true
        
        // 1. MediaCodec వీడియో ఎన్‌కోడర్ సెటప్
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, WIDTH, HEIGHT).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, BITRATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, FPS)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
        }

        mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).apply {
            configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            val surface: Surface = createInputSurface()
            prepare()
            start()
            
            // 2. MediaProjection నుండి వచ్చే డిస్‌ప్లేను ఈ సర్ఫేస్‌కి కనెక్ట్ చేయడం
            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "ScreenStream",
                WIDTH, HEIGHT, DPI,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                surface, null, null
            )
        }

        // ఇక్కడ ఎన్‌కోడడ్ డేటాను (H.264 / AAC) RTMP లైబ్రరీ లేదా Socket ద్వారా RTMP URL కి పంపే లూప్ రన్ చేయాలి.
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            "screen_stream_channel",
            "Screen Streaming Service",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        virtualDisplay?.release()
        mediaCodec?.stop()
        mediaCodec?.release()
        mediaProjection?.stop()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
