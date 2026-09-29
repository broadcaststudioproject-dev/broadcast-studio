import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  try { cameras = await availableCameras(); } catch (e) { debugPrint("Camera Error: $e"); }
  runApp(const PocketPCRApp());
}

class PocketPCRApp extends StatelessWidget {
  const PocketPCRApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: StudioScreen());
  }
}

class NewsBulletinItem {
  String title; String mediaPath; bool isVideo; 
  NewsBulletinItem({required this.title, required this.mediaPath, this.isVideo = true});
}

class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> with WidgetsBindingObserver {
  CameraController? controller;
  VideoPlayerController? _bulletinVideoController; 
  
  // ROBUST GESTURE CONTROL VARIABLES (ChatGPT సలహాతో మెరుగుపరచబడింది)
  bool isLiveLocked = false;
  int _activePointers = 0;
  int _maxPointers = 0;
  DateTime? _gestureStartTime;
  Timer? _unlockTimer;
  
  bool hideControls = false;
  bool isMenuOpen = false;
  
  int currentCameraIndex = 0;
  bool isLiveBroadcasting = false;
  
  bool isNewsBulletinMode = false;
  int currentNewsIndex = 0;
  bool isBulletinMuted = true; 

  final List<NewsBulletinItem> newsBulletinList = [
    NewsBulletinItem(title: "Please Select Videos", mediaPath: "", isVideo: true),
  ];

  final ImagePicker _picker = ImagePicker();
  String channelLogoPath = ""; 
  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA"; 
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String breakingNewsText = "తాజా వార్తలు లోడ్ అవుతున్నాయి...";
  
