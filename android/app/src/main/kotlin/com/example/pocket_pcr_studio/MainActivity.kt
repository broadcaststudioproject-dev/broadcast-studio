package com.ssyatratv.pocket_pcr

import android.content.Context
import android.graphics.SurfaceTexture
import android.hardware.usb.UsbDevice
import android.view.Surface
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import com.jiangdongguo.android.usbcamera.UVCCameraHelper
import com.serenegiant.usb.widget.CameraViewInterface

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ssyatratv.pocket_pcr/stream"
    
    // USB Camera Variables
    private var mUVCCameraHelper: UVCCameraHelper? = null
    private var surfaceEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var flutterSurface: Surface? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenStream" -> {
                    val rtmpUrl = call.argument<String>("rtmpUrl")
                    // మీ థర్డ్-పార్టీ RTMP లైబ్రరీ (ఉదాహరణకు rtmp-rtsp-stream-client-java) ఇక్కడ కాల్ అవుతుంది
                    // startScreenBroadcasting(rtmpUrl)
                    result.success(true)
                }
                "stopScreenStream" -> {
                    // stopScreenBroadcasting()
                    result.success(true)
                }
                "startUsbCamera" -> {
                    try {
                        val textureRegistry = flutterEngine.renderer
                        surfaceEntry = textureRegistry.createSurfaceTexture()
                        val surfaceTexture = surfaceEntry?.surfaceTexture
                        
                        // UVC కెమెరా రిజల్యూషన్ సెట్ చేయడం
                        surfaceTexture?.setDefaultBufferSize(1920, 1080)
                        flutterSurface = Surface(surfaceTexture)

                        initUVCCamera()
                        
                        // Flutter టెక్స్చర్ ఐడీని వెనక్కి పంపడం
                        result.success(surfaceEntry?.id())
                    } catch (e: Exception) {
                        result.error("UVC_ERROR", e.localizedMessage, null)
                    }
                }
                "stopUsbCamera" -> {
                    mUVCCameraHelper?.release()
                    flutterSurface?.release()
                    surfaceEntry?.release()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun initUVCCamera() {
        mUVCCameraHelper = UVCCameraHelper.getInstance()
        mUVCCameraHelper?.setDefaultFrameFormat(UVCCameraHelper.FRAME_FORMAT_MJPEG)
        mUVCCameraHelper?.initUSBMonitor(this, mCameraHelperCallback)
        mUVCCameraHelper?.registerUSB()
    }

    private val mCameraHelperCallback = object : UVCCameraHelper.OnMyDevConnectListener {
        override fun onAttachDev(device: UsbDevice?) {
            if (mUVCCameraHelper?.isCameraOpened == false) {
                mUVCCameraHelper?.requestPermission(0)
            }
        }
        override fun onDettachDev(device: UsbDevice?) {
            mUVCCameraHelper?.closeCamera()
        }
        override fun onConnectDev(device: UsbDevice?, isConnected: Boolean) {
            if (isConnected) {
                // ఫ్లట్టర్ సర్ఫేస్ కు ఫీడ్ పంపడం
                mUVCCameraHelper?.startPreview(flutterSurface)
            }
        }
        override fun onDisConnectDev(device: UsbDevice?) {
            mUVCCameraHelper?.closeCamera()
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        mUVCCameraHelper?.unregisterUSB()
        mUVCCameraHelper?.release()
    }
}
