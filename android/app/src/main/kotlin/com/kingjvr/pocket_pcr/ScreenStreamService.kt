import 'dart:io';
import 'package:flutter/services.dart';

class StreamManager {
  // ఆండ్రాయిడ్ కోసం మనం సెట్ చేసిన MethodChannel పేరు
  static const MethodChannel _channel = MethodChannel('com.kingjvk.pocket_pcr/stream');
  
  // విండోస్ లో FFmpeg ప్రాసెస్‌ని కంట్రోల్ చేయడానికి
  static Process? _windowsFfmpegProcess;

  // 🔴 లైవ్ స్టార్ట్ చేయడానికి ఫంక్షన్
  static Future<void> startLiveStream(String rtmpUrl) async {
    if (Platform.isAndroid) {
      // 1. Android అయితే: Kotlin సర్వీస్‌కి కమాండ్ పంపుతాము
      try {
        await _channel.invokeMethod('START_STREAM', {'rtmpUrl': rtmpUrl});
        print("Android Live Started");
      } on PlatformException catch (e) {
        print("Android Error: '${e.message}'.");
      }
    } else if (Platform.isWindows) {
      // 2. Windows అయితే: FFmpeg ద్వారా స్క్రీన్ రికార్డ్ చేసి లైవ్ పంపుతాము
      _startWindowsStream(rtmpUrl);
    }
  }

  // 🔴 లైవ్ ఆపడానికి ఫంక్షన్
  static Future<void> stopLiveStream() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('STOP_STREAM');
        print("Android Live Stopped");
      } on PlatformException catch (e) {
        print("Android Error: '${e.message}'.");
      }
    } else if (Platform.isWindows) {
      _stopWindowsStream();
    }
  }

  // ==========================================
  // WINDOWS FFMPEG లాజిక్ (స్క్రీన్ కాప్చర్ & RTMP)
  // ==========================================
  static void _startWindowsStream(String rtmpUrl) async {
    try {
      // గమనిక: విండోస్ సిస్టమ్‌లో/ప్రాజెక్ట్‌లో ffmpeg.exe ఉండాలి
      _windowsFfmpegProcess = await Process.start(
        'ffmpeg',
        [
          '-f', 'gdigrab',           // విండోస్ స్క్రీన్ క్యాప్చర్ టూల్
          '-framerate', '30',        // 30 FPS
          '-i', 'desktop',           // మొత్తం స్క్రీన్ రికార్డ్ చేయడానికి
          '-c:v', 'libx264',         // వీడియో ఎన్‌కోడర్
          '-preset', 'ultrafast',    // లాగ్ (Delay) లేకుండా స్పీడ్ గా వెళ్లడానికి
          '-tune', 'zerolatency',    // జీరో లేటెన్సీ కోసం
          '-pix_fmt', 'yuv420p',
          '-c:a', 'aac',             // ఆడియో ఎన్‌కోడర్ (మైక్ కనెక్ట్ చేస్తే సెట్ చేయాలి)
          '-f', 'flv',               // RTMP కి సపోర్ట్ చేసే ఫార్మాట్
          rtmpUrl                    // మీ యూట్యూబ్/ఫేస్బుక్ RTMP లింక్
        ],
      );
      print("Windows Live Stream Started via FFmpeg");

      // విండోస్ లో ఏమైనా ఎర్రర్ వస్తే చూడటానికి
      _windowsFfmpegProcess?.stderr.listen((data) {
        print('FFmpeg Log: ${String.fromCharCodes(data)}');
      });

    } catch (e) {
      print("Windows Stream Error: FFmpeg ఇన్‌స్టాల్ అయిందో లేదో చెక్ చేయండి. Error: $e");
    }
  }

  static void _stopWindowsStream() {
    if (_windowsFfmpegProcess != null) {
      _windowsFfmpegProcess?.kill();
      _windowsFfmpegProcess = null;
      print("Windows Live Stream Stopped");
    }
  }
}