  TextEditingController youtubeUrlController = TextEditingController();
  Timer? _newsTimer;
  bool _isCameraInitialized = false; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    youtubeUrlController.text = "rtmps://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY_HERE";
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _initCamera();
    _requestPermissions();
    _fetchBreakingNews(); 
    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) { _fetchBreakingNews(); });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newsTimer?.cancel();
    _unlockTimer?.cancel();
    controller?.dispose();
    _bulletinVideoController?.removeListener(_videoListener);
    _bulletinVideoController?.dispose();
    youtubeUrlController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone, Permission.storage].request();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;
    try {
      if (controller != null) { await controller!.dispose(); controller = null; }
      final camController = CameraController(cameras[currentCameraIndex], ResolutionPreset.high, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      controller = camController;
      await camController.initialize();
      if (!mounted) return;
      setState(() { _isCameraInitialized = true; }); 
    } catch (e) {}
  }

  void _switchCamera() async {
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    await _initCamera();
    setState(() { isMenuOpen = false; }); 
  }

  // --- ADVANCED INVISIBLE GESTURE DETECTION (ChatGPT FIX) ---
  
  void _handlePointerDown(PointerDownEvent event) {
    _activePointers++;
    if (_activePointers > _maxPointers) _maxPointers = _activePointers;
    
    if (_activePointers == 1) {
      _gestureStartTime = DateTime.now();
    }
    
    // 3-Finger Unlock (Start Timer)
    if (_activePointers == 3 && isLiveLocked) {
      HapticFeedback.selectionClick();
      _unlockTimer?.cancel();
      _unlockTimer = Timer(const Duration(seconds: 2), () {
        if (_activePointers >= 3) { // 2 సెకన్ల తర్వాత కూడా 3 వేళ్లు ఉంటేనే అన్‌లాక్
          setState(() { isLiveLocked = false; }); 
          HapticFeedback.heavyImpact(); 
        }
      });
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers--;
    if (_activePointers < 3) {
      _unlockTimer?.cancel(); // ఏ ఒక్క వేలు తీసేసినా లాక్ టైమర్ క్యాన్సిల్
    }
    
    if (_activePointers == 0) {
      // ఇక్కడ Two-Finger Tap ని పక్కాగా గుర్తిస్తాం
      if (_gestureStartTime != null && isLiveLocked) {
        final duration = DateTime.now().difference(_gestureStartTime!);
        // 400 మిల్లీసెకన్ల లోపు 2 వేళ్లు పెట్టి తీస్తేనే అది 'ట్యాప్' అవుతుంది
        if (duration.inMilliseconds < 400 && _maxPointers == 2) {
          _toggleMute();
        }
      }
      _maxPointers = 0;
      _gestureStartTime = null;
    }
    
    if (_activePointers < 0) _activePointers = 0;
  }

  void _handleSwipe(DragEndDetails details, bool isHorizontal) {
    if (!isLiveLocked) return; 
    if (isHorizontal) {
      if (details.primaryVelocity! > 300) _changeNewsVideo(1); 
      else if (details.primaryVelocity! < -300) _changeNewsVideo(-1); 
    } else {
      if (details.primaryVelocity! > 300) {
        HapticFeedback.lightImpact();
        setState(() { isNewsBulletinMode = false; _bulletinVideoController?.pause(); });
      }
    }
  }

  void _changeNewsVideo(int direction) {
    if (newsBulletinList.length <= 1) return;
    HapticFeedback.lightImpact(); 
    setState(() {
      currentNewsIndex = (currentNewsIndex + direction) % newsBulletinList.length;
      if (currentNewsIndex < 0) currentNewsIndex = newsBulletinList.length - 1;
      isNewsBulletinMode = true;
      if (newsBulletinList[currentNewsIndex].mediaPath.isNotEmpty) {
        _startBulletinMedia(newsBulletinList[currentNewsIndex].mediaPath, newsBulletinList[currentNewsIndex].isVideo);
      }
    });
  }

  void _toggleMute() {
    HapticFeedback.mediumImpact();
    setState(() {
      isBulletinMuted = !isBulletinMuted;
      _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
    });
  }

  // ------------------------------------------------

  void _startBulletinMedia(String path, bool isVideo) {
    if (path.isEmpty) return;
    if (isVideo) {
      _bulletinVideoController?.removeListener(_videoListener);
      _bulletinVideoController?.dispose();
      _bulletinVideoController = VideoPlayerController.file(File(path))
        ..initialize().then((_) {
          if (!mounted) return;
          _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
          setState(() {});
          _bulletinVideoController?.play();
          _bulletinVideoController?.addListener(_videoListener);
        });
    }
  }

  void _videoListener() {
    final vController = _bulletinVideoController;
    if (vController == null || !vController.value.isInitialized) return;
    if (vController.value.position >= vController.value.duration && vController.value.duration != Duration.zero) {
      vController.removeListener(_videoListener);
      _changeNewsVideo(1); 
    }
  }

  Future<void> _startLiveAndLock() async {
    String fullRtmpUrl = youtubeUrlController.text.trim();
    if (fullRtmpUrl.isEmpty) return;
    try {
      bool success = await StreamServiceManager.startLiveStream(fullRtmpUrl);
      if (success) {
        HapticFeedback.heavyImpact();
        setState(() { 
          isLiveBroadcasting = true; 
          isLiveLocked = true; 
          hideControls = true;
          isMenuOpen = false;
        });
      }
    } catch (e) { }
  }

  Future<void> _stopLiveStream() async {
    bool success = await StreamServiceManager.stopLiveStream();
    if (success) setState(() { isLiveBroadcasting = false; });
  }

  void _showBulletinManagerDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("News Playlist", style: TextStyle(color: Colors.white)),
          content: ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final List<XFile> medias = await _picker.pickMultipleMedia();
              if (medias.isNotEmpty) {
                setState(() {
                  if (newsBulletinList.length == 1 && newsBulletinList[0].mediaPath.isEmpty) newsBulletinList.clear();
                  for (var media in medias) {
                    bool isVid = media.path.toLowerCase().endsWith('.mp4') || media.path.toLowerCase().endsWith('.mov');
                    newsBulletinList.add(NewsBulletinItem(title: "News Video", mediaPath: media.path, isVideo: isVid));
                  }
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ప్లేలిస్ట్ రెడీ!")));
                });
              }
            },
            icon: const Icon(Icons.video_library), label: const Text("Select Videos"),
          ),
        );
      },
    );
  }

  Future<void> _fetchBreakingNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = [];
        for (var item in items.take(15)) titles.add(item.findElements('title').first.innerText);
        if (titles.isNotEmpty && mounted) setState(() { breakingNewsText = titles.join("   ♦   "); });
      }
    } catch (e) { }
  }

  Widget _buildMainDisplay(bool isScreenLandscape, double screenWidth, double screenHeight, Widget cameraWidget) {
    if (isNewsBulletinMode && _bulletinVideoController != null && _bulletinVideoController!.value.isInitialized) {
      double pipWidth = isScreenLandscape ? screenWidth * 0.25 : screenWidth * 0.35;
      double pipHeight = pipWidth * (screenHeight / screenWidth); 

      return Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.black, child: Center(child: AspectRatio(aspectRatio: _bulletinVideoController!.value.aspectRatio, child: VideoPlayer(_bulletinVideoController!))))),
          Positioned(top: 20, left: 15, child: Container(width: pipWidth, height: pipHeight, decoration: BoxDecoration(border: Border.all(color: Colors.redAccent, width: 2.5)), child: cameraWidget)),
        ],
      );
    } 
    return Stack(children: [Positioned.fill(child: cameraWidget)]);
  }

  @override
  Widget build(BuildContext context) {
    bool isScreenLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    Widget cameraWidget = (_isCameraInitialized && controller != null && controller!.value.isInitialized)
        ? ClipRect(child: SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: isScreenLandscape?1920:1080, height: isScreenLandscape?1080:1920, child: CameraPreview(controller!)))))
        : const Center(child: CircularProgressIndicator());

    Widget visualScreenLogoWidget = channelLogoPath.isNotEmpty ? SizedBox(width: 70, height: 70, child: Image.file(File(channelLogoPath))) : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: Colors.red[900], child: const Text("SS YATRA TV", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false, bottom: true,
        // LISTENER FOR ADVANCED MULTI-TOUCH GESTURES
        child: Listener(
          onPointerDown: _handlePointerDown,
          onPointerUp: _handlePointerUp,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) => _handleSwipe(details, true),
            onVerticalDragEnd: (details) => _handleSwipe(details, false),
            onDoubleTap: () {
              if (isLiveLocked && isNewsBulletinMode && _bulletinVideoController != null) {
                _bulletinVideoController!.value.isPlaying ? _bulletinVideoController!.pause() : _bulletinVideoController!.play();
                HapticFeedback.lightImpact();
              }
            },
            onTap: () {
              if (isLiveLocked) return; 
              setState(() { isMenuOpen ? isMenuOpen = false : hideControls = !hideControls; });
            },
            child: Stack(
              children: [
                Positioned.fill(child: _buildMainDisplay(isScreenLandscape, screenWidth, screenHeight, cameraWidget)),
                
                Positioned(top: 15, right: 15, child: visualScreenLogoWidget),
                
                Positioned(
                  bottom: 65, left: 15, 
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(color: Colors.red.shade700, padding: const EdgeInsets.all(3), child: Text(locationText, style: const TextStyle(color: Colors.white, fontSize: 11))),
                    Container(color: Colors.white, padding: const EdgeInsets.all(4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13))),
                  ])
                ),
                
                Positioned(
                  bottom: 0, left: 0, right: 0, 
                  child: Container(
                    height: 55, color: Colors.red.shade900,
                    child: Row(children: [
                      Container(width: 55, color: Colors.black, child: const Icon(Icons.newspaper, color: Colors.amber)),
                      Expanded(child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 40.0))
                    ]),
                  ),
                ),

                if (!hideControls && !isLiveLocked)
                  Positioned(
                    bottom: 75, right: 20,
                    child: FloatingActionButton(backgroundColor: Colors.blueAccent, onPressed: () { setState(() { isMenuOpen = !isMenuOpen; }); }, child: Icon(isMenuOpen ? Icons.close : Icons.menu)),
                  ),

                if (!hideControls && isMenuOpen && !isLiveLocked)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black87,
                      child: Center(
                        child: Wrap(
                          spacing: 25, runSpacing: 25,
                          children: [
                            _buildControlButton(Icons.playlist_play, "1. Playlist", _showBulletinManagerDialog, Colors.orange),
                            _buildControlButton(Icons.video_camera_back, "2. Check News", () { setState(() { isNewsBulletinMode = true; isMenuOpen = false; _changeNewsVideo(0); }); }, Colors.teal),
                            _buildControlButton(Icons.lock_outline, "3. START LIVE & LOCK", _startLiveAndLock, Colors.redAccent),
                            if (isLiveBroadcasting) _buildControlButton(Icons.stop, "Stop Live", _stopLiveStream, Colors.red),
                            _buildControlButton(Icons.flip_camera_android, "Switch Cam", _switchCamera, Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, VoidCallback onTap, Color iconColor) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 26, backgroundColor: Colors.white30, child: Icon(icon, color: iconColor, size: 26)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class StreamServiceManager {
  static const platform = MethodChannel('com.ssyatratv.pocket_pcr/stream');
  static Future<bool> startLiveStream(String rtmpUrl) async {
    try { await platform.invokeMethod('startScreenStream', {'rtmpUrl': rtmpUrl.replaceFirst('rtmps://', 'rtmp://')}); return true; } 
    catch (e) { return false; }
  }
  static Future<bool> stopLiveStream() async {
    try { await platform.invokeMethod('stopScreenStream'); return true; } 
    catch (e) { return false; }
  }
}
