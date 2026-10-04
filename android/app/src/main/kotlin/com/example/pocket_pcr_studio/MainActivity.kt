package com.kingjvk.pocket_pcr

import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    // ప్యాకేజీ పేరు ఇక్కడ కూడా సేమ్ ఉండాలి 
    private val CHANNEL = "com.kingjvk.pocket_pcr/stream"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenStream" -> {
                    val rtmpUrl = call.argument<String>("rtmpUrl")
                    val recordAudio = call.argument<Boolean>("recordAudio") ?: true
                    
                    Log.d("PocketPCR", "Starting RTMP Stream to: $rtmpUrl (Audio: $recordAudio)")
                    // మీ RTMP బ్రాడ్‌కాస్టింగ్ లాజిక్ ఇక్కడ వస్తుంది
                    result.success(true)
                }
                "stopScreenStream" -> {
                    Log.d("PocketPCR", "Stopping RTMP Stream")
                    result.success(true)
                }
                "startUsbCamera" -> {
                    Log.d("PocketPCR", "Initializing USB/UVC Camera")
                    try {
                        val textureRegistry = flutterEngine.renderer
                        val surfaceEntry = textureRegistry.createSurfaceTexture()
                        
                        // ఇక్కడ AndroidUSBCamera (UVC) లాజిక్ యాడ్ చేసి textureId ని ఫ్లట్టర్‌కి పంపాలి
                        result.success(surfaceEntry.id())
                    } catch (e: Exception) {
                        result.error("UVC_ERROR", e.localizedMessage, null)
                    }
                }
                "stopUsbCamera" -> {
                    Log.d("PocketPCR", "Releasing USB/UVC Camera")
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
