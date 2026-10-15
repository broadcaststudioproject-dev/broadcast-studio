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
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StudioScreen(),
    );
  }
}

// ============================================================================
// --- NATIVE STREAMING SERVICE MANAGER
// ============================================================================
class StreamServiceManager {
  static const platform = MethodChannel('com.kingjvk.pocket_pcr/stream');
  
  static Future<bool> startLiveStream(String cableRtmp, String restreamRtmp, String satelliteSrt, bool noiseCancel) async {
    try {
      await platform.invokeMethod('startScreenCaptureStreaming', {
        'cableRtmp': cableRtmp.trim(),
        'restreamRtmp': restreamRtmp.trim(),
        'satelliteSrt': satelliteSrt.trim(),
        'noiseCancel': noiseCancel
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

// ============================================================================
// --- 1. MAIN STUDIO SCREEN
// ============================================================================

class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  
  CameraController? controller;
  VlcPlayerController? _bulletinVideoController; 
  
  List<String> dualMediaList = [];
  int currentDualMediaIndex = 0;
  VideoPlayerController? _bottomAdVideoController;

  List<String> localVideoPlaylist = [];
  int currentLocalVideoIndex = 0;
  bool isLocalPlaylistPlaying = false;

  bool hideControls = false;
  bool isMenuOpen = false;

  int currentCameraIndex = 0;
  bool isLandscape = false;
  bool isLiveBroadcasting = false;
  bool isLivePaused = false;
  
  bool isDualScreenMode = false;
  bool isLBandRight = true;

  bool isNewsBulletinMode = false;
  bool isBulletinMuted = false;
  bool isCameraVisible = false;
  bool isYoutubeLoading = false;
  
  bool isNoiseCancellationEnabled = true;

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  double _baseScale = 1.0;

  final ImagePicker _picker = ImagePicker();

  String channelLogoPath = "";
  double logoWidth = 70.0;
  double logoHeight = 70.0;
  int logoPosition = 0; 

  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA";
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String breakingNewsText = "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";

  TextEditingController cableRtmpController = TextEditingController();
  TextEditingController restreamRtmpController = TextEditingController();
  TextEditingController satelliteSrtController = TextEditingController();
  TextEditingController networkVideoUrlCtrl = TextEditingController();
  TextEditingController youtubeVideoUrlCtrl = TextEditingController();
  TextEditingController watermarkCtrl = TextEditingController();
  TextEditingController locCtrl = TextEditingController();
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController roleCtrl = TextEditingController();

  TextEditingController ipCamUrlCtrl = TextEditingController();
  TextEditingController droneCamUrlCtrl = TextEditingController();

  Timer? _newsTimer;
  Timer? _adCycleTimer;
  Timer? _tickerColorTimer;
  
  bool _isCameraInitialized = false;

  List<String> leftAdPaths = [];
  List<String> rightAdPaths = [];
  List<String> bottomAdPaths = [];
  
  int leftAdIndex = 0;
  int rightAdIndex = 0;
  int bottomAdIndex = 0;

  VideoPlayerController? _leftAdVideoCtrl;
  VideoPlayerController? _rightAdVideoCtrl;
  VideoPlayerController? _bottomAdVideoCtrlForAds;
  VideoPlayerController? _logoVideoCtrl;

  bool isExternalIpCamMode = false;
  bool isUsbCamMode = false;
  bool isDroneCamMode = false;
  VideoPlayerController? _ipCamController;
  VideoPlayerController? _droneCamController;
  int? _usbTextureId;

  int adDisplayMode = 0;
  bool isAdCurrentlyShowing = false;
  int adShapeMode = 0;
  int _tickerBgColorIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    ipCamUrlCtrl.text = "http://192.168.1.100:8080/video";
    droneCamUrlCtrl.text = "rtsp://192.168.1.1:554/live";

    watermarkCtrl.text = watermarkText;
    locCtrl.text = locationText;
    nameCtrl.text = reporterName;
    roleCtrl.text = reporterRole;
    
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);

    _tickerColorTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) setState(() => _tickerBgColorIndex++);
    });

