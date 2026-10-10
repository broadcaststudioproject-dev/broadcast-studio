package com.kingjvk.pocket_pcr;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.widget.Toast;
import androidx.core.app.NotificationCompat;
import com.pedro.library.rtmp.RtmpDisplay;
import com.pedro.rtmp.utils.ConnectCheckerRtmp;

public class ScreenStreamService extends Service implements ConnectCheckerRtmp {
    private RtmpDisplay rtmpDisplay;
    private static final int NOTIFICATION_ID = 2026;
    private static final String CHANNEL_ID = "PocketPCR_LiveChannel";
    private Handler mainHandler;

    @Override
    public void onCreate() {
        super.onCreate();
        mainHandler = new Handler(Looper.getMainLooper());
        createNotificationChannel();

        Notification notification = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Pocket PCR Studio")
                .setContentText("స్క్రీన్ బ్యాక్‌గ్రౌండ్‌లో ప్రసారం అవుతోంది (Live On-Air)")
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build();

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION);
            } else {
                startForeground(NOTIFICATION_ID, notification);
            }
        } catch (Exception e) {
            mainHandler.post(() -> Toast.makeText(this, "Foreground Service Error: " + e.getMessage(), Toast.LENGTH_LONG).show());
        }

        rtmpDisplay = new RtmpDisplay(getBaseContext(), true, this);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null) {
            int resultCode = intent.getIntExtra("resultCode", -1);
            Intent data = intent.getParcelableExtra("data");
            String rtmpUrl = intent.getStringExtra("rtmpUrl");

            if (resultCode != -1 && data != null && rtmpUrl != null && !rtmpUrl.isEmpty()) {
                rtmpDisplay.setIntentResult(resultCode, data);

                if (rtmpDisplay.prepareVideo(1280, 720, 30, 2500 * 1024, 0, 320) &&
                    rtmpDisplay.prepareAudio(64 * 1024, 32000, true, false, false)) {
                    
                    rtmpDisplay.startStream(rtmpUrl);
                } else {
                    mainHandler.post(() -> Toast.makeText(this, "సెటప్ విఫలమైంది. మొబైల్ రిజల్యూషన్ సపోర్ట్ చేయట్లేదు.", Toast.LENGTH_LONG).show());
                    stopSelf();
                }
            }
        }
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (rtmpDisplay != null && rtmpDisplay.isStreaming()) {
            rtmpDisplay.stopStream();
        }
        rtmpDisplay = null;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onConnectionSuccessRtmp() {
        mainHandler.post(() -> Toast.makeText(this, "SUCCESS: మీరు లైవ్‌లో ఉన్నారు!", Toast.LENGTH_LONG).show());
    }

    @Override
    public void onConnectionFailedRtmp(final String reason) {
        mainHandler.post(() -> Toast.makeText(this, "FAILED: లైవ్ ఫెయిల్ అయ్యింది: " + reason, Toast.LENGTH_LONG).show());
        if (rtmpDisplay != null) {
            rtmpDisplay.stopStream();
        }
        stopSelf();
    }

    @Override
    public void onNewBitrateRtmp(long bitrate) {
    }

    @Override
    public void onDisconnectRtmp() {
        mainHandler.post(() -> Toast.makeText(this, "లైవ్ కట్ అయ్యింది.", Toast.LENGTH_SHORT).show());
    }

    @Override
    public void onAuthErrorRtmp() {
        mainHandler.post(() -> Toast.makeText(this, "ఆథరైజేషన్ ఎర్రర్.", Toast.LENGTH_SHORT).show());
    }

    @Override
    public void onAuthSuccessRtmp() {
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "PCR Live Stream", NotificationManager.IMPORTANCE_LOW);
            NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }
}
