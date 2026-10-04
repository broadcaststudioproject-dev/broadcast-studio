package com.kingjvk.pocket_pcr

import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.kingjvk.pocket_pcr/stream"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenStream" -> {
                    val rtmpUrl = call.argument<String>("rtmpUrl")
                    val recordAudio = call.argument<Boolean>("recordAudio") ?: true
                    
                    Log.d("PocketPCR", "Starting RTMP Stream to: $rtmpUrl (Audio: $recordAudio)")
                    // TODO: Screen capture (MediaProjection) and RTMP streaming logic here
                    result.success(true)
                }
                
                "stopScreenStream" -> {
                    Log.d("PocketPCR", "Stopping RTMP Stream")
                    // TODO: Stop RTMP streaming
                    result.success(true)
                }
                
                "startUsbCamera" -> {
                    Log.d("PocketPCR", "Initializing external USB/UVC Capture Card")
                    try {
                        val textureRegistry = flutterEngine.renderer
                        val surfaceEntry = textureRegistry.createSurfaceTexture()
                        
                        // TODO: Connect USB Camera and map preview to surfaceEntry.surfaceTexture
                        
                        result.success(surfaceEntry.id())
                    } catch (e: Exception) {
                        result.error("UVC_ERROR", "OTG Permission denied or Camera not found", null)
                    }
                }
                
                "stopUsbCamera" -> {
                    Log.d("PocketPCR", "Releasing USB/UVC Capture Card")
                    // TODO: Release UVC Camera resources
                    result.success(true)
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