    _loadSavedData();
    _requestPermissions();
    _fetchBreakingNews();

    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) { _fetchBreakingNews(); });
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      watermarkText = prefs.getString('watermarkText') ?? "SS YATRA TV";
      locationText = prefs.getString('locationText') ?? "LIVE KOTHAKOTA";
      reporterName = prefs.getString('reporterName') ?? "JANAMPALLY VINOD KUMAR";
      reporterRole = prefs.getString('reporterRole') ?? "SPECIAL CORRESPONDENT";
      breakingNewsText = prefs.getString('breakingNewsText') ?? "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";
      
      adShapeMode = prefs.getInt('adShapeMode') ?? 0;
      logoPosition = prefs.getInt('logoPosition') ?? 0;
      isNoiseCancellationEnabled = prefs.getBool('noiseCancel') ?? true;

      cableRtmpController.text = prefs.getString('cableRtmp') ?? "";
      restreamRtmpController.text = prefs.getString('restreamRtmp') ?? "";
      satelliteSrtController.text = prefs.getString('satelliteSrt') ?? "";
      youtubeVideoUrlCtrl.text = prefs.getString('youtubeVideoUrl') ?? "";
      networkVideoUrlCtrl.text = prefs.getString('networkVideoUrl') ?? "";

      String savedLogo = prefs.getString('channelLogoPath') ?? "";
      if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) _setLogo(savedLogo);

      leftAdPaths = (prefs.getStringList('leftAdPaths') ?? []).where((p) => File(p).existsSync()).toList();
      rightAdPaths = (prefs.getStringList('rightAdPaths') ?? []).where((p) => File(p).existsSync()).toList();
      bottomAdPaths = (prefs.getStringList('bottomAdPaths') ?? []).where((p) => File(p).existsSync()).toList();

      if (leftAdPaths.isNotEmpty) _initAdVideo('left');
      if (rightAdPaths.isNotEmpty) _initAdVideo('right');
      if (bottomAdPaths.isNotEmpty) _initAdVideo('bottom');
    });
  }

  void _setLogo(String path) {
    channelLogoPath = path;
    if (path.toLowerCase().endsWith('.mp4')) {
      _logoVideoCtrl?.dispose();
      _logoVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { 
        if (mounted) { _logoVideoCtrl!.setLooping(true); _logoVideoCtrl!.setVolume(0); _logoVideoCtrl!.play(); setState((){}); } 
      });
    } else { 
      _logoVideoCtrl?.dispose(); _logoVideoCtrl = null; 
    }
  }

  void _initAdVideo(String pos) {
    String path = "";
    if (pos == 'left' && leftAdPaths.isNotEmpty) path = leftAdPaths[leftAdIndex = leftAdIndex % leftAdPaths.length];
    if (pos == 'right' && rightAdPaths.isNotEmpty) path = rightAdPaths[rightAdIndex = rightAdIndex % rightAdPaths.length];
    if (pos == 'bottom' && bottomAdPaths.isNotEmpty) path = bottomAdPaths[bottomAdIndex = bottomAdIndex % bottomAdPaths.length];
    if (path.isEmpty) return;

    bool isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov') || path.toLowerCase().endsWith('.gif');
    if (pos == 'left') {
      _leftAdVideoCtrl?.dispose(); _leftAdVideoCtrl = null;
      if (isVideo) _leftAdVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { if(mounted){ _leftAdVideoCtrl!.setLooping(true); _leftAdVideoCtrl!.setVolume(0.0); _leftAdVideoCtrl!.play(); setState((){}); }});
    } else if (pos == 'right') {
      _rightAdVideoCtrl?.dispose(); _rightAdVideoCtrl = null;
      if (isVideo) _rightAdVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { if(mounted){ _rightAdVideoCtrl!.setLooping(true); _rightAdVideoCtrl!.setVolume(0.0); _rightAdVideoCtrl!.play(); setState((){}); }});
    } else if (pos == 'bottom') {
      _bottomAdVideoCtrlForAds?.dispose(); _bottomAdVideoCtrlForAds = null;
      if (isVideo) _bottomAdVideoCtrlForAds = VideoPlayerController.file(File(path))..initialize().then((_) { if(mounted){ _bottomAdVideoCtrlForAds!.setLooping(true); _bottomAdVideoCtrlForAds!.setVolume(0.0); _bottomAdVideoCtrlForAds!.play(); setState((){}); }});
    }
  }

  Future<void> _saveTextSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('watermarkText', watermarkText);
    await prefs.setString('locationText', locationText);
    await prefs.setString('reporterName', reporterName);
    await prefs.setString('reporterRole', reporterRole);
    await prefs.setInt('adShapeMode', adShapeMode);
    await prefs.setInt('logoPosition', logoPosition);
    await prefs.setBool('noiseCancel', isNoiseCancellationEnabled);
  }

  Future<void> _saveLinks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cableRtmp', cableRtmpController.text);
    await prefs.setString('restreamRtmp', restreamRtmpController.text);
    await prefs.setString('satelliteSrt', satelliteSrtController.text);
    await prefs.setString('youtubeVideoUrl', youtubeVideoUrlCtrl.text);
    await prefs.setString('networkVideoUrl', networkVideoUrlCtrl.text);
  }

  Future<void> _saveAdPaths(String pos, List<String> paths) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (pos == 'left') await prefs.setStringList('leftAdPaths', paths);
    if (pos == 'right') await prefs.setStringList('rightAdPaths', paths);
    if (pos == 'bottom') await prefs.setStringList('bottomAdPaths', paths);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (isCameraVisible &&
          !isExternalIpCamMode &&
          !isUsbCamMode &&
          !isDroneCamMode && 
          (controller == null || !controller!.value.isInitialized)) {
        _initCamera();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newsTimer?.cancel();
    _adCycleTimer?.cancel();
    _tickerColorTimer?.cancel();

    controller?.dispose();
    _bulletinVideoController?.stopRendererScanning();
    _bulletinVideoController?.dispose();
    _bottomAdVideoController?.dispose();

    _leftAdVideoCtrl?.dispose();
    _rightAdVideoCtrl?.dispose();
    _bottomAdVideoCtrlForAds?.dispose();
    _logoVideoCtrl?.dispose();
    _ipCamController?.dispose();
    _droneCamController?.dispose();
    
    super.dispose();
  }

  Future<void> _fetchBreakingNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = [];
        for (var item in items.take(20)) {
          titles.add(item.findElements('title').first.innerText.replaceAll(RegExp(r'^[0-9]+[smh]\s*Trend:\s*', caseSensitive: false), ''));
        }
        if (titles.isNotEmpty && mounted) setState(() => breakingNewsText = titles.join("   ♦   "));
      }
    } catch (e) {}
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone, Permission.storage, Permission.photos, Permission.videos].request();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;
    try {
      if (controller != null) await controller!.dispose();
      final camController = CameraController(cameras[currentCameraIndex], ResolutionPreset.high, enableAudio: true);
      controller = camController;
      await camController.initialize();
      if (!mounted) return;
      _minZoomLevel = await camController.getMinZoomLevel();
      _maxZoomLevel = await camController.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      setState(() => _isCameraInitialized = true);
    } catch (e) {}
  }

  void _switchCamera() async {
    if (isExternalIpCamMode || isUsbCamMode || isDroneCamMode) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఎక్స్‌టర్నల్ / డ్రోన్ మోడ్‌లో కెమెరా స్విచ్ పనిచేయదు.")));
      return;
    }
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    if (isCameraVisible) await _initCamera();
    setState(() => isMenuOpen = false);
  }

  void _toggleCameraVisibility() async {
    setState(() => isMenuOpen = false);
    if (isExternalIpCamMode || isUsbCamMode || isDroneCamMode) {
      setState(() {
        isExternalIpCamMode = false; isUsbCamMode = false; isDroneCamMode = false; isCameraVisible = false; _usbTextureId = null;
      });
      _ipCamController?.dispose(); _ipCamController = null;
      _droneCamController?.dispose(); _droneCamController = null;
      try { await StreamServiceManager.stopUsbCamera(); } catch (_) {}
      return;
    }
    if (isCameraVisible) {
      setState(() => isCameraVisible = false);
      await controller?.dispose(); controller = null;
      setState(() => _isCameraInitialized = false);
    } else {
      setState(() => isCameraVisible = true);
      await _initCamera();
    }
  }

  void _toggleAdMode() {
    setState(() {
      adDisplayMode = (adDisplayMode + 1) % 3;
      isMenuOpen = false;
      _adCycleTimer?.cancel();
      if (adDisplayMode == 0) {
        isAdCurrentlyShowing = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("యాడ్స్ ఆఫ్"), backgroundColor: Colors.red));
      } else if (adDisplayMode == 1) {
        isAdCurrentlyShowing = true; _startPermanentCycle();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("యాడ్స్ ఆన్ (నిరంతరం)"), backgroundColor: Colors.blueAccent));
      } else if (adDisplayMode == 2) {
        isAdCurrentlyShowing = true; _startAutoCycle();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఆటో టైమర్"), backgroundColor: Colors.green));
      }
    });
  }

  void _startPermanentCycle() {
    _adCycleTimer?.cancel();
    _adCycleTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted && adDisplayMode == 1) {
        setState(() {
          if (leftAdPaths.isNotEmpty) leftAdIndex = (leftAdIndex + 1) % leftAdPaths.length;
          if (rightAdPaths.isNotEmpty) rightAdIndex = (rightAdIndex + 1) % rightAdPaths.length;
          if (bottomAdPaths.isNotEmpty) bottomAdIndex = (bottomAdIndex + 1) % bottomAdPaths.length;
          _initAdVideo('left'); _initAdVideo('right'); _initAdVideo('bottom');
        });
      }
    });
  }

  void _startAutoCycle() {
    _adCycleTimer?.cancel();
    if (isAdCurrentlyShowing) {
      _adCycleTimer = Timer(const Duration(seconds: 20), () {
        if (mounted && adDisplayMode == 2) { setState(() => isAdCurrentlyShowing = false); _startAutoCycle(); }
      });
    } else {
      _adCycleTimer = Timer(const Duration(seconds: 40), () {
        if (mounted && adDisplayMode == 2) {
          setState(() {
            isAdCurrentlyShowing = true;
            if (leftAdPaths.isNotEmpty) leftAdIndex = (leftAdIndex + 1) % leftAdPaths.length;
            if (rightAdPaths.isNotEmpty) rightAdIndex = (rightAdIndex + 1) % rightAdPaths.length;
            if (bottomAdPaths.isNotEmpty) bottomAdIndex = (bottomAdIndex + 1) % bottomAdPaths.length;
            _initAdVideo('left'); _initAdVideo('right'); _initAdVideo('bottom');
          });
          _startAutoCycle();
        }
      });
    }
  }

  void _toggleAdShapeMode() async {
    setState(() { adShapeMode = (adShapeMode + 1) % 3; isMenuOpen = false; });
    await _saveTextSettings();
  }

  void _toggleLBandDirection() {
    setState(() { isLBandRight = !isLBandRight; isMenuOpen = false; });
  }

  void _changeLogoPosition() async {
    setState(() { logoPosition = (logoPosition + 1) % 4; isMenuOpen = false; });
    await _saveTextSettings();
  }

  Future<void> _startIpCamera(String url) async {
    if (url.isEmpty) return;
    _ipCamController?.dispose();
    _ipCamController = VideoPlayerController.networkUrl(Uri.parse(url))..initialize().then((_) {
      if (!mounted) return;
      setState(() { isExternalIpCamMode = true; isUsbCamMode = false; isDroneCamMode = false; isCameraVisible = true; isNewsBulletinMode = false; isDualScreenMode = false; });
      _ipCamController?.play();
    });
  }

  Future<void> _startDroneCamera(String url) async {
    if (url.isEmpty) return;
    _droneCamController?.dispose();
    _droneCamController = VideoPlayerController.networkUrl(Uri.parse(url))..initialize().then((_) {
      if (!mounted) return;
      setState(() { isDroneCamMode = true; isExternalIpCamMode = false; isUsbCamMode = false; isCameraVisible = true; isNewsBulletinMode = false; isDualScreenMode = false; });
      _droneCamController?.play();
    });
  }

  Future<void> _startUsbCamera() async {
    try {
      final int? textureId = await StreamServiceManager.startUsbCamera();
      if (textureId != null) {
        setState(() { _usbTextureId = textureId; isUsbCamMode = true; isExternalIpCamMode = false; isDroneCamMode = false; isCameraVisible = true; isNewsBulletinMode = false; });
      }
    } catch (e) {}
  }

  void _showExternalCamsDialog() {
    setState(() => isMenuOpen = false);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("External Cameras & Drone", style: TextStyle(color: Colors.white, fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: ipCamUrlCtrl, style: const TextStyle(color: Colors.yellow, fontSize: 12), decoration: const InputDecoration(hintText: "IP Cam URL")),
              ElevatedButton(onPressed: () { Navigator.pop(context); _startIpCamera(ipCamUrlCtrl.text.trim()); }, child: const Text("Connect IP Cam")),
              TextField(controller: droneCamUrlCtrl, style: const TextStyle(color: Colors.yellow, fontSize: 12), decoration: const InputDecoration(hintText: "Drone URL")),
              ElevatedButton(onPressed: () { Navigator.pop(context); _startDroneCamera(droneCamUrlCtrl.text.trim()); }, child: const Text("Connect Drone")),
              ElevatedButton(onPressed: () { Navigator.pop(context); _startUsbCamera(); }, child: const Text("Start USB Camera")),
            ]),
          ),
        );
      }
    );
  }

  Future<void> _pickAds(String pos) async {
    try {
      final List<XFile> medias = await _picker.pickMultipleMedia();
      if (medias.isNotEmpty && mounted) {
        setState(() {
          if (pos == 'left') { leftAdPaths.addAll(medias.map((e) => e.path)); leftAdIndex = leftAdPaths.length - 1; _saveAdPaths(pos, leftAdPaths); }
          if (pos == 'right') { rightAdPaths.addAll(medias.map((e) => e.path)); rightAdIndex = rightAdPaths.length - 1; _saveAdPaths(pos, rightAdPaths); }
          if (pos == 'bottom') { bottomAdPaths.addAll(medias.map((e) => e.path)); bottomAdIndex = bottomAdPaths.length - 1; _saveAdPaths(pos, bottomAdPaths); }
          _initAdVideo(pos);
        });
      }
    } catch (e) {}
  }

  void _manageAdsDialog(String pos) {
    List<String> currentPaths = [];
    if (pos == 'left') currentPaths = leftAdPaths;
    if (pos == 'right') currentPaths = rightAdPaths;
    if (pos == 'bottom') currentPaths = bottomAdPaths;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900], title: Text("Manage ${pos.toUpperCase()} Ads", style: const TextStyle(color: Colors.white, fontSize: 16)),
            content: SizedBox(
              width: double.maxFinite,
              child: currentPaths.isEmpty ? const Text("యాడ్స్ ఏమీ లేవు.", style: TextStyle(color: Colors.white54)) : ListView.builder(
                shrinkWrap: true, itemCount: currentPaths.length, itemBuilder: (ctx, idx) {
                  String path = currentPaths[idx];
                  bool isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov') || path.toLowerCase().endsWith('.gif');
                  return ListTile(
                    leading: isVideo ? const Icon(Icons.video_file, color: Colors.blueAccent, size: 40) : Image.file(File(path), width: 50, height: 50, fit: BoxFit.cover),
                    title: Text("Ad ${idx + 1}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                    trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () {
                      setState(() {
                        currentPaths.removeAt(idx); _saveAdPaths(pos, currentPaths);
                        if (pos == 'left') { if (leftAdIndex >= leftAdPaths.length) leftAdIndex = 0; _initAdVideo('left'); }
                        if (pos == 'right') { if (rightAdIndex >= rightAdPaths.length) rightAdIndex = 0; _initAdVideo('right'); }
                        if (pos == 'bottom') { if (bottomAdIndex >= bottomAdPaths.length) bottomAdIndex = 0; _initAdVideo('bottom'); }
                      });
                      setDialogState(() {});
                    }),
                  );
                },
              ),
            ),
            actions: [
              TextButton(child: const Text("Clear All", style: TextStyle(color: Colors.redAccent)), onPressed: () {
                setState(() {
                  currentPaths.clear(); _saveAdPaths(pos, currentPaths);
                  if (pos == 'left') { leftAdIndex = 0; _leftAdVideoCtrl?.dispose(); _leftAdVideoCtrl = null; }
                  if (pos == 'right') { rightAdIndex = 0; _rightAdVideoCtrl?.dispose(); _rightAdVideoCtrl = null; }
                  if (pos == 'bottom') { bottomAdIndex = 0; _bottomAdVideoCtrlForAds?.dispose(); _bottomAdVideoCtrlForAds = null; }
                });
                Navigator.pop(ctx);
              }),
              TextButton(child: const Text("Close", style: TextStyle(color: Colors.white)), onPressed: () => Navigator.pop(ctx))
            ],
          );
        });
      },
    );
  }

  void _showEditDialog() {
    setState(() => isMenuOpen = false);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900], title: const Text("స్టూడియో సెట్టింగ్స్", style: TextStyle(color: Colors.white, fontSize: 13)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final XFile? media = await _picker.pickMedia();
                    if (media != null) {
                      setState(() => _setLogo(media.path));
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      await prefs.setString('channelLogoPath', media.path);
                      setDialogState(() {});
                    }
                  },
                  icon: const Icon(Icons.upload), label: const Text("లోగో అప్లోడ్ (JPEG, GIF, MP4)")
                ),
                TextField(controller: watermarkCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "వాటర్ మార్క్")),
                TextField(controller: locCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "లొకేషన్")),
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "రిపోర్టర్ పేరు")),
                TextField(controller: roleCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "హోదా")),
                const Divider(color: Colors.white24, height: 20),
                SwitchListTile(
                  title: const Text("Noise Cancellation\n(ఆడియో నాయిస్ క్యాన్సిలేషన్)", style: TextStyle(color: Colors.white, fontSize: 12)),
                  value: isNoiseCancellationEnabled,
                  activeColor: Colors.greenAccent,
                  onChanged: (val) {
                    setState(() => isNoiseCancellationEnabled = val);
                    setDialogState(() {});
                  },
                ),
              ]),
            ),
            actions: [
              ElevatedButton(onPressed: () async {
                setState(() { watermarkText = watermarkCtrl.text; locationText = locCtrl.text; reporterName = nameCtrl.text; reporterRole = roleCtrl.text; });
                await _saveTextSettings(); Navigator.pop(context);
              }, child: const Text("Save & Close"))
            ],
          );
        });
      },
    );
  }

  void _toggleDualScreenAndPickMedia() async {
    setState(() => isMenuOpen = false);
    if (isDualScreenMode) {
      setState(() { isDualScreenMode = false; dualMediaList.clear(); _bottomAdVideoController?.dispose(); _bottomAdVideoController = null; });
      return;
    }
    try {
      final List<XFile> medias = await _picker.pickMultipleMedia();
      if (medias.isNotEmpty && mounted) {
        dualMediaList = medias.map((e) => e.path).toList(); currentDualMediaIndex = 0;
        setState(() { isDualScreenMode = true; isNewsBulletinMode = false; });
        _playDualMedia(dualMediaList[currentDualMediaIndex]);
      }
    } catch (e) {}
  }

  void _playDualMedia(String path) {
    if (path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov')) {
      _bottomAdVideoController?.dispose();
      _bottomAdVideoController = VideoPlayerController.file(File(path))..initialize().then((_) { 
        if (mounted) { _bottomAdVideoController!.setLooping(true); _bottomAdVideoController!.setVolume(1.0); _bottomAdVideoController!.play(); setState(() {}); }
      });
    } else { _bottomAdVideoController?.dispose(); _bottomAdVideoController = null; setState(() {}); }
  }

  void _prevDualMedia() {
    if (dualMediaList.isEmpty) return;
    currentDualMediaIndex = (currentDualMediaIndex - 1) < 0 ? dualMediaList.length - 1 : currentDualMediaIndex - 1;
    _playDualMedia(dualMediaList[currentDualMediaIndex]);
  }

  void _nextDualMedia() {
    if (dualMediaList.isEmpty) return;
    currentDualMediaIndex = (currentDualMediaIndex + 1) % dualMediaList.length;
    _playDualMedia(dualMediaList[currentDualMediaIndex]);
  }

  void _toggleDualMediaPause() {
    if (_bottomAdVideoController != null) { _bottomAdVideoController!.value.isPlaying ? _bottomAdVideoController!.pause() : _bottomAdVideoController!.play(); setState(() {}); }
  }

  Future<void> _startLiveAndLock() async {
    await _saveLinks();
    
    String cableUrl = cableRtmpController.text.trim();
    String restreamUrl = restreamRtmpController.text.trim();
    String satUrl = satelliteSrtController.text.trim();

    if (cableUrl.isEmpty && restreamUrl.isEmpty && satUrl.isEmpty) {
      _showMultiStreamDialog();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("దయచేసి ఏదైనా ఒక లైవ్ లింక్ ఇచ్చి మళ్ళీ GO LIVE నొక్కండి."), backgroundColor: Colors.red));
      return;
    }
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) await Permission.microphone.request();
    
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
    
    bool success = await StreamServiceManager.startLiveStream(cableUrl, restreamUrl, satUrl, isNoiseCancellationEnabled);
    if (success) {
      setState(() {
        isLiveBroadcasting = true;
        isLivePaused = false;
        hideControls = true;
        isMenuOpen = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ రికార్డింగ్ ప్రారంభమైంది!"), backgroundColor: Colors.green));
    }
  }

  Future<void> _stopLiveStream() async {
    bool success = await StreamServiceManager.stopLiveStream();
    if (success) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      setState(() {
        isLiveBroadcasting = false;
        isLivePaused = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ ప్రసారం నిలిపివేయబడింది."), backgroundColor: Colors.blue));
    }
  }

  Future<void> _togglePauseLive() async {
    setState(() => isLivePaused = !isLivePaused);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isLivePaused ? "లైవ్ పాజ్ చేయబడింది." : "లైవ్ మళ్లీ మొదలైంది!"), backgroundColor: Colors.orange));
  }

  Future<void> _pickLocalGalleryVideos(StateSetter setDialogState) async {
    try {
      final List<XFile> medias = await _picker.pickMultipleMedia();
      if (medias.isNotEmpty && mounted) {
        List<String> validVideos = medias.where((m) => m.path.toLowerCase().endsWith('.mp4') || m.path.toLowerCase().endsWith('.mkv') || m.path.toLowerCase().endsWith('.mov')).map((e) => e.path).toList();
        
        setState(() {
          localVideoPlaylist = validVideos;
          currentLocalVideoIndex = 0;
        });
        setDialogState(() {}); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${validVideos.length} వీడియోలు సెలెక్ట్ అయ్యాయి.", style: const TextStyle(fontWeight: FontWeight.bold))));
      }
    } catch (e) {}
  }

  Future<void> _playLocalPlaylist() async {
    if (localVideoPlaylist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ముందుగా గ్యాలరీ నుండి వీడియోలు ఎంచుకోండి."), backgroundColor: Colors.red));
      return;
    }
    Navigator.pop(context); 
    _startVlcPlayback(File(localVideoPlaylist[currentLocalVideoIndex]));
  }

  Future<void> _startVlcPlayback(File file) async {
    _bulletinVideoController?.stopRendererScanning();
    _bulletinVideoController?.dispose();

    _bulletinVideoController = VlcPlayerController.file(
      file,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(),
    );

    _bulletinVideoController?.addListener(_vlcListener);

    setState(() {
      isNewsBulletinMode = true;
      isDualScreenMode = false;
      hideControls = true;
      isLocalPlaylistPlaying = true;
    });
  }

  void _vlcListener() {
    if (!mounted) return;
    if (_bulletinVideoController != null) {
      if (_bulletinVideoController!.value.playingState == PlayingState.ended) {
        _bulletinVideoController!.removeListener(_vlcListener); 
        _playNextInPlaylist();
      }
    }
  }

  void _playNextInPlaylist() {
    if (isLocalPlaylistPlaying && currentLocalVideoIndex < localVideoPlaylist.length - 1) {
      currentLocalVideoIndex++;
      _startVlcPlayback(File(localVideoPlaylist[currentLocalVideoIndex]));
    } else {
      setState(() {
        isLocalPlaylistPlaying = false;
        isNewsBulletinMode = false;
        hideControls = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ప్లేలిస్ట్ పూర్తయింది. కెమెరా మోడ్ ఆక్టివేట్ అయ్యింది."), backgroundColor: Colors.blue));
    }
  }

  void _showMultiStreamDialog() {
    setState(() => isMenuOpen = false);
    showDialog(
      context: context, 
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text("Live Links Setup", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                _buildLinkEditor("1. Primary Live Stream (RTMP / RTMPS / SRT / HLS)", cableRtmpController),
                const Divider(color: Colors.white24, height: 15),
                _buildLinkEditor("2. Secondary Live Stream (RTMP / RTMPS / SRT / HLS)", restreamRtmpController),
                const Divider(color: Colors.white24, height: 15),
                _buildLinkEditor("3. Satellite / Backup Stream (RTMP / RTMPS / SRT / HLS)", satelliteSrtController),
                const Divider(color: Colors.white24, height: 15),
                
                const Text("4. Play Gallery Videos (HD, 4K Playlist)", style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Row(children: [
                  Expanded(child: Text(localVideoPlaylist.isNotEmpty ? "${localVideoPlaylist.length} Videos Selected" : "గ్యాలరీ నుండి వీడియోలు ఎంచుకోండి...", style: const TextStyle(color: Colors.yellow, fontSize: 11))),
                  ElevatedButton.icon(
                    onPressed: () => _pickLocalGalleryVideos(setDialogState),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                    icon: const Icon(Icons.video_library, size: 16, color: Colors.white), 
                    label: const Text("PICK VIDEOS", style: TextStyle(color: Colors.white, fontSize: 10))
                  )
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, padding: const EdgeInsets.symmetric(vertical: 10)),
                    onPressed: _playLocalPlaylist,
                    icon: const Icon(Icons.playlist_play, color: Colors.white, size: 20),
                    label: const Text("PLAY GALLERY PLAYLIST", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                  )
                ),

                const Divider(color: Colors.white24, height: 15),
                
                const Text("5. Play YouTube Video (Govt/Public Live)", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Row(children: [
                  Expanded(child: TextField(controller: youtubeVideoUrlCtrl, style: const TextStyle(color: Colors.yellow, fontSize: 12), decoration: const InputDecoration(hintText: "Paste YouTube Link here...", hintStyle: TextStyle(color: Colors.white30), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))))),
                  IconButton(icon: const Icon(Icons.save, color: Colors.blueAccent, size: 22), onPressed: () async { await _saveLinks(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"))); }),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, padding: const EdgeInsets.symmetric(vertical: 10)),
                    onPressed: () { Navigator.pop(context); _startYoutubeVideo(youtubeVideoUrlCtrl.text.trim()); },
                    icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                    label: const Text("PLAY YOUTUBE LINK", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                  )
                ),

                const Divider(color: Colors.white24, height: 15),
                
                const Text("6. Play Network URL (MP4/M3U8)", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                const SizedBox(height: 5),
                Row(children: [
                  Expanded(child: TextField(controller: networkVideoUrlCtrl, style: const TextStyle(color: Colors.yellow, fontSize: 12), decoration: const InputDecoration(hintText: "Paste MP4 Link here...", hintStyle: TextStyle(color: Colors.white30), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))))),
                  IconButton(icon: const Icon(Icons.save, color: Colors.blueAccent, size: 22), onPressed: () async { await _saveLinks(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"))); }),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.symmetric(vertical: 10)),
                    onPressed: () { Navigator.pop(context); _startNetworkBulletin(networkVideoUrlCtrl.text.trim()); },
                    icon: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                    label: const Text("PLAY NETWORK LINK", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
                  )
                ),
              ])
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white)))
            ]
          );
        });
      }
    );
  }

  Widget _buildLinkEditor(String label, TextEditingController controller) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
      Row(children: [
        Expanded(child: TextField(controller: controller, style: const TextStyle(color: Colors.yellow, fontSize: 12), decoration: const InputDecoration(hintText: "Paste stream URL here...", hintStyle: TextStyle(color: Colors.white30), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))))),
        IconButton(icon: const Icon(Icons.save, color: Colors.blueAccent, size: 22), onPressed: () async { await _saveLinks(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"))); }),
      ])
    ]);
  }

  // --- NEW ROBUST YOUTUBE METHOD WITH 15 SEC TIMEOUT ---
  Future<void> _startYoutubeVideo(String url) async {
    if (url.isEmpty) return;
    setState(() => isYoutubeLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ప్రభుత్వ / పబ్లిక్ యూట్యూబ్ లైవ్ లోడ్ అవుతోంది... దయచేసి వేచి ఉండండి."), backgroundColor: Colors.orange));
    
    try {
      var ytExplode = yt.YoutubeExplode(); 
      String? videoIdStr = yt.VideoId.parseVideoId(url);
      if (videoIdStr != null) {
        var vId = yt.VideoId(videoIdStr);
        // పెంచిన 15 సెకన్ల టైమౌట్
        var video = await ytExplode.videos.get(vId).timeout(const Duration(seconds: 15));
        String finalPlayUrl = "";
        
        if (video.isLive) { 
          finalPlayUrl = await ytExplode.videos.streamsClient.getHttpLiveStreamUrl(vId).timeout(const Duration(seconds: 15)); 
        } else { 
          var manifest = await ytExplode.videos.streamsClient.getManifest(vId).timeout(const Duration(seconds: 15)); 
          if (manifest.muxed.isNotEmpty) {
            finalPlayUrl = manifest.muxed.withHighestBitrate().url.toString(); 
          } else {
            finalPlayUrl = manifest.audioOnly.first.url.toString(); 
          }
        }
        ytExplode.close();
        
        if (finalPlayUrl.isNotEmpty) {
           _playInVlc(finalPlayUrl);
        } else {
           throw Exception("URL దొరకలేదు");
        }
      } else {
         throw Exception("తప్పు యూట్యూబ్ లింక్");
      }
    } catch (e) {
      setState(() { isYoutubeLoading = false; isNewsBulletinMode = false; hideControls = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("యూట్యూబ్ లింక్ లోడ్ అవ్వలేదు. దయచేసి 'flutter pub upgrade' కమాండ్ వాడండి. (Error: $e)"), backgroundColor: Colors.red, duration: const Duration(seconds: 6)));
    }
  }

  Future<void> _startNetworkBulletin(String url) async {
    if (url.isEmpty) return;
    _playInVlc(url);
  }

  // --- COMMON VLC PLAYER LOGIC WITH HTTP RECONNECT ---
  void _playInVlc(String playUrl) {
    _bulletinVideoController?.stopRendererScanning(); 
    _bulletinVideoController?.dispose();
    
    // యూట్యూబ్ లైవ్ కనెక్షన్ కట్ కాకుండా ఉండటానికి సెట్టింగ్స్
    final options = VlcPlayerOptions(
      advanced: VlcAdvancedOptions([
        VlcAdvancedOptions.networkCaching(3000), // 3 సెకన్ల బఫర్
      ]),
      http: VlcHttpOptions([
        VlcHttpOptions.httpReconnect(true), // ఆటో రీకనెక్ట్
      ]),
    );
    
    _bulletinVideoController = VlcPlayerController.network(
      playUrl,
      hwAcc: HwAcc.auto,
      autoPlay: true,
      options: options,
    );
    
    setState(() { 
      isNewsBulletinMode = true; 
      isDualScreenMode = false; 
      hideControls = true; 
      isLocalPlaylistPlaying = false;
      isYoutubeLoading = false;
    }); 
  }

  void _toggleRotation() {
    setState(() {
      isMenuOpen = false;
      isLandscape = !isLandscape;
      if (isLandscape) { SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]); } 
      else { SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); }
    });
  }

  Widget _buildFloatingBtn(String heroTag, IconData icon, String label, Color color, VoidCallback onPressed) {
    return FloatingActionButton.extended(
      heroTag: heroTag, backgroundColor: color, onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMenuButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade800, child: Icon(icon, color: color, size: 28)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isScreenLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    double screenW = MediaQuery.of(context).size.width; double screenH = MediaQuery.of(context).size.height;
    double tickerH = 55.0; double topAreaH = screenH - tickerH;

    double camW = 1080; double camH = 1920;
    if (_isCameraInitialized && controller != null && controller!.value.isInitialized) {
      final previewSize = controller!.value.previewSize;
      if (previewSize != null) { camW = previewSize.width; camH = previewSize.height; if (camW < camH) { double temp = camW; camW = camH; camH = temp; } }
    }
    double finalCamW = isScreenLandscape ? camW : camH; double finalCamH = isScreenLandscape ? camH : camW;

    Widget phoneCameraWidget = (!isCameraVisible) ? Container(color: Colors.transparent) : (_isCameraInitialized && controller != null && controller!.value.isInitialized)
      ? GestureDetector(
          onScaleStart: (details) => _baseScale = _currentZoomLevel,
          onScaleUpdate: (details) async {
            if (controller == null || !controller!.value.isInitialized) return;
            double zoom = _baseScale * details.scale;
            if (zoom < _minZoomLevel) zoom = _minZoomLevel; if (zoom > _maxZoomLevel) zoom = _maxZoomLevel;
            setState(() => _currentZoomLevel = zoom); await controller?.setZoomLevel(zoom);
          },
          child: ClipRect(child: SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: finalCamW, height: finalCamH, child: CameraPreview(controller!)))))
        )
      : const Center(child: CircularProgressIndicator(color: Colors.amber));

    Widget actualCameraWidget = isLivePaused 
      ? Container(color: Colors.black, child: const Center(child: Text("LIVE PAUSED", style: TextStyle(color: Colors.redAccent, fontSize: 30, fontWeight: FontWeight.bold))))
      : (isExternalIpCamMode && _ipCamController != null && _ipCamController!.value.isInitialized) ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _ipCamController!.value.size.width, height: _ipCamController!.value.size.height, child: VideoPlayer(_ipCamController!))))
      : (isDroneCamMode && _droneCamController != null && _droneCamController!.value.isInitialized) ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _droneCamController!.value.size.width, height: _droneCamController!.value.size.height, child: VideoPlayer(_droneCamController!))))
      : (isUsbCamMode && _usbTextureId != null) ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: 1920, height: 1080, child: Texture(textureId: _usbTextureId!))))
      : phoneCameraWidget;

    Widget staticReporterBadge = Column(
      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
      children: [
        if (watermarkText.isNotEmpty) Container(color: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text(watermarkText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
        Container(color: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
        const SizedBox(height: 2),
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13.0))),
        Container(color: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0)))
      ]
    );

    Widget channelLogoWidget = channelLogoPath.isNotEmpty
        ? SizedBox(width: 70, height: 70, child: channelLogoPath.toLowerCase().endsWith('.mp4') ? (_logoVideoCtrl != null && _logoVideoCtrl!.value.isInitialized ? VideoPlayer(_logoVideoCtrl!) : const SizedBox()) : Image.file(File(channelLogoPath), fit: BoxFit.contain, filterQuality: FilterQuality.high))
        : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)), child: const Text("SS YATRA TV", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)));

    Widget positionedLogoWidget = Positioned(
      top: (logoPosition == 0 || logoPosition == 1) ? 15.0 : null, bottom: (logoPosition == 2 || logoPosition == 3) ? 65.0 : null,
      left: (logoPosition == 0 || logoPosition == 2) ? 15.0 : null, right: (logoPosition == 1 || logoPosition == 3) ? 15.0 : null,
      child: channelLogoWidget,
    );

    final List<Color> bgColors = [const Color(0xFF0D47A1), Colors.red.shade900, Colors.purple.shade900, Colors.teal.shade900];

    bool showAds = isAdCurrentlyShowing;
    double lAdW = 0, rAdW = 0, bAdH = 0; double vW = screenW, vH = topAreaH, vLeft = 0;

    if (showAds) {
      if (adShapeMode == 0) { 
        double adW = screenW * 0.20; vW = screenW - adW; vH = vW * (9 / 16); bAdH = topAreaH - vH;
        if (bAdH < topAreaH * 0.15) { bAdH = topAreaH * 0.15; vH = topAreaH - bAdH; vW = vH * (16 / 9); adW = screenW - vW; }
        if (isLBandRight) { lAdW = 0; rAdW = adW; vLeft = 0; } else { lAdW = adW; rAdW = 0; vLeft = adW; }
      } else if (adShapeMode == 1) { 
        lAdW = screenW * 0.18; rAdW = screenW * 0.18; vW = screenW - lAdW - rAdW; vH = topAreaH; vLeft = lAdW; bAdH = 0;
      } else if (adShapeMode == 2) { 
        lAdW = screenW * 0.15; rAdW = screenW * 0.15; vW = screenW - lAdW - rAdW; vH = vW * (9 / 16); bAdH = topAreaH - vH;
        if (bAdH < topAreaH * 0.15) { bAdH = topAreaH * 0.15; vH = topAreaH - bAdH; vW = vH * (16 / 9); lAdW = (screenW - vW) / 2; rAdW = lAdW; }
        vLeft = lAdW;
      }
    }

    Widget mainPlayer = isNewsBulletinMode && _bulletinVideoController != null
        ? SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 1920,
                height: 1080,
                child: VlcPlayer(
                  controller: _bulletinVideoController!,
                  aspectRatio: 16 / 9,
                  placeholder: const Center(child: CircularProgressIndicator(color: Colors.red)),
                )
              )
            )
          )
        : actualCameraWidget;

    if (isDualScreenMode && dualMediaList.isNotEmpty) {
      mainPlayer = isScreenLandscape ? Row(children: [Expanded(child: actualCameraWidget), Container(width: 3, color: Colors.amberAccent), Expanded(child: GestureDetector(onTapUp: (details) { double dx = details.localPosition.dx; if (dx < screenW/6) { _prevDualMedia(); } else if (dx > screenW/3) { _nextDualMedia(); } else { _toggleDualMediaPause(); } }, child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bottomAdVideoController!.value.size.width, height: _bottomAdVideoController!.value.size.height, child: VideoPlayer(_bottomAdVideoController!))) : Image.file(File(dualMediaList[currentDualMediaIndex]), fit: BoxFit.cover, width: double.infinity, height: double.infinity)))]) : Column(children: [Expanded(flex: 4, child: actualCameraWidget), Expanded(flex: 4, child: GestureDetector(onTapUp: (details) { double dx = details.localPosition.dx; if (dx < screenW/3) { _prevDualMedia(); } else if (dx > screenW*2/3) { _nextDualMedia(); } else { _toggleDualMediaPause(); } }, child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bottomAdVideoController!.value.size.width, height: _bottomAdVideoController!.value.size.height, child: VideoPlayer(_bottomAdVideoController!))) : Image.file(File(dualMediaList[currentDualMediaIndex]), fit: BoxFit.cover, width: double.infinity, height: double.infinity)))]);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false, bottom: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() { isMenuOpen = false; hideControls = !hideControls; }),
          child: Stack(
            children: [
              AnimatedPositioned(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut, left: showAds ? vLeft : 0, top: 0, width: showAds ? vW : screenW, height: showAds ? vH : topAreaH, child: ClipRect(child: isYoutubeLoading ? const Center(child: CircularProgressIndicator(color: Colors.red)) : mainPlayer)),
              positionedLogoWidget,
              if (!isNewsBulletinMode && !isDualScreenMode) Positioned(bottom: 65, left: 15.0, child: staticReporterBadge),
              
              AnimatedPositioned(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut, left: showAds && lAdW > 0 ? 0 : -screenW * 0.25, top: 0, width: lAdW > 0 ? lAdW : screenW * 0.20, height: topAreaH, child: GestureDetector(onTap: () => _pickAds('left'), onLongPress: () => _manageAdsDialog('left'), child: Container(color: Colors.black, child: leftAdPaths.isNotEmpty ? (_leftAdVideoCtrl != null && _leftAdVideoCtrl!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _leftAdVideoCtrl!.value.size.width, height: _leftAdVideoCtrl!.value.size.height, child: VideoPlayer(_leftAdVideoCtrl!))) : SizedBox.expand(child: Image.file(File(leftAdPaths[leftAdIndex]), fit: BoxFit.fill))) : const Center(child: Text("LEFT ADS", style: TextStyle(color: Colors.white, fontSize: 10)))))),
              AnimatedPositioned(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut, right: showAds && rAdW > 0 ? 0 : -screenW * 0.25, top: 0, width: rAdW > 0 ? rAdW : screenW * 0.20, height: topAreaH, child: GestureDetector(onTap: () => _pickAds('right'), onLongPress: () => _manageAdsDialog('right'), child: Container(color: Colors.black, child: rightAdPaths.isNotEmpty ? (_rightAdVideoCtrl != null && _rightAdVideoCtrl!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _rightAdVideoCtrl!.value.size.width, height: _rightAdVideoCtrl!.value.size.height, child: VideoPlayer(_rightAdVideoCtrl!))) : SizedBox.expand(child: Image.file(File(rightAdPaths[rightAdIndex]), fit: BoxFit.fill))) : const Center(child: Text("RIGHT ADS", style: TextStyle(color: Colors.white, fontSize: 10)))))),
              AnimatedPositioned(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut, left: showAds ? vLeft : 0, top: showAds && bAdH > 0 ? vH : topAreaH + 50, width: showAds ? vW : screenW, height: bAdH > 0 ? bAdH : 50, child: GestureDetector(onTap: () => _pickAds('bottom'), onLongPress: () => _manageAdsDialog('bottom'), child: Container(color: Colors.black, child: bottomAdPaths.isNotEmpty ? (_bottomAdVideoCtrlForAds != null && _bottomAdVideoCtrlForAds!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _bottomAdVideoCtrlForAds!.value.size.width, height: _bottomAdVideoCtrlForAds!.value.size.height, child: VideoPlayer(_bottomAdVideoCtrlForAds!))) : SizedBox.expand(child: Image.file(File(bottomAdPaths[bottomAdIndex]), fit: BoxFit.fill))) : const Center(child: Text("BOTTOM ADS", style: TextStyle(color: Colors.white, fontSize: 11)))))),

              Positioned(
                bottom: 0, left: 0, right: 0, height: tickerH,
                child: Container(
                  decoration: BoxDecoration(color: bgColors[_tickerBgColorIndex % bgColors.length], border: Border.all(color: Colors.amber.shade400, width: 1.5)),
                  child: Row(children: [
                    Container(width: 95, color: Colors.red.shade900, alignment: Alignment.center, child: const Text("BREAKING\nNEWS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
                    Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 45.0)))
                  ]),
                ),
              ),

              if (!hideControls && isMenuOpen)
                Positioned.fill(
                  child: Container(
                    color: Colors.black87,
                    child: Center(
                      child: Wrap(
                        alignment: WrapAlignment.center, spacing: 30, runSpacing: 35,
                        children: [
                          _buildMenuButton(Icons.live_tv, "Live Links", Colors.redAccent, _showMultiStreamDialog),
                          _buildMenuButton(Icons.dashboard_customize, "PCR Board", Colors.yellowAccent, () { setState(() => isMenuOpen = false); Navigator.push(context, MaterialPageRoute(builder: (context) => const MasterPCRBoard())); }),
                          _buildMenuButton(Icons.bar_chart, "Election Results", Colors.blueAccent, () { setState(() => isMenuOpen = false); Navigator.push(context, MaterialPageRoute(builder: (context) => const ElectionBoardScreen())); }),
                          _buildMenuButton(Icons.flip_camera_android, "Phone Cam", Colors.white, _switchCamera),
                          _buildMenuButton(isCameraVisible ? Icons.videocam_off : Icons.videocam, isCameraVisible ? "Cam OFF" : "Cam ON", Colors.greenAccent, _toggleCameraVisibility),
                          _buildMenuButton(Icons.video_call, "Ext. Cams", Colors.cyanAccent, _showExternalCamsDialog),
                          _buildMenuButton(Icons.grid_on, "Dual Screen", Colors.orangeAccent, _toggleDualScreenAndPickMedia),
                          _buildMenuButton(Icons.visibility, adDisplayMode == 0 ? "Ads OFF" : (adDisplayMode == 1 ? "Ads ON" : "Auto Ads"), Colors.redAccent, _toggleAdMode),
                          _buildMenuButton(Icons.dashboard, adShapeMode == 0 ? "Shape: L-Band" : (adShapeMode == 1 ? "Shape: 2-Sides" : "Shape: U-Band"), Colors.orangeAccent, _toggleAdShapeMode),
                          _buildMenuButton(Icons.picture_in_picture_alt, "Logo Pos", Colors.lightGreenAccent, _changeLogoPosition),
                          if (adShapeMode == 0) _buildMenuButton(Icons.swap_horiz, "L-Band L/R", Colors.orangeAccent, _toggleLBandDirection),
                          _buildMenuButton(Icons.screen_rotation, "Rotate", Colors.purpleAccent, _toggleRotation),
                          _buildMenuButton(Icons.settings, "Settings", Colors.blue, _showEditDialog),
                        ]
                      ),
                    ),
                  ),
                ),

              if (!hideControls)
                Positioned(
                  bottom: 75, right: 15,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isLiveBroadcasting) ...[
                        _buildFloatingBtn("main_stop_live", Icons.stop, "Live Stop", Colors.red, _stopLiveStream),
                        const SizedBox(width: 10),
                        _buildFloatingBtn("main_pause_live", isLivePaused ? Icons.play_arrow : Icons.pause, isLivePaused ? "Resume" : "Pause", Colors.orange, _togglePauseLive),
                      ] else ...[
                        _buildFloatingBtn("main_go_live", Icons.sensors, "GO LIVE", Colors.green.shade800, _startLiveAndLock),
                      ],
                      const SizedBox(width: 10),
                      FloatingActionButton(
                        heroTag: 'main_menu_btn', backgroundColor: Colors.blue.shade900,
                        onPressed: () => setState(() => isMenuOpen = !isMenuOpen),
                        child: Icon(isMenuOpen ? Icons.close : Icons.menu, color: Colors.white),
                      )
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// --- 2. MASTER PCR BOARD SCREEN 
// ============================================================================

