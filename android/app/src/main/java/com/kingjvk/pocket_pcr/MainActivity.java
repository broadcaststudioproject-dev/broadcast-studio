package com.kingjvk.pocket_pcr;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.media.projection.MediaProjectionManager;
import android.os.Build;
import android.os.Bundle;
import android.widget.Toast;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.kingjvk.pocket_pcr/stream";
    private static final int SCREEN_RECORD_REQUEST_CODE = 1001;

    private String currentCableRtmp = null;
    private String currentCableRtmps = null;
    private String currentSatSrt = null;

    private MediaProjectionManager mediaProjectionManager;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Toast.makeText(this, "✅ Java Engine Started!", Toast.LENGTH_LONG).show();
        mediaProjectionManager = (MediaProjectionManager) getSystemService(Context.MEDIA_PROJECTION_SERVICE);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                switch (call.method) {
                    case "startScreenCaptureStreaming":
                        currentCableRtmp = call.argument("cableRtmp");
                        currentCableRtmps = call.argument("cableRtmps");
                        currentSatSrt = call.argument("satelliteSrt");

                        String activeStreamUrl = (currentCableRtmp != null && !currentCableRtmp.isEmpty()) ? currentCableRtmp
                                : (currentCableRtmps != null && !currentCableRtmps.isEmpty()) ? currentCableRtmps
                                : currentSatSrt;

                        if (activeStreamUrl == null || activeStreamUrl.isEmpty()) {
                            result.error("INVALID_URL", "Streaming URL is missing", null);
                            return;
                        }

                        try {
                            Intent captureIntent = mediaProjectionManager.createScreenCaptureIntent();
                            startActivityForResult(captureIntent, SCREEN_RECORD_REQUEST_CODE);
                            result.success(true);
                        } catch (Exception e) {
                            result.error("PROJECTION_ERROR", e.getMessage() != null ? e.getMessage() : "Cannot start screen capture", null);
                        }
                        break;
                    case "stopScreenCaptureStreaming":
                        Intent stopIntent = new Intent(this, ScreenStreamService.class);
                        stopService(stopIntent);
                        Toast.makeText(this, "Live Broadcast Stopped!", Toast.LENGTH_SHORT).show();
                        result.success(true);
                        break;
                    case "pauseScreenCaptureStreaming":
                        Toast.makeText(this, "Live Broadcast Paused!", Toast.LENGTH_SHORT).show();
                        result.success(true);
                        break;
                    case "startUsbCamera":
                        try {
                            io.flutter.view.TextureRegistry textureRegistry = flutterEngine.getRenderer();
                            io.flutter.view.TextureRegistry.SurfaceTextureEntry surfaceEntry = textureRegistry.createSurfaceTexture();
                            result.success(surfaceEntry.id());
                        } catch (Exception e) {
                            result.error("UVC_ERROR", "OTG Permission denied", null);
                        }
                        break;
                    case "stopUsbCamera":
                        result.success(true);
                        break;
                    default:
                        result.notImplemented();
                        break;
                }
            });
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == SCREEN_RECORD_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                Toast.makeText(this, "లైవ్‌కి కనెక్ట్ అవుతోంది (Background Service)...", Toast.LENGTH_LONG).show();

                String targetUrl = (currentCableRtmp != null && !currentCableRtmp.isEmpty()) ? currentCableRtmp
                        : (currentCableRtmps != null && !currentCableRtmps.isEmpty()) ? currentCableRtmps
                        : currentSatSrt;

                Intent serviceIntent = new Intent(this, ScreenStreamService.class);
                serviceIntent.putExtra("resultCode", resultCode);
                serviceIntent.putExtra("data", data);
                serviceIntent.putExtra("rtmpUrl", targetUrl);

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent);
                } else {
                    startService(serviceIntent);
                }
            } else {
                Toast.makeText(this, "స్క్రీన్ రికార్డింగ్ పర్మిషన్ రిజెక్ట్ చేయబడింది", Toast.LENGTH_SHORT).show();
            }
        }
    }
}
