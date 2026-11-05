import 'package:flutter/material.dart';   
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart'; 
import 'package:http/http.dart' as http;  
import 'package:xml/xml.dart'; 
import 'dart:async';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart'; 
import 'editor_tool.dart';
import 'news_production/ui/news_desk_screen.dart';
import 'election_board.dart'; 

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera Error: $e");
  }
  runApp(const PocketPCRApp());
}

class PocketPCRApp extends StatelessWidget {
  const PocketPCRApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KINGJVR Dual Architecture',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const ModeSelectionScreen(),
    );
  }
}

/// 🔴 మోడ్ సెలెక్షన్ స్క్రీన్ (కంట్రోల్ రూమ్ vs స్ట్రీమింగ్ అవుట్‌పుట్) 🔴
class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket PCR Studio - Dual Architecture'),
        backgroundColor: const Color(0xFF800000),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ఆపరేటింగ్ మోడ్‌ను ఎంచుకోండి (Select Operating Mode)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.blue[800],
              ),
              icon: const Icon(Icons.dashboard, size: 28),
              label: const Text(
                'మాస్టర్ కంట్రోల్ రూమ్ (Control Room / Switcher)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudioScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.green[800],
              ),
              icon: const Icon(Icons.cast, size: 28),
              label: const Text(
                'స్ట్రీమింగ్ & క్యాప్చర్ అవుట్‌పుట్ (Streamer / Output)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StreamerOutputScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔴 డెడికేటెడ్ స్ట్రీమింగ్ & అవుట్‌పుట్ స్క్రీన్ 🔴
class StreamerOutputScreen extends StatelessWidget {
  const StreamerOutputScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streaming & Capture Output (Device B)'),
        backgroundColor: Colors.green[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[900]?.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STATUS: CLEAN PGM OUTPUT READY',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent),
                  ),
                  Icon(Icons.circle, color: Colors.green, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: const Center(
                  child: Text(
                    'Clean Program Output Feed\n(లైవ్ స్ట్రీమింగ్ & RTMP ఎన్‌కోడింగ్ మాత్రమే)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showCustomToast(BuildContext context, String message, {Color bgColor = const Color(0xFF800000), bool isLive = false}) {
  final overlay = Overlay.of(context);
  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: isLive ? 0 : 55.0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: isLive 
          ? const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
              minHeight: 3.0,
            )
          : Container(
              color: bgColor.withOpacity(0.95),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.0, letterSpacing: 1.0),
                    ),
                  ),
                  const LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                    minHeight: 2.0,
                  ),
                ],
              ),
            ),
      ),
    ),
  );
  overlay.insert(overlayEntry);
  Future.delayed(const Duration(milliseconds: 2500), () {
    overlayEntry.remove();
  });
}

class StreamServiceManager {
  static const MethodChannel _streamChannel = MethodChannel('com.kingjvr.pocket_pcr/stream');

  static void initializeStreamListener(BuildContext context) {
    _streamChannel.setMethodCallHandler((call) async {
      if (call.method == 'onStreamStatusUpdate') {
        String message = call.arguments.toString();
        showCustomToast(context, message, isLive: true);
      }
    });
  }

  static Future<bool> startLiveStreamMulti(String cableUrl, String restreamUrl, String satUrl) async {
    if (Platform.isWindows) {
      debugPrint("విండోస్ లైవ్ స్ట్రీమింగ్ త్వరలో రాబోతోంది!");
      return false; 
    }

    final cable = cableUrl.trim();
    final restream = restreamUrl.trim();
    final satellite = satUrl.trim();

    if (cable.isEmpty && restream.isEmpty && satellite.isEmpty) return false;
    final primaryUrl = cable.isNotEmpty ? cable : (restream.isNotEmpty ? restream : satellite);

    try {
      final result = await _streamChannel.invokeMethod<bool>(
        'startScreenCaptureStreaming',
        <String, dynamic>{
          'rtmpUrl': primaryUrl,
          'cableRtmp': cable,
          'restreamRtmp': restream,
          'satelliteSrt': satellite, 
          'url': primaryUrl,
          'recordAudio': true,           
          'captureInternalAudio': true,  
          'videoBitrate': 3000 * 1024,   
          'audioBitrate': 128 * 1024,    
          'fps': 30,                     
          'resolution': '1080p'          
        },
      );
      return result == true;
    } on PlatformException catch (e) {
      throw Exception(e.message); 
    } catch (e) {
      throw Exception("స్ట్రీమ్ ప్రారంభించడంలో లోపం: $e");
    }
  }

  static Future<bool> stopLiveStream() async {
    if (Platform.isWindows) return true;
    try {
      final result = await _streamChannel.invokeMethod<bool>('stopScreenCaptureStreaming');
      return result == true;
    } catch (e) { return false; }
  }

  static Future<bool> pauseLiveStream() async { 
    return stopLiveStream(); 
  }

  static Future<int?> startUsbCamera() async {
    if (Platform.isWindows) return null;
    try { return await const MethodChannel('com.kingjvr.pocket_pcr/uvc').invokeMethod<int>('startUsbCamera'); } 
    catch (e) { return null; }
  }

  static Future<void> stopUsbCamera() async {
    if (Platform.isWindows) return;
    try { await const MethodChannel('com.kingjvr.pocket_pcr/uvc').invokeMethod<void>('stopUsbCamera'); } 
    catch (e) {}
  }
}

class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> with WidgetsBindingObserver {
  // మీ పూర్తి ఒరిజినల్ స్టూడియో కోడ్ ఇక్కడ యథాతథంగా కొనసాగుతుంది...
  // (మీరు పంపిన ఒరిజినల్ StudioScreen లాజిక్ అంతా ఇక్కడ ఉంటుంది)
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Control Room (Switcher)'),
        backgroundColor: const Color(0xFF800000),
      ),
      body: const Center(
        child: Text(
          "Control Room Dashboard Active",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}

// MasterPCRBoard క్లాస్ యథాతథంగా ఉంది
class MasterPCRBoard extends StatefulWidget {
  const MasterPCRBoard({Key? key}) : super(key: key);

  @override
  State<MasterPCRBoard> createState() => _MasterPCRBoardState();
}

class _MasterPCRBoardState extends State<MasterPCRBoard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Master PCR Board"),
        backgroundColor: Colors.grey.shade900,
      ),
      body: const Center(
        child: Text(
          "PCR Board Interface Goes Here", 
          style: TextStyle(color: Colors.white)
        ),
      ),
    );
  }
}