class MasterPCRBoard extends StatefulWidget {
  const MasterPCRBoard({Key? key}) : super(key: key);

  @override
  State<MasterPCRBoard> createState() => _MasterPCRBoardState();
}

class _MasterPCRBoardState extends State<MasterPCRBoard> {
  final Map<String, VlcPlayerController> _rtspControllers = {};
  CameraController? _phoneCamCtrl;
  List<CameraDescription> _cameras = [];

  bool hideControls = false; 
  bool isLiveBroadcasting = false;
  bool isLivePaused = false;
  bool isNoiseCancellationEnabled = true;
  
  int layoutMode = 6; 
  String mainCameraId = "REPORTER_CAM"; 
  List<String> hexCams = ["IP_1", "IP_2", "DRONE_1", "IP_3", "IP_4", "HDMI_1"]; 

  String channelLogoPath = "";
  int logoPosition = 0; 
  VideoPlayerController? _logoVideoCtrl;

  List<String> leftAdPaths = [];
  List<String> rightAdPaths = [];
  List<String> bottomAdPaths = [];
  int leftAdIndex = 0;
  int rightAdIndex = 0;
  int bottomAdIndex = 0;

  VideoPlayerController? _leftAdVideoCtrl;
  VideoPlayerController? _rightAdVideoCtrl;
  VideoPlayerController? _bottomAdVideoCtrlForAds;

