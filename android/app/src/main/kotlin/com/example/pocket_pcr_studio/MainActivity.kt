package com.example.pocket_pcr_studio

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.ssyatratv.pocket_pcr/stream"
    private val requestScreenCapture = 100
    private val requestPerms = 101
    private var pendingRtmpUrl: String = ""

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScreenStream" -> {
                        pendingRtmpUrl = call.argument<String>("rtmpUrl") ?: ""
                        if (pendingRtmpUrl.isBlank() || pendingRtmpUrl.contains("YOUR_STREAM_KEY")) {
                            showToast("Restream stream key paste చేయండి")
                            result.error("NO_KEY", "Missing Restream stream key", null)
                            return@setMethodCallHandler
                        }
                        requestRuntimePermissionsThenCapture()
                        result.success(true)
                    }
                    "stopScreenStream" -> {
                        stopScreenCapture()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestRuntimePermissionsThenCapture() {
        val needed = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            needed.add(Manifest.permission.RECORD_AUDIO)
        }
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (needed.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, needed.toTypedArray(), requestPerms)
        } else {
            startScreenCapture()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == requestPerms) {
            startScreenCapture()
        }
    }

    private fun startScreenCapture() {
        try {
            val mpm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            startActivityForResult(mpm.createScreenCaptureIntent(), requestScreenCapture)
        } catch (e: Exception) {
            showToast("Error opening popup: ${e.message}")
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestScreenCapture) return

        if (resultCode == Activity.RESULT_OK && data != null) {
            showToast("Permission OK — Restream కి పంపుతున్నాం…")
            try {
                val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
                    action = ScreenStreamService.ACTION_START
                    putExtra(ScreenStreamService.EXTRA_URL, pendingRtmpUrl)
                    putExtra(ScreenStreamService.EXTRA_RESULT_CODE, resultCode)
                    putExtra(ScreenStreamService.EXTRA_DATA, data)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
            } catch (e: Exception) {
                showToast("Service blocked: ${e.message}")
            }
        } else {
            showToast("Recording permission cancelled! Code: $resultCode")
        }
    }

    private fun stopScreenCapture() {
        val serviceIntent = Intent(this, ScreenStreamService::class.java).apply {
            action = ScreenStreamService.ACTION_STOP
        }
        try {
            startService(serviceIntent)
        } catch (e: Exception) {
            showToast("Stop failed: ${e.message}")
        }
    }

    private fun showToast(message: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(this, message, Toast.LENGTH_LONG).show()
        }
    }
}
