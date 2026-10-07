import 'package:flutter/services.dart';

class StreamServiceManager {
  static const platform = MethodChannel('com.kingjvk.pocket_pcr/stream');
  
  static Future<bool> startLiveStream(String rtmpUrl) async {
    try {
      String safeUrl = rtmpUrl.replaceFirst('rtmps://', 'rtmp://');
      // మనం ఆండ్రాయిడ్ ఫైల్ కి పంపాల్సిన కరెక్ట్ కమాండ్ ఇదే
      await platform.invokeMethod('startScreenCaptureStreaming', {
        'cableRtmp': safeUrl,
        'satelliteSrt': ''
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  
  static Future<bool> stopLiveStream() async {
    try {
      await platform.invokeMethod('stopScreenCaptureStreaming');
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> pauseLiveStream() async {
    try {
      await platform.invokeMethod('pauseScreenCaptureStreaming');
      return true;
    } catch (e) {
      return false;
    }
  }
  
  static Future<int?> startUsbCamera() async {
    try {
      return await platform.invokeMethod('startUsbCamera');
    } catch (e) {
      return null;
    }
  }
  
  static Future<void> stopUsbCamera() async {
    try {
      await platform.invokeMethod('stopUsbCamera');
    } catch (e) {}
  }
}