  int adDisplayMode = 0;
  bool isAdCurrentlyShowing = false;
  Timer? _adCycleTimer;
  int adShapeMode = 0;
  bool isLBandRight = true;

  String breakingNewsText = "తాజా వార్తలు లోడ్ అవుతున్నాయి...";
  int _tickerBgColorIndex = 0;
  Timer? _tickerColorTimer;

  TextEditingController cableRtmpController = TextEditingController();
  TextEditingController restreamRtmpController = TextEditingController();
  TextEditingController satelliteSrtController = TextEditingController();

  final List<Color> bgColors = [const Color(0xFF0D47A1), Colors.red.shade900, Colors.purple.shade900, Colors.teal.shade900];

  final List<Map<String, dynamic>> cameraList = [
    {"id": "REPORTER_CAM", "name": "Reporter", "type": "PHONE", "active": true, "muted": false, "url": ""},
    {"id": "DRONE_1", "name": "DJI Drone", "type": "DRONE", "active": false, "muted": true, "url": "rtsp://192.168.1.1:554/live"}, 
    {"id": "HDMI_1", "name": "Sony Cam 1", "type": "USB", "active": false, "muted": false, "url": ""},
    {"id": "IP_1", "name": "CCTV Left", "type": "IP", "active": false, "muted": true, "url": "https://www.youtube.com/watch?v=5qap5aO4i9A"}, 
    {"id": "IP_2", "name": "CCTV Right", "type": "IP", "active": false, "muted": true, "url": "rtsp://192.168.1.100:8080/video"},
    {"id": "IP_3", "name": "Mobile WiFi 1", "type": "IP", "active": false, "muted": true, "url": "rtsp://192.168.1.101:8080/video"},
    {"id": "IP_4", "name": "Mobile WiFi 2", "type": "IP", "active": false, "muted": true, "url": "rtsp://192.168.1.102:8080/video"},
  ];

  @override
  void initState() {
    super.initState();
    _initPhoneCamera();
    _tickerColorTimer = Timer.periodic(const Duration(seconds: 2), (timer) { if (mounted) setState(() => _tickerBgColorIndex++); });
    _loadSavedData();
  }

  Future<void> _initPhoneCamera() async {
    try { 
      _cameras = await availableCameras(); 
      if (_cameras.isNotEmpty) {
        CameraDescription? cam = _cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => _cameras.first);
        _phoneCamCtrl = CameraController(cam, ResolutionPreset.max, enableAudio: true); 
        await _phoneCamCtrl!.initialize(); 
        if (mounted) setState(() {}); 
      }
    } catch (e) {}
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      layoutMode = prefs.getInt('pcr_layoutMode') ?? 6;
      adShapeMode = prefs.getInt('adShapeMode') ?? 0;
      logoPosition = prefs.getInt('logoPosition') ?? 0;
      isNoiseCancellationEnabled = prefs.getBool('noiseCancel') ?? true;
      breakingNewsText = prefs.getString('breakingNewsText') ?? "తాజా వార్తలు లోడ్ అవుతున్నాయి...";

      cableRtmpController.text = prefs.getString('cableRtmp') ?? "";
      restreamRtmpController.text = prefs.getString('restreamRtmp') ?? "";
      satelliteSrtController.text = prefs.getString('satelliteSrt') ?? "";

      String savedLogo = prefs.getString('channelLogoPath') ?? "";
      if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) _setLogo(savedLogo);

      leftAdPaths = (prefs.getStringList('leftAdPaths') ?? []).where((p) => File(p).existsSync()).toList();
      rightAdPaths = (prefs.getStringList('rightAdPaths') ?? []).where((p) => File(p).existsSync()).toList();
      bottomAdPaths = (prefs.getStringList('bottomAdPaths') ?? []).where((p) => File(p).existsSync()).toList();

      if (leftAdPaths.isNotEmpty) _initAdVideo('left');
      if (rightAdPaths.isNotEmpty) _initAdVideo('right');
      if (bottomAdPaths.isNotEmpty) _initAdVideo('bottom');
    });
  }

  void _setLogo(String path) {
    channelLogoPath = path;
    if (path.toLowerCase().endsWith('.mp4')) {
      _logoVideoCtrl?.dispose();
      _logoVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { 
        if (mounted) { _logoVideoCtrl!.setLooping(true); _logoVideoCtrl!.setVolume(0); _logoVideoCtrl!.play(); setState((){}); } 
      });
    } else { _logoVideoCtrl?.dispose(); _logoVideoCtrl = null; }
  }

  void _initAdVideo(String pos) {
    String path = "";
    if (pos == 'left' && leftAdPaths.isNotEmpty) path = leftAdPaths[leftAdIndex = leftAdIndex % leftAdPaths.length];
    if (pos == 'right' && rightAdPaths.isNotEmpty) path = rightAdPaths[rightAdIndex = rightAdIndex % rightAdPaths.length];
    if (pos == 'bottom' && bottomAdPaths.isNotEmpty) path = bottomAdPaths[bottomAdIndex = bottomAdIndex % bottomAdPaths.length];
    if (path.isEmpty) return;

    bool isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov') || path.toLowerCase().endsWith('.gif');
    if (pos == 'left') {
      _leftAdVideoCtrl?.dispose(); _leftAdVideoCtrl = null;
      if (isVideo) _leftAdVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { if(mounted){ _leftAdVideoCtrl!.setLooping(true); _leftAdVideoCtrl!.setVolume(0.0); _leftAdVideoCtrl!.play(); setState((){}); }});
    } else if (pos == 'right') {
      _rightAdVideoCtrl?.dispose(); _rightAdVideoCtrl = null;
      if (isVideo) _rightAdVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { if(mounted){ _rightAdVideoCtrl!.setLooping(true); _rightAdVideoCtrl!.setVolume(0.0); _rightAdVideoCtrl!.play(); setState((){}); }});
    } else if (pos == 'bottom') {
      _bottomAdVideoCtrlForAds?.dispose(); _bottomAdVideoCtrlForAds = null;
      if (isVideo) _bottomAdVideoCtrlForAds = VideoPlayerController.file(File(path))..initialize().then((_) { if(mounted){ _bottomAdVideoCtrlForAds!.setLooping(true); _bottomAdVideoCtrlForAds!.setVolume(0.0); _bottomAdVideoCtrlForAds!.play(); setState((){}); }});
    }
  }

  void _swapCamera(int gridIndex) {
    setState(() { String temp = mainCameraId; mainCameraId = hexCams[gridIndex]; hexCams[gridIndex] = temp; });
  }

  Future<void> _toggleRTSPCamera(String camId, String url, bool isActive, bool isMuted) async { 
    if (isActive) { 
      String finalUrl = url;
      if (url.contains("youtube.com") || url.contains("youtu.be")) {
        var ytExplode = yt.YoutubeExplode();
        try {
          String? videoIdStr = yt.VideoId.parseVideoId(url);
          if (videoIdStr != null) {
            var vId = yt.VideoId(videoIdStr); 
            var video = await ytExplode.videos.get(vId);
            if (video.isLive) { finalUrl = await ytExplode.videos.streamsClient.getHttpLiveStreamUrl(vId); } 
            else { var manifest = await ytExplode.videos.streamsClient.getManifest(vId); finalUrl = manifest.muxed.withHighestBitrate().url.toString(); }
          }
        } catch (e) {} finally { ytExplode.close(); }
      }
      setState(() { _rtspControllers[camId] = VlcPlayerController.network(finalUrl, hwAcc: HwAcc.full, autoPlay: true, options: VlcPlayerOptions()); _rtspControllers[camId]?.setVolume(isMuted ? 0 : 100); });
    } else { 
      _rtspControllers[camId]?.stopRendererScanning(); _rtspControllers[camId]?.dispose(); setState(() => _rtspControllers.remove(camId));
    } 
  }

  void _toggleMute(Map<String, dynamic> cam) { 
    setState(() { cam['muted'] = !cam['muted']; if (cam['active'] && (cam['type'] == 'IP' || cam['type'] == 'DRONE')) { _rtspControllers[cam['id']]?.setVolume(cam['muted'] ? 0 : 100); } }); 
  }

  Future<void> _startLiveAndLock() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cableRtmp', cableRtmpController.text);
    await prefs.setString('restreamRtmp', restreamRtmpController.text);
    await prefs.setString('satelliteSrt', satelliteSrtController.text);

    String cableUrl = cableRtmpController.text.trim();
    String restreamUrl = restreamRtmpController.text.trim();
    String satUrl = satelliteSrtController.text.trim();

    if (cableUrl.isEmpty && restreamUrl.isEmpty && satUrl.isEmpty) {
      _showMultiStreamDialog();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("దయచేసి ఏదైనా ఒక లైవ్ లింక్ ఇవ్వండి."), backgroundColor: Colors.red));
      return;
    }
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) await Permission.microphone.request();
    
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
    bool success = await StreamServiceManager.startLiveStream(cableUrl, restreamUrl, satUrl, isNoiseCancellationEnabled);
    if (success) {
      setState(() { isLiveBroadcasting = true; isLivePaused = false; hideControls = true; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ రికార్డింగ్ ప్రారంభమైంది!"), backgroundColor: Colors.green));
    }
  }

  Future<void> _stopLiveStream() async {
    bool success = await StreamServiceManager.stopLiveStream();
    if (success) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      setState(() { isLiveBroadcasting = false; isLivePaused = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ నిలిపివేయబడింది."), backgroundColor: Colors.blue));
    }
  }

  Future<void> _togglePauseLive() async {
    setState(() => isLivePaused = !isLivePaused);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isLivePaused ? "లైవ్ పాజ్ చేయబడింది." : "లైవ్ మళ్లీ మొదలైంది!"), backgroundColor: Colors.orange));
  }

  void _showMultiStreamDialog() {
    showDialog(
      context: context, 
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900], title: const Text("Live Links Setup", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                _buildLinkEditor("1. Primary Live Stream (RTMP / RTMPS / SRT / HLS)", cableRtmpController),
                const Divider(color: Colors.white24, height: 20),
                _buildLinkEditor("2. Secondary Live Stream (RTMP / RTMPS / SRT / HLS)", restreamRtmpController),
                const Divider(color: Colors.white24, height: 20),
                _buildLinkEditor("3. Satellite / Backup Stream (RTMP / RTMPS / SRT / HLS)", satelliteSrtController),
              ])
            ),
            actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white))) ]
          );
        });
      }
    );
  }

  Widget _buildLinkEditor(String label, TextEditingController controller) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
      Row(children: [
        Expanded(child: TextField(controller: controller, style: const TextStyle(color: Colors.yellow, fontSize: 12), decoration: const InputDecoration(hintText: "Paste stream URL here...", hintStyle: TextStyle(color: Colors.white30), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))))),
        IconButton(icon: const Icon(Icons.save, color: Colors.blueAccent, size: 22), onPressed: () async { SharedPreferences prefs = await SharedPreferences.getInstance(); await prefs.setString('cableRtmp', cableRtmpController.text); await prefs.setString('restreamRtmp', restreamRtmpController.text); await prefs.setString('satelliteSrt', satelliteSrtController.text); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"))); }),
      ])
    ]);
  }

  @override
  void dispose() {
    _phoneCamCtrl?.dispose();
    for (var controller in _rtspControllers.values) { controller.dispose(); } 
    _tickerColorTimer?.cancel(); _adCycleTimer?.cancel();
    _leftAdVideoCtrl?.dispose(); _rightAdVideoCtrl?.dispose(); _bottomAdVideoCtrlForAds?.dispose(); _logoVideoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenW = MediaQuery.of(context).size.width; double screenH = MediaQuery.of(context).size.height;
    double tickerH = 55.0; double topAreaH = screenH - tickerH;

    bool showAds = isAdCurrentlyShowing;
    double lAdW = 0, rAdW = 0, bAdH = 0; double vW = screenW, vH = topAreaH, vLeft = 0;

    if (showAds) {
      if (adShapeMode == 0) { 
        double adW = screenW * 0.20; vW = screenW - adW; vH = vW * (9 / 16); bAdH = topAreaH - vH;
        if (bAdH < topAreaH * 0.15) { bAdH = topAreaH * 0.15; vH = topAreaH - bAdH; vW = vH * (16 / 9); adW = screenW - vW; }
        if (isLBandRight) { lAdW = 0; rAdW = adW; vLeft = 0; } else { lAdW = adW; rAdW = 0; vLeft = adW; }
      } else if (adShapeMode == 1) { 
        lAdW = screenW * 0.18; rAdW = screenW * 0.18; vW = screenW - lAdW - rAdW; vH = topAreaH; vLeft = lAdW; bAdH = 0;
      } else if (adShapeMode == 2) { 
        lAdW = screenW * 0.15; rAdW = screenW * 0.15; vW = screenW - lAdW - rAdW; vH = vW * (9 / 16); bAdH = topAreaH - vH;
        if (bAdH < topAreaH * 0.15) { bAdH = topAreaH * 0.15; vH = topAreaH - bAdH; vW = vH * (16 / 9); lAdW = (screenW - vW) / 2; rAdW = lAdW; }
        vLeft = lAdW;
      }
    }

    Widget channelLogoWidget = channelLogoPath.isNotEmpty
        ? SizedBox(width: 70, height: 70, child: channelLogoPath.toLowerCase().endsWith('.mp4') ? (_logoVideoCtrl != null && _logoVideoCtrl!.value.isInitialized ? VideoPlayer(_logoVideoCtrl!) : const SizedBox()) : Image.file(File(channelLogoPath), fit: BoxFit.contain, filterQuality: FilterQuality.high))
        : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: Colors.red[900]?.withOpacity(0.9), child: const Text("SS YATRA TV", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)));

    Widget positionedLogoWidget = Positioned(
      top: (logoPosition == 0 || logoPosition == 1) ? 15.0 : null, bottom: (logoPosition == 2 || logoPosition == 3) ? 65.0 : null,
      left: (logoPosition == 0 || logoPosition == 2) ? 15.0 : null, right: (logoPosition == 1 || logoPosition == 3) ? 15.0 : null,
      child: channelLogoWidget,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => hideControls = !hideControls),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600), curve: Curves.easeInOut,
                left: showAds ? vLeft : 0, top: 0, width: showAds ? vW : screenW, height: showAds ? vH : topAreaH,
                child: ClipRect(child: isLivePaused ? Container(color: Colors.black, child: const Center(child: Text("LIVE PAUSED", style: TextStyle(color: Colors.redAccent, fontSize: 30, fontWeight: FontWeight.bold)))) : Row(
                  children: [
                    Expanded(flex: 5, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2)), child: _buildLiveFeed(mainCameraId))), Container(width: 2, color: Colors.white24), 
                    Expanded(flex: 6, child: Column(children: layoutMode == 4 ? [Expanded(child: Row(children: [Expanded(child: _buildHexBox(0)), Expanded(child: _buildHexBox(1))])), Expanded(child: Row(children: [Expanded(child: _buildHexBox(2)), Expanded(child: _buildHexBox(3))] ))] : [Expanded(child: Row(children: [Expanded(child: _buildHexBox(0)), Expanded(child: _buildHexBox(1)), Expanded(child: _buildHexBox(2))])), Expanded(child: Row(children: [Expanded(child: _buildHexBox(3)), Expanded(child: _buildHexBox(4)), Expanded(child: _buildHexBox(5))]))]))
                  ]
                )),
              ),
              
              positionedLogoWidget,

              AnimatedPositioned(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut, left: showAds && lAdW > 0 ? 0 : -screenW * 0.25, top: 0, width: lAdW > 0 ? lAdW : screenW * 0.20, height: topAreaH, child: Container(color: Colors.black, child: leftAdPaths.isNotEmpty ? (_leftAdVideoCtrl != null && _leftAdVideoCtrl!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _leftAdVideoCtrl!.value.size.width, height: _leftAdVideoCtrl!.value.size.height, child: VideoPlayer(_leftAdVideoCtrl!))) : SizedBox.expand(child: Image.file(File(leftAdPaths[leftAdIndex]), fit: BoxFit.fill))) : const SizedBox())),
              AnimatedPositioned(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut, right: showAds && rAdW > 0 ? 0 : -screenW * 0.25, top: 0, width: rAdW > 0 ? rAdW : screenW * 0.20, height: topAreaH, child: Container(color: Colors.black, child: rightAdPaths.isNotEmpty ? (_rightAdVideoCtrl != null && _rightAdVideoCtrl!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _rightAdVideoCtrl!.value.size.width, height: _rightAdVideoCtrl!.value.size.height, child: VideoPlayer(_rightAdVideoCtrl!))) : SizedBox.expand(child: Image.file(File(rightAdPaths[rightAdIndex]), fit: BoxFit.fill))) : const SizedBox())),
              AnimatedPositioned(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut, left: showAds ? vLeft : 0, top: showAds && bAdH > 0 ? vH : topAreaH + 50, width: showAds ? vW : screenW, height: bAdH > 0 ? bAdH : 50, child: Container(color: Colors.black, child: bottomAdPaths.isNotEmpty ? (_bottomAdVideoCtrlForAds != null && _bottomAdVideoCtrlForAds!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _bottomAdVideoCtrlForAds!.value.size.width, height: _bottomAdVideoCtrlForAds!.value.size.height, child: VideoPlayer(_bottomAdVideoCtrlForAds!))) : SizedBox.expand(child: Image.file(File(bottomAdPaths[bottomAdIndex]), fit: BoxFit.fill))) : const SizedBox())),

              Positioned(
                bottom: 0, left: 0, right: 0, height: tickerH,
                child: Container(
                  decoration: BoxDecoration(color: bgColors[_tickerBgColorIndex % bgColors.length], border: Border.all(color: Colors.amber.shade400, width: 1.5)),
                  child: Row(children: [
                    Container(width: 95, color: Colors.red.shade900, alignment: Alignment.center, child: const Text("BREAKING\nNEWS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
                    Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 45.0)))
                  ]),
                ),
              ),

              if (!hideControls)
                Positioned(
                  top: 15, left: 15,
                  child: Row(
                    children: [
                      FloatingActionButton(mini: true, backgroundColor: Colors.blueGrey, onPressed: () => Navigator.pop(context), child: const Icon(Icons.arrow_back, color: Colors.white)),
                      const SizedBox(width: 10),
                      GestureDetector(onTap: () { setState(() { layoutMode = layoutMode == 4 ? 6 : 4; }); SharedPreferences.getInstance().then((p) => p.setInt('pcr_layoutMode', layoutMode)); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(4)), child: Text("1+${layoutMode} LAYOUT", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)))),
                    ],
                  ),
                ),

              if (!hideControls)
                Positioned(
                  bottom: tickerH + 5, left: 0, right: 0,
                  child: Container(
                    height: 140, color: Colors.black87.withOpacity(0.95),
                    child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: cameraList.length, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), itemBuilder: (context, index) => _buildCompactCameraBox(cameraList[index])),
                  ),
                ),

              // === FLOATING CONTROLS IN PCR BOARD ===
              if (!hideControls)
                Positioned(
                  bottom: 160, right: 15,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isLiveBroadcasting) ...[
                        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: const StadiumBorder()), onPressed: _stopLiveStream, icon: const Icon(Icons.stop, color: Colors.white), label: const Text("STOP LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: const StadiumBorder()), onPressed: _togglePauseLive, icon: Icon(isLivePaused ? Icons.play_arrow : Icons.pause, color: Colors.white), label: Text(isLivePaused ? "RESUME" : "PAUSE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ] else ...[
                        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade900, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: const StadiumBorder()), onPressed: _startLiveAndLock, icon: const Icon(Icons.sensors, color: Colors.white), label: const Text("GO LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                      const SizedBox(width: 15),
                      Container(decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(15)), child: IconButton(iconSize: 32, icon: const Icon(Icons.settings_input_antenna, color: Colors.white), onPressed: _showMultiStreamDialog))
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHexBox(int index) { 
    return GestureDetector(onTap: () => _swapCamera(index), child: Container(decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.grey.shade800, width: 1)), child: Stack(children: [ Positioned.fill(child: _buildLiveFeed(hexCams[index])), Positioned(top: 2, left: 2, child: Container(padding: const EdgeInsets.all(2), color: Colors.black54, child: const Text("TAP TO SWAP", style: TextStyle(color: Colors.white, fontSize: 8)))) ]))); 
  }

  Widget _buildLiveFeed(String camId) { 
    var camData = cameraList.firstWhere((cam) => cam['id'] == camId, orElse: () => cameraList[0]); 
    if (camId == "REPORTER_CAM") { 
      if (_phoneCamCtrl != null && _phoneCamCtrl!.value.isInitialized) return CameraPreview(_phoneCamCtrl!); 
      return const Center(child: CircularProgressIndicator(color: Colors.red)); 
    } 
    if (camData['type'] == "IP" || camData['type'] == "DRONE") { 
      return _rtspControllers.containsKey(camId) ? VlcPlayer(controller: _rtspControllers[camId]!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.red))) : Container(color: Colors.black, child: const Center(child: Text("NO SIGNAL", style: TextStyle(color: Colors.red, fontSize: 10)))); 
    } 
    return Container(color: Colors.black, child: const Center(child: Text("NO SIGNAL", style: TextStyle(color: Colors.red, fontSize: 10)))); 
  }

  Widget _buildCompactCameraBox(Map<String, dynamic> cam) { 
    bool isLive = hexCams.contains(cam['id']) || (mainCameraId == cam['id']); bool isActive = cam['active']; bool isMuted = cam['muted']; 
    return Container(width: 100, margin: const EdgeInsets.only(right: 6), child: Column(children: [ Expanded(child: Container(decoration: BoxDecoration(color: Colors.black, border: Border.all(color: isLive ? Colors.red : (isActive ? Colors.green : Colors.grey.shade800), width: isLive ? 2.5 : 1)), child: Stack(children: [ Center(child: Text(isActive ? "Live" : "OFF", style: TextStyle(color: isActive ? Colors.greenAccent : Colors.red, fontSize: 10))), Positioned(top: 1, left: 1, child: Container(padding: const EdgeInsets.all(1), color: Colors.black54, child: Text(cam['type'], style: const TextStyle(color: Colors.yellow, fontSize: 7)))) ]))), const SizedBox(height: 2), Text(cam['name'], style: const TextStyle(color: Colors.white, fontSize: 9, overflow: TextOverflow.ellipsis)), Row(mainAxisAlignment: MainAxisAlignment.center, children: [ GestureDetector(onTap: () async { bool willBeActive = !isActive; setState(() { cam['active'] = willBeActive; }); if (cam['type'] == "IP" || cam['type'] == "DRONE") await _toggleRTSPCamera(cam['id'], cam['url'], willBeActive, cam['muted']); }, child: Icon(isActive ? Icons.power_settings_new : Icons.power_off, color: isActive ? Colors.green : Colors.red, size: 16)), const SizedBox(width: 5), GestureDetector(onTap: () => _toggleMute(cam), child: Icon(isMuted ? Icons.mic_off : Icons.mic, color: isMuted ? Colors.red : Colors.blueAccent, size: 16)), const SizedBox(width: 5), if (isActive) GestureDetector(onTap: () => setState(() { mainCameraId = cam['id']; }), child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2)), child: const Text("CUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8))))]) ])); 
  }
}

// ============================================================================
// --- 3. ELECTION BOARD SCREEN
// ============================================================================

class ElectionBoardScreen extends StatefulWidget {
  const ElectionBoardScreen({Key? key}) : super(key: key);

  @override
  State<ElectionBoardScreen> createState() => _ElectionBoardScreenState();
}

class _ElectionBoardScreenState extends State<ElectionBoardScreen> {
  int bjpSeats = 150;
  int tmcSeats = 103;
  int congSeats = 5;
  int leftSeats = 2;
  int othSeats = 2;

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  bool hideControls = false;
  bool isLiveBroadcasting = false;
  bool isLivePaused = false;
  bool isNoiseCancellationEnabled = true;

  String channelLogoPath = "";
  int logoPosition = 0; 
  VideoPlayerController? _logoVideoCtrl;

  List<String> leftAdPaths = [];
  List<String> rightAdPaths = [];
  List<String> bottomAdPaths = [];
  int leftAdIndex = 0;
  int rightAdIndex = 0;
  int bottomAdIndex = 0;

  VideoPlayerController? _leftAdVideoCtrl;
  VideoPlayerController? _rightAdVideoCtrl;
  VideoPlayerController? _bottomAdVideoCtrlForAds;

  int adDisplayMode = 0;
  bool isAdCurrentlyShowing = false;
  Timer? _adCycleTimer;
  int adShapeMode = 0;
  bool isLBandRight = true;

  String breakingNewsText = "తాజా వార్తలు లోడ్ అవుతున్నాయి...";
  int _tickerBgColorIndex = 0;
  Timer? _tickerColorTimer;

  TextEditingController cableRtmpController = TextEditingController();
  TextEditingController restreamRtmpController = TextEditingController();
  TextEditingController satelliteSrtController = TextEditingController();

  final List<Color> bgColors = [const Color(0xFF0D47A1), Colors.red.shade900, Colors.purple.shade900, Colors.teal.shade900];

  @override
  void initState() {
    super.initState();
    _initReporterCamera();
    _tickerColorTimer = Timer.periodic(const Duration(seconds: 2), (timer) { if (mounted) setState(() => _tickerBgColorIndex++); });
    _loadSavedData();
  }

  Future<void> _initReporterCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        CameraDescription? frontCam;
        for (var cam in _cameras) {
          if (cam.lensDirection == CameraLensDirection.front) { frontCam = cam; break; }
        }
        _cameraController = CameraController(frontCam ?? _cameras.first, ResolutionPreset.high, enableAudio: true);
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {}
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      adShapeMode = prefs.getInt('adShapeMode') ?? 0;
      logoPosition = prefs.getInt('logoPosition') ?? 0;
      isNoiseCancellationEnabled = prefs.getBool('noiseCancel') ?? true;
      breakingNewsText = prefs.getString('breakingNewsText') ?? "తాజా వార్తలు లోడ్ అవుతున్నాయి...";

      cableRtmpController.text = prefs.getString('cableRtmp') ?? "";
      restreamRtmpController.text = prefs.getString('restreamRtmp') ?? "";
      satelliteSrtController.text = prefs.getString('satelliteSrt') ?? "";

      String savedLogo = prefs.getString('channelLogoPath') ?? "";
      if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) _setLogo(savedLogo);

      leftAdPaths = (prefs.getStringList('leftAdPaths') ?? []).where((p) => File(p).existsSync()).toList();
      rightAdPaths = (prefs.getStringList('rightAdPaths') ?? []).where((p) => File(p).existsSync()).toList();
      bottomAdPaths = (prefs.getStringList('bottomAdPaths') ?? []).where((p) => File(p).existsSync()).toList();

      if (leftAdPaths.isNotEmpty) _initAdVideo('left');
      if (rightAdPaths.isNotEmpty) _initAdVideo('right');
      if (bottomAdPaths.isNotEmpty) _initAdVideo('bottom');
    });
  }

  void _setLogo(String path) {
    channelLogoPath = path;
    if (path.toLowerCase().endsWith('.mp4')) {
      _logoVideoCtrl?.dispose();
      _logoVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { 
        if (mounted) { _logoVideoCtrl!.setLooping(true); _logoVideoCtrl!.setVolume(0); _logoVideoCtrl!.play(); setState((){}); } 
      });
    } else { _logoVideoCtrl?.dispose(); _logoVideoCtrl = null; }
  }

  void _initAdVideo(String pos) {
    String path = "";
    if (pos == 'left' && leftAdPaths.isNotEmpty) path = leftAdPaths[leftAdIndex = leftAdIndex % leftAdPaths.length];
    if (pos == 'right' && rightAdPaths.isNotEmpty) path = rightAdPaths[rightAdIndex = rightAdIndex % rightAdPaths.length];
    if (pos == 'bottom' && bottomAdPaths.isNotEmpty) path = bottomAdPaths[bottomAdIndex = bottomAdIndex % bottomAdPaths.length];
    if (path.isEmpty) return;

    bool isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov') || path.toLowerCase().endsWith('.gif');
    if (pos == 'left') {
      _leftAdVideoCtrl?.dispose(); _leftAdVideoCtrl = null;
      if (isVideo) _leftAdVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { if(mounted){ _leftAdVideoCtrl!.setLooping(true); _leftAdVideoCtrl!.setVolume(0.0); _leftAdVideoCtrl!.play(); setState((){}); }});
    } else if (pos == 'right') {
      _rightAdVideoCtrl?.dispose(); _rightAdVideoCtrl = null;
      if (isVideo) _rightAdVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { if(mounted){ _rightAdVideoCtrl!.setLooping(true); _rightAdVideoCtrl!.setVolume(0.0); _rightAdVideoCtrl!.play(); setState((){}); }});
    } else if (pos == 'bottom') {
      _bottomAdVideoCtrlForAds?.dispose(); _bottomAdVideoCtrlForAds = null;
      if (isVideo) _bottomAdVideoCtrlForAds = VideoPlayerController.file(File(path))..initialize().then((_) { if(mounted){ _bottomAdVideoCtrlForAds!.setLooping(true); _bottomAdVideoCtrlForAds!.setVolume(0.0); _bottomAdVideoCtrlForAds!.play(); setState((){}); }});
    }
  }

  Future<void> _startLiveAndLock() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cableRtmp', cableRtmpController.text);
    await prefs.setString('restreamRtmp', restreamRtmpController.text);
    await prefs.setString('satelliteSrt', satelliteSrtController.text);

    String cableUrl = cableRtmpController.text.trim();
    String restreamUrl = restreamRtmpController.text.trim();
    String satUrl = satelliteSrtController.text.trim();

    if (cableUrl.isEmpty && restreamUrl.isEmpty && satUrl.isEmpty) {
      _showMultiStreamDialog();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("దయచేసి ఏదైనా ఒక లైవ్ లింక్ ఇవ్వండి."), backgroundColor: Colors.red));
      return;
    }
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) await Permission.microphone.request();
    
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
    bool success = await StreamServiceManager.startLiveStream(cableUrl, restreamUrl, satUrl, isNoiseCancellationEnabled);
    if (success) {
      setState(() { isLiveBroadcasting = true; isLivePaused = false; hideControls = true; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ రికార్డింగ్ ప్రారంభమైంది!"), backgroundColor: Colors.green));
    }
  }

  Future<void> _stopLiveStream() async {
    bool success = await StreamServiceManager.stopLiveStream();
    if (success) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      setState(() { isLiveBroadcasting = false; isLivePaused = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ నిలిపివేయబడింది."), backgroundColor: Colors.blue));
    }
  }

  Future<void> _togglePauseLive() async {
    setState(() => isLivePaused = !isLivePaused);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isLivePaused ? "లైవ్ పాజ్ చేయబడింది." : "లైవ్ మళ్లీ మొదలైంది!"), backgroundColor: Colors.orange));
  }

  void _showMultiStreamDialog() {
    showDialog(
      context: context, 
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900], title: const Text("Live Links Setup", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                _buildLinkEditor("1. Primary Live Stream (RTMP / RTMPS / SRT / HLS)", cableRtmpController),
                const Divider(color: Colors.white24, height: 20),
                _buildLinkEditor("2. Secondary Live Stream (RTMP / RTMPS / SRT / HLS)", restreamRtmpController),
                const Divider(color: Colors.white24, height: 20),
                _buildLinkEditor("3. Satellite / Backup Stream (RTMP / RTMPS / SRT / HLS)", satelliteSrtController),
              ])
            ),
            actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white))) ]
          );
        });
      }
    );
  }

  Widget _buildLinkEditor(String label, TextEditingController controller) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
      Row(children: [
        Expanded(child: TextField(controller: controller, style: const TextStyle(color: Colors.yellow, fontSize: 12), decoration: const InputDecoration(hintText: "Paste stream URL here...", hintStyle: TextStyle(color: Colors.white30), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))))),
        IconButton(icon: const Icon(Icons.save, color: Colors.blueAccent, size: 22), onPressed: () async { SharedPreferences prefs = await SharedPreferences.getInstance(); await prefs.setString('cableRtmp', cableRtmpController.text); await prefs.setString('restreamRtmp', restreamRtmpController.text); await prefs.setString('satelliteSrt', satelliteSrtController.text); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"))); }),
      ])
    ]);
  }

  @override
  void dispose() {
    _cameraController?.dispose(); 
    _tickerColorTimer?.cancel(); _adCycleTimer?.cancel();
    _leftAdVideoCtrl?.dispose(); _rightAdVideoCtrl?.dispose(); _bottomAdVideoCtrlForAds?.dispose(); _logoVideoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenW = MediaQuery.of(context).size.width; double screenH = MediaQuery.of(context).size.height;
    double tickerH = 55.0; double topAreaH = screenH - tickerH;

    bool showAds = isAdCurrentlyShowing;
    double lAdW = 0, rAdW = 0, bAdH = 0; double vW = screenW, vH = topAreaH, vLeft = 0;

    if (showAds) {
      if (adShapeMode == 0) { 
        double adW = screenW * 0.20; vW = screenW - adW; vH = vW * (9 / 16); bAdH = topAreaH - vH;
        if (bAdH < topAreaH * 0.15) { bAdH = topAreaH * 0.15; vH = topAreaH - bAdH; vW = vH * (16 / 9); adW = screenW - vW; }
        if (isLBandRight) { lAdW = 0; rAdW = adW; vLeft = 0; } else { lAdW = adW; rAdW = 0; vLeft = adW; }
      } else if (adShapeMode == 1) { 
        lAdW = screenW * 0.18; rAdW = screenW * 0.18; vW = screenW - lAdW - rAdW; vH = topAreaH; vLeft = lAdW; bAdH = 0;
      } else if (adShapeMode == 2) { 
        lAdW = screenW * 0.15; rAdW = screenW * 0.15; vW = screenW - lAdW - rAdW; vH = vW * (9 / 16); bAdH = topAreaH - vH;
        if (bAdH < topAreaH * 0.15) { bAdH = topAreaH * 0.15; vH = topAreaH - bAdH; vW = vH * (16 / 9); lAdW = (screenW - vW) / 2; rAdW = lAdW; }
        vLeft = lAdW;
      }
    }

    Widget channelLogoWidget = channelLogoPath.isNotEmpty
        ? SizedBox(width: 70, height: 70, child: channelLogoPath.toLowerCase().endsWith('.mp4') ? (_logoVideoCtrl != null && _logoVideoCtrl!.value.isInitialized ? VideoPlayer(_logoVideoCtrl!) : const SizedBox()) : Image.file(File(channelLogoPath), fit: BoxFit.contain, filterQuality: FilterQuality.high))
        : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)), child: const Text("SS YATRA TV", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)));

    Widget positionedLogoWidget = Positioned(
      top: (logoPosition == 0 || logoPosition == 1) ? 15.0 : null, bottom: (logoPosition == 2 || logoPosition == 3) ? 65.0 : null,
      left: (logoPosition == 0 || logoPosition == 2) ? 15.0 : null, right: (logoPosition == 1 || logoPosition == 3) ? 15.0 : null,
      child: channelLogoWidget,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => hideControls = !hideControls),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600), curve: Curves.easeInOut,
                left: showAds ? vLeft : 0, top: 0, width: showAds ? vW : screenW, height: showAds ? vH : topAreaH,
                child: ClipRect(
                  child: isLivePaused ? Container(color: Colors.black, child: const Center(child: Text("LIVE PAUSED", style: TextStyle(color: Colors.redAccent, fontSize: 30, fontWeight: FontWeight.bold)))) : Column(
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), color: Colors.black, child: Row(children: [ Container(padding: const EdgeInsets.all(6), color: Colors.red.shade900, child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("WEST BENGAL", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), Text("262/294", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)), ], ), ), const SizedBox(width: 4), Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ _buildPartyHeaderItem("BJP+", "▲ +78", "$bjpSeats", Colors.orange.shade800), _buildPartyHeaderItem("TMC+", "▼ -87", "$tmcSeats", Colors.green.shade800), _buildPartyHeaderItem("CONG", "▲ +5", "$congSeats", Colors.blue.shade800), _buildPartyHeaderItem("LEFT+", "▲ +2", "$leftSeats", Colors.red.shade800), _buildPartyHeaderItem("OTH", "▲ +2", "$othSeats", Colors.grey.shade700), ], )), ])),
                      Expanded(
                        child: Row(
                          children: [
                            Container(width: 170, color: Colors.grey.shade900, padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text("PUDUCHERRY", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), const Text("17/30", style: TextStyle(color: Colors.amber, fontSize: 11)), const Divider(color: Colors.white24), _buildStateResultRow("NRC+", "▲ +1", "11", Colors.red.shade800), _buildStateResultRow("TVK+", "▲ +4", "4", Colors.red.shade800), _buildStateResultRow("CONG+", "▼ -2", "2", Colors.red.shade800), _buildStateResultRow("OTH", "▼ -3", "0", Colors.red.shade800), ])),
                            Expanded(
                              child: Container(
                                color: Colors.black,
                                child: Stack(
                                  children: [
                                    Positioned(left: 10, top: 10, bottom: 10, width: 140, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2), color: Colors.grey[850]), child: _cameraController != null && _cameraController!.value.isInitialized ? ClipRect(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _cameraController!.value.previewSize!.height, height: _cameraController!.value.previewSize!.width, child: CameraPreview(_cameraController!)))) : const Center(child: CircularProgressIndicator(color: Colors.amber)))),
                                    Positioned(left: 160, right: 10, top: 20, bottom: 20, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade800, border: Border.all(color: Colors.amber, width: 3), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)]), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Text("BREAKING NEWS", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)), SizedBox(height: 15), Text("EARLY TRENDS: MAMATA TRAILING FROM BHABANIPUR", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), ]))),
                                  ],
                                ),
                              ),
                            ),
                            Container(width: 170, color: Colors.grey.shade900, padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text("ASSAM", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), const Text("96/126", style: TextStyle(color: Colors.amber, fontSize: 11)), const Divider(color: Colors.white24), _buildStateResultRow("BJP+", "▲ +18", "71", Colors.red.shade800), _buildStateResultRow("CONG", "▼ -2", "23", Colors.red.shade800), _buildStateResultRow("AIUDF+", "▼ -11", "1", Colors.red.shade800), _buildStateResultRow("OTH", "▼ -5", "1", Colors.red.shade800), ])),
                          ],
                        ),
                      ),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), color: Colors.black, child: Row(children: [ Container(width: 130, padding: const EdgeInsets.all(4), color: Colors.red.shade900, child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("TAMIL NADU", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), Text("142/234", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)), ], )), const SizedBox(width: 4), Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ _buildBottomPartyItem("DMK+", "▼ -38", "63", Colors.amber), _buildBottomPartyItem("TVK", "▲ +41", "41", Colors.brown.shade700), _buildBottomPartyItem("ADMK+", "▼ -4", "37", Colors.teal.shade800), _buildBottomPartyItem("OTH", "▲ +1", "1", Colors.grey.shade700), ], )), ])),
                    ],
                  ),
                ),
              ),

              positionedLogoWidget,

              AnimatedPositioned(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut, left: showAds && lAdW > 0 ? 0 : -screenW * 0.25, top: 0, width: lAdW > 0 ? lAdW : screenW * 0.20, height: topAreaH, child: Container(color: Colors.black, child: leftAdPaths.isNotEmpty ? (_leftAdVideoCtrl != null && _leftAdVideoCtrl!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _leftAdVideoCtrl!.value.size.width, height: _leftAdVideoCtrl!.value.size.height, child: VideoPlayer(_leftAdVideoCtrl!))) : SizedBox.expand(child: Image.file(File(leftAdPaths[leftAdIndex]), fit: BoxFit.fill))) : const SizedBox())),
              AnimatedPositioned(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut, right: showAds && rAdW > 0 ? 0 : -screenW * 0.25, top: 0, width: rAdW > 0 ? rAdW : screenW * 0.20, height: topAreaH, child: Container(color: Colors.black, child: rightAdPaths.isNotEmpty ? (_rightAdVideoCtrl != null && _rightAdVideoCtrl!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _rightAdVideoCtrl!.value.size.width, height: _rightAdVideoCtrl!.value.size.height, child: VideoPlayer(_rightAdVideoCtrl!))) : SizedBox.expand(child: Image.file(File(rightAdPaths[rightAdIndex]), fit: BoxFit.fill))) : const SizedBox())),
              AnimatedPositioned(duration: const Duration(milliseconds: 600), curve: Curves.easeInOut, left: showAds ? vLeft : 0, top: showAds && bAdH > 0 ? vH : topAreaH + 50, width: showAds ? vW : screenW, height: bAdH > 0 ? bAdH : 50, child: Container(color: Colors.black, child: bottomAdPaths.isNotEmpty ? (_bottomAdVideoCtrlForAds != null && _bottomAdVideoCtrlForAds!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _bottomAdVideoCtrlForAds!.value.size.width, height: _bottomAdVideoCtrlForAds!.value.size.height, child: VideoPlayer(_bottomAdVideoCtrlForAds!))) : SizedBox.expand(child: Image.file(File(bottomAdPaths[bottomAdIndex]), fit: BoxFit.fill))) : const SizedBox())),

              Positioned(
                bottom: 0, left: 0, right: 0, height: tickerH,
                child: Container(
                  decoration: BoxDecoration(color: bgColors[_tickerBgColorIndex % bgColors.length], border: Border.all(color: Colors.amber.shade400, width: 1.5)),
                  child: Row(children: [
                    Container(width: 95, color: Colors.red.shade900, alignment: Alignment.center, child: const Text("BREAKING\nNEWS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
                    Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 45.0)))
                  ]),
                ),
              ),

              if (!hideControls)
                Positioned(
                  top: 15, left: 15,
                  child: FloatingActionButton(mini: true, backgroundColor: Colors.blueGrey, onPressed: () => Navigator.pop(context), child: const Icon(Icons.arrow_back, color: Colors.white)),
                ),

              // === FLOATING CONTROLS IN ELECTION BOARD ===
              if (!hideControls)
                Positioned(
                  bottom: 75, right: 15,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isLiveBroadcasting) ...[
                        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: const StadiumBorder()), onPressed: _stopLiveStream, icon: const Icon(Icons.stop, color: Colors.white), label: const Text("STOP LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: const StadiumBorder()), onPressed: _togglePauseLive, icon: Icon(isLivePaused ? Icons.play_arrow : Icons.pause, color: Colors.white), label: Text(isLivePaused ? "RESUME" : "PAUSE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ] else ...[
                        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade900, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: const StadiumBorder()), onPressed: _startLiveAndLock, icon: const Icon(Icons.sensors, color: Colors.white), label: const Text("GO LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                      const SizedBox(width: 15),
                      Container(decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(15)), child: IconButton(iconSize: 32, icon: const Icon(Icons.settings_input_antenna, color: Colors.white), onPressed: _showMultiStreamDialog))
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartyHeaderItem(String party, String change, String seats, Color bgColor) {
    return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 4), color: bgColor, child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(party, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(width: 2), Text(change, style: const TextStyle(color: Colors.white70, fontSize: 8))]), Text(seats, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))])));
  }

  Widget _buildStateResultRow(String party, String change, String seats, Color bgColor) {
    return Container(margin: const EdgeInsets.symmetric(vertical: 3), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), color: bgColor, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(party, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), Text(change, style: const TextStyle(color: Colors.white70, fontSize: 9))]), Text(seats, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))]));
  }

  Widget _buildBottomPartyItem(String party, String change, String seats, Color bgColor) {
    return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 4), color: bgColor, child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(party, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(width: 2), Text(change, style: const TextStyle(color: Colors.white70, fontSize: 9))]), Text(seats, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))])));
  }
}
