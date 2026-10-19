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
// 1. STREAM SERVICE MANAGER (ఎర్రర్ హ్యాండ్లింగ్ తో)
// ============================================================================
class StreamServiceManager {
  static Future<bool> startLiveStream(String rtmpUrl) async {
    if (rtmpUrl.isEmpty) return false;
    String safeUrl = rtmpUrl.replaceFirst('rtmps://', 'rtmp://');
    List<String> channels = ['com.ssyatratv.pocket_pcr/stream', 'com.kingjvk.pocket_pcr/stream'];
    List<String> methods = ['startScreenStream', 'startScreenCaptureStreaming'];
    for (String c in channels) {
      for (String m in methods) {
        try {
          await MethodChannel(c).invokeMethod(m, {
            'rtmpUrl': safeUrl, 'cableRtmp': safeUrl, 'restreamRtmp': safeUrl,
            'satelliteSrt': safeUrl, 'url': safeUrl, 'recordAudio': true
          });
          return true;
        } catch (e) { debugPrint("Stream Error on $c: $e"); }
      }
    }
    return false;
  }
  
  static Future<bool> stopLiveStream() async {
    List<String> channels = ['com.ssyatratv.pocket_pcr/stream', 'com.kingjvk.pocket_pcr/stream'];
    for (String c in channels) {
      try { await MethodChannel(c).invokeMethod('stopScreenStream'); return true; } catch (_) {}
      try { await MethodChannel(c).invokeMethod('stopScreenCaptureStreaming'); return true; } catch (_) {}
    }
    return false;
  }

  static Future<bool> pauseLiveStream() async {
    List<String> channels = ['com.ssyatratv.pocket_pcr/stream', 'com.kingjvk.pocket_pcr/stream'];
    for (String c in channels) {
      try { await MethodChannel(c).invokeMethod('pauseScreenStream'); return true; } catch (_) {}
      try { await MethodChannel(c).invokeMethod('stopScreenStream'); return true; } catch (_) {}
    }
    return false;
  }
  
  static Future<int?> startUsbCamera() async {
    try { return await const MethodChannel('com.ssyatratv.pocket_pcr/uvc').invokeMethod('startUsbCamera'); } catch (e) { return null; }
  }
  
  static Future<void> stopUsbCamera() async {
    try { await const MethodChannel('com.ssyatratv.pocket_pcr/uvc').invokeMethod('stopUsbCamera'); } catch (e) {}
  }
}

// ============================================================================
// 2. STUDIO SCREEN (మీ ఒరిజినల్ కోడ్ లోని అణువణువూ ఇక్కడ ఉంది)
// ============================================================================
class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> with WidgetsBindingObserver {
  CameraController? controller;
  VideoPlayerController? _bulletinVideoController;
  VideoPlayerController? _bottomAdVideoController;
  VideoPlayerController? _leftAdVideoCtrl;
  VideoPlayerController? _rightAdVideoCtrl;
  VideoPlayerController? _bottomAdVideoCtrlForAds; 
  VideoPlayerController? _logoVideoCtrl;
  VideoPlayerController? _ipCamController;
  
  List<String> dualMediaList = [];
  int currentDualMediaIndex = 0;

  bool isLiveLocked = false;
  bool hideControls = false;
  bool isMenuOpen = false;

  int currentCameraIndex = 0;
  bool isLandscape = false;
  bool isLiveBroadcasting = false;
  bool isLivePaused = false;
  
  bool isDualScreenMode = false;
  int adDisplayMode = 0; 
  bool isAdCurrentlyShowing = false;
  int adShapeMode = 0; 
  bool isLBandRight = true; 
  int logoPosition = 1; 

  bool isNewsBulletinMode = false;
  bool isNetworkVideoMode = false;
  bool isBulletinMuted = false;
  bool isCameraVisible = true; 
  bool isYoutubeLoading = false;
  bool isNoiseCancellationEnabled = true;

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  double _baseScale = 1.0;
  bool _isCameraInitialized = false;
  bool isExternalIpCamMode = false;
  bool isUsbCamMode = false;
  int? _usbTextureId;

  final ImagePicker _picker = ImagePicker();

  String channelLogoPath = "";
  double logoWidth = 70.0;
  double logoHeight = 70.0;

  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA";
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String breakingNewsText = "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";

  String splitScreenMainHeadline = "తాజా వార్తలు";
  String splitScreenSubHeadline = "వార్తా అప్డేట్";

  TextEditingController restreamRtmpController = TextEditingController(); 
  TextEditingController cableRtmpController = TextEditingController();
  TextEditingController satelliteSrtController = TextEditingController();
  TextEditingController networkVideoUrlCtrl = TextEditingController();
  TextEditingController youtubeVideoUrlCtrl = TextEditingController();
  TextEditingController watermarkCtrl = TextEditingController();
  TextEditingController locCtrl = TextEditingController();
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController roleCtrl = TextEditingController();
  TextEditingController manualTickerCtrl = TextEditingController();
  TextEditingController mainHeadlineCtrl = TextEditingController();
  TextEditingController subHeadlineCtrl = TextEditingController();
  TextEditingController ipCamUrlCtrl = TextEditingController();
  TextEditingController usbCamUrlCtrl = TextEditingController();

  Timer? _newsTimer;
  Timer? _adCycleTimer;

  List<String> leftAdPaths = [];
  List<String> rightAdPaths = [];
  List<String> bottomAdPaths = [];
  int leftAdIndex = 0;
  int rightAdIndex = 0;
  int bottomAdIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    ipCamUrlCtrl.text = "http://192.168.1.100:8080/video"; 
    usbCamUrlCtrl.text = "/dev/video0";

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, 
      DeviceOrientation.landscapeLeft, 
      DeviceOrientation.landscapeRight
    ]);

    _loadSavedData(); 
    _requestPermissionsAndInitCamera();
    _fetchBreakingNews();

    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) { _fetchBreakingNews(); });
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
        if (titles.isNotEmpty && mounted) {
          setState(() { breakingNewsText = titles.join("   ♦   "); });
        }
      }
    } catch (e) { debugPrint("News Fetch Error: $e"); }
  }

  void _showMsg(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  void _setLogo(String path) {
    channelLogoPath = path;
    if (path.toLowerCase().endsWith('.mp4')) {
      _logoVideoCtrl?.dispose();
      _logoVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { 
          if (mounted) { _logoVideoCtrl!.setLooping(true); _logoVideoCtrl!.setVolume(0); _logoVideoCtrl!.play(); setState(() {}); } 
      });
    } else { _logoVideoCtrl?.dispose(); _logoVideoCtrl = null; }
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      watermarkText = prefs.getString('watermarkText') ?? "SS YATRA TV";
      locationText = prefs.getString('locationText') ?? "LIVE KOTHAKOTA";
      reporterName = prefs.getString('reporterName') ?? "JANAMPALLY VINOD KUMAR";
      reporterRole = prefs.getString('reporterRole') ?? "SPECIAL CORRESPONDENT";
      splitScreenMainHeadline = prefs.getString('splitScreenMainHeadline') ?? "తాజా వార్తలు";
      splitScreenSubHeadline = prefs.getString('splitScreenSubHeadline') ?? "వార్తా అప్డేట్";
      isNoiseCancellationEnabled = prefs.getBool('noiseCancel') ?? true;
      adShapeMode = prefs.getInt('adShapeMode') ?? 0;
      logoPosition = prefs.getInt('logoPosition') ?? 1;

      restreamRtmpController.text = prefs.getString('restreamRtmp') ?? "";
      cableRtmpController.text = prefs.getString('cableRtmp') ?? "";
      satelliteSrtController.text = prefs.getString('satelliteSrt') ?? "";
      youtubeVideoUrlCtrl.text = prefs.getString('youtubeVideoUrl') ?? "";
      networkVideoUrlCtrl.text = prefs.getString('networkVideoUrl') ?? "";
      ipCamUrlCtrl.text = prefs.getString('ipCamUrl') ?? "http://192.168.1.100:8080/video";
      usbCamUrlCtrl.text = prefs.getString('usbCamUrl') ?? "/dev/video0";

      String savedLogo = prefs.getString('channelLogoPath') ?? "";
      if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) { _setLogo(savedLogo); }
      
      leftAdPaths = (prefs.getStringList('leftAdPaths') ?? []).where((p) => File(p).existsSync()).toList();
      rightAdPaths = (prefs.getStringList('rightAdPaths') ?? []).where((p) => File(p).existsSync()).toList();
      bottomAdPaths = (prefs.getStringList('bottomAdPaths') ?? []).where((p) => File(p).existsSync()).toList();

      if (leftAdPaths.isNotEmpty) _initAdVideo('left');
      if (rightAdPaths.isNotEmpty) _initAdVideo('right');
      if (bottomAdPaths.isNotEmpty) _initAdVideo('bottom');
    });
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

  Future<void> _saveLinks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('restreamRtmp', restreamRtmpController.text);
    await prefs.setString('cableRtmp', cableRtmpController.text);
    await prefs.setString('satelliteSrt', satelliteSrtController.text);
    await prefs.setString('youtubeVideoUrl', youtubeVideoUrlCtrl.text);
    await prefs.setString('networkVideoUrl', networkVideoUrlCtrl.text);
    await prefs.setString('ipCamUrl', ipCamUrlCtrl.text);
    await prefs.setString('usbCamUrl', usbCamUrlCtrl.text);
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
      if (isCameraVisible && !isExternalIpCamMode && !isUsbCamMode && (controller == null || !controller!.value.isInitialized)) { _initCamera(); }
    }
  }

  Future<void> _requestPermissionsAndInitCamera() async {
    await [Permission.camera, Permission.microphone, Permission.storage].request();
    setState(() { isCameraVisible = true; });
    await _initCamera();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) { try { cameras = await availableCameras(); } catch (e) {} }
    if (cameras.isEmpty) return;
    try {
      controller?.dispose();
      controller = CameraController(cameras[currentCameraIndex], ResolutionPreset.high, enableAudio: true);
      await controller!.initialize();
      if (!mounted) return;
      _minZoomLevel = await controller!.getMinZoomLevel();
      _maxZoomLevel = await controller!.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      setState(() { _isCameraInitialized = true; });
    } catch (e) { _showMsg("Camera Init Error: $e", Colors.red); }
  }

  // --- ఆప్షన్స్ & డైలాగ్స్ (మీ ఒరిజినల్ ఫంక్షన్స్ అన్నీ) ---
  void _switchCamera() async {
    if (isExternalIpCamMode || isUsbCamMode) { _showMsg("ఎక్స్‌టర్నల్ కెమెరాలో స్విచ్ పనిచేయదు.", Colors.orange); return; }
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    if (isCameraVisible) await _initCamera();
    setState(() { isMenuOpen = false; });
  }

  void _toggleCameraVisibility() async {
    setState(() { isMenuOpen = false; });
    if (isExternalIpCamMode || isUsbCamMode) {
      setState(() { isExternalIpCamMode = false; isUsbCamMode = false; isCameraVisible = false; _usbTextureId = null; });
      _ipCamController?.dispose(); _ipCamController = null;
      try { await StreamServiceManager.stopUsbCamera(); } catch (_) {}
      return;
    }
    if (isCameraVisible) {
      setState(() { isCameraVisible = false; _isCameraInitialized = false; });
      await controller?.dispose(); controller = null;
    } else {
      setState(() { isCameraVisible = true; }); await _initCamera();
    }
  }

  Future<void> _startIpCamera(String url) async {
    if (url.isEmpty) return;
    _showMsg("IP కెమెరాకు కనెక్ట్ అవుతోంది...", Colors.orange);
    _ipCamController?.dispose();
    _ipCamController = VideoPlayerController.networkUrl(Uri.parse(url))..initialize().then((_) {
        if (!mounted) return;
        setState(() { isExternalIpCamMode = true; isUsbCamMode = false; isCameraVisible = true; isNewsBulletinMode = false; isDualScreenMode = false; });
        _ipCamController?.play();
      }).catchError((e) { _showMsg("IP కెమెరా కనెక్ట్ కాలేదు.", Colors.red); });
  }

  Future<void> _startUsbCamera(String url) async {
    final int? textureId = await StreamServiceManager.startUsbCamera();
    if (textureId != null) {
      setState(() { isUsbCamMode = true; isExternalIpCamMode = false; isCameraVisible = true; _usbTextureId = textureId; });
      _showMsg("USB కనెక్ట్ అయ్యింది!", Colors.green);
    } else {
      _showMsg("USB కార్డ్ కనెక్ట్ కాలేదు.", Colors.red);
    }
  }

  void _showExternalCamsDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.grey[900], title: const Text("External Cameras Setup", style: TextStyle(color: Colors.white, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: ipCamUrlCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "IP Cam Link")),
          ElevatedButton(onPressed: () { _saveLinks(); Navigator.pop(context); _startIpCamera(ipCamUrlCtrl.text); }, child: const Text("Connect IP Cam")),
          const Divider(),
          TextField(controller: usbCamUrlCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "USB Cam Link")),
          ElevatedButton(onPressed: () { Navigator.pop(context); _startUsbCamera(usbCamUrlCtrl.text); }, child: const Text("Connect USB Cam")),
        ]),
      );
    });
  }

  Future<void> _startYoutubeVideo(String url) async {
    if (url.isEmpty) return;
    setState(() { isYoutubeLoading = true; isCameraVisible = false; });
    _showMsg("యూట్యూబ్ వీడియో లోడ్ అవుతోంది...", Colors.orange);
    try {
      var ytExplode = yt.YoutubeExplode();
      var videoId = yt.VideoId(url);
      var manifest = await ytExplode.videos.streamsClient.getManifest(videoId).timeout(const Duration(seconds: 15));
      String playUrl = manifest.muxed.isNotEmpty ? manifest.muxed.withHighestBitrate().url.toString() : manifest.audioOnly.first.url.toString();
      ytExplode.close();
      _playNetworkBulletin(playUrl);
    } catch (e) {
      setState(() { isYoutubeLoading = false; isCameraVisible = true; });
      _showMsg("యూట్యూబ్ లింక్ ప్లే కాలేదు.", Colors.red);
    }
  }

  void _playNetworkBulletin(String playUrl) {
    _bulletinVideoController?.dispose();
    _bulletinVideoController = VideoPlayerController.networkUrl(Uri.parse(playUrl))..initialize().then((_) { 
        if (!mounted) return; 
        _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0); 
        setState(() { isNewsBulletinMode = true; isNetworkVideoMode = false; isDualScreenMode = false; hideControls = false; isYoutubeLoading = false; isCameraVisible = false; }); 
        _bulletinVideoController?.play(); 
      }).catchError((e) { 
        setState(() { isYoutubeLoading = false; isCameraVisible = true; isNewsBulletinMode = false; });
        _showMsg("వీడియో ప్లే అవ్వడం లేదు.", Colors.red); 
      });
  }

  Future<void> _playLocalGalleryVideo() async {
    try {
      final XFile? videoFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (videoFile != null) {
        _showMsg("గ్యాలరీ వీడియో లోడ్ అవుతోంది...", Colors.orange);
        _bulletinVideoController?.dispose();
        _bulletinVideoController = VideoPlayerController.file(File(videoFile.path))..initialize().then((_) {
            if (!mounted) return;
            setState(() { isNewsBulletinMode = true; isDualScreenMode = false; isCameraVisible = false; });
            _bulletinVideoController?.play();
          });
      }
    } catch (e) {}
  }

  void _showMultiStreamDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.grey[900], title: const Text("Live Control Room", style: TextStyle(color: Colors.white, fontSize: 15)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: cableRtmpController, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "Main RTMP URL")),
          TextField(controller: restreamRtmpController, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "Backup RTMP URL")),
          TextField(controller: satelliteSrtController, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "Satellite SRT URL")),
          TextField(controller: youtubeVideoUrlCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "YouTube Video Link")),
          Row(children: [ Expanded(child: ElevatedButton(onPressed: () { _saveLinks(); _showMsg("లింక్స్ సేవ్ అయ్యాయి ✔️", Colors.green); Navigator.pop(context); }, child: const Text("Save"))), const SizedBox(width: 5), Expanded(child: ElevatedButton(onPressed: () { Navigator.pop(context); _startYoutubeVideo(youtubeVideoUrlCtrl.text); }, child: const Text("Play YT"))) ]),
          ElevatedButton(onPressed: () { Navigator.pop(context); _playLocalGalleryVideo(); }, child: const Text("గ్యాలరీ వీడియో తీసుకోండి")),
        ])),
      );
    });
  }

  void _showEditDialog() {
    setState(() { isMenuOpen = false; });
    watermarkCtrl.text = watermarkText; locCtrl.text = locationText; nameCtrl.text = reporterName; roleCtrl.text = reporterRole;
    mainHeadlineCtrl.text = splitScreenMainHeadline; subHeadlineCtrl.text = splitScreenSubHeadline;
    
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.grey[900], title: const Text("స్టూడియో సెట్టింగ్స్", style: TextStyle(color: Colors.white, fontSize: 13)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(onPressed: () async {
            final XFile? media = await _picker.pickMedia(); 
            if (media != null) { setState(() => channelLogoPath = media.path); (await SharedPreferences.getInstance()).setString('channelLogoPath', media.path); _setLogo(media.path); }
          }, child: const Text("లోగో అప్లోడ్")),
          TextField(controller: watermarkCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "వాటర్ మార్క్")),
          TextField(controller: nameCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "రిపోర్టర్ పేరు")),
          TextField(controller: locCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "లొకేషన్")),
          TextField(controller: mainHeadlineCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "డ్యూయల్ స్క్రీన్ హెడ్డింగ్")),
          TextField(controller: manualTickerCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "మాన్యువల్ బ్రేకింగ్ టిక్కర్")),
          ElevatedButton(onPressed: () { if (manualTickerCtrl.text.isNotEmpty) setState(() => breakingNewsText = manualTickerCtrl.text); }, child: const Text("టిక్కర్ అప్‌డేట్")),
        ])),
        actions: [ ElevatedButton(onPressed: () async {
            setState(() { watermarkText = watermarkCtrl.text; locationText = locCtrl.text; reporterName = nameCtrl.text; splitScreenMainHeadline = mainHeadlineCtrl.text; });
            SharedPreferences p = await SharedPreferences.getInstance(); p.setString('watermarkText', watermarkText); p.setString('locationText', locationText); p.setString('reporterName', reporterName); p.setString('splitScreenMainHeadline', splitScreenMainHeadline);
            Navigator.pop(context);
          }, child: const Text("Save & Close")) ],
      );
    });
  }

  Future<void> _pickAds(String pos) async {
    try {
      final List<XFile> medias = await _picker.pickMultipleMedia();
      if (medias.isNotEmpty && mounted) {
        setState(() {
          if (pos == 'left') { leftAdPaths.addAll(medias.map((e) => e.path)); _saveAdPaths(pos, leftAdPaths); }
          if (pos == 'right') { rightAdPaths.addAll(medias.map((e) => e.path)); _saveAdPaths(pos, rightAdPaths); }
          if (pos == 'bottom') { bottomAdPaths.addAll(medias.map((e) => e.path)); _saveAdPaths(pos, bottomAdPaths); }
          _initAdVideo(pos);
        });
      }
    } catch (e) {}
  }

  void _manageAdsDialog(String pos) {
    List<String> currentPaths = (pos == 'left') ? leftAdPaths : (pos == 'right' ? rightAdPaths : bottomAdPaths);
    showDialog(context: context, builder: (ctx) {
      return AlertDialog(
        backgroundColor: Colors.grey[900], title: Text("Manage $pos Ads", style: const TextStyle(color: Colors.white)),
        content: SizedBox(width: double.maxFinite, child: currentPaths.isEmpty ? const Text("No Ads") : ListView.builder(shrinkWrap: true, itemCount: currentPaths.length, itemBuilder: (ctx, idx) {
          return ListTile(title: Text("Ad ${idx + 1}", style: const TextStyle(color: Colors.white)), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { setState(() { currentPaths.removeAt(idx); _saveAdPaths(pos, currentPaths); _initAdVideo(pos); }); Navigator.pop(ctx); _manageAdsDialog(pos); }));
        })),
        actions: [ TextButton(child: const Text("Clear All"), onPressed: () { setState(() { currentPaths.clear(); _saveAdPaths(pos, currentPaths); }); Navigator.pop(ctx); }), TextButton(child: const Text("Close"), onPressed: () => Navigator.pop(ctx)) ],
      );
    });
  }

  void _changeLogoPosition() { setState(() { logoPosition = (logoPosition + 1) % 4; isMenuOpen = false; }); }
  void _toggleRotation() { setState(() { isMenuOpen = false; isLandscape = !isLandscape; if (isLandscape) SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]); else SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); }); }
  void _toggleLBandDirection() { setState(() { isLBandRight = !isLBandRight; isMenuOpen = false; }); }
  void _toggleAdShapeMode() { setState(() { adShapeMode = (adShapeMode + 1) % 3; isMenuOpen = false; }); }

  void _toggleAdMode() {
    setState(() {
      adDisplayMode = (adDisplayMode + 1) % 3; isMenuOpen = false; _adCycleTimer?.cancel();
      if (adDisplayMode == 0) { isAdCurrentlyShowing = false; _showMsg("Ads OFF", Colors.red); } 
      else if (adDisplayMode == 1) { isAdCurrentlyShowing = true; _startPermanentCycle(); _showMsg("Ads ON", Colors.blue); } 
      else if (adDisplayMode == 2) { isAdCurrentlyShowing = true; _startAutoCycle(); _showMsg("Auto Ads", Colors.green); }
    });
  }

  void _startPermanentCycle() { _adCycleTimer?.cancel(); _adCycleTimer = Timer.periodic(const Duration(seconds: 20), (timer) { if (mounted && adDisplayMode == 1) setState(() { if (leftAdPaths.isNotEmpty) leftAdIndex = (leftAdIndex + 1) % leftAdPaths.length; if (rightAdPaths.isNotEmpty) rightAdIndex = (rightAdIndex + 1) % rightAdPaths.length; if (bottomAdPaths.isNotEmpty) bottomAdIndex = (bottomAdIndex + 1) % bottomAdPaths.length; _initAdVideo('left'); _initAdVideo('right'); _initAdVideo('bottom'); }); }); }
  void _startAutoCycle() { _adCycleTimer?.cancel(); if (isAdCurrentlyShowing) { _adCycleTimer = Timer(const Duration(seconds: 20), () { if (mounted && adDisplayMode == 2) { setState(() => isAdCurrentlyShowing = false); _startAutoCycle(); } }); } else { _adCycleTimer = Timer(const Duration(seconds: 40), () { if (mounted && adDisplayMode == 2) { setState(() => isAdCurrentlyShowing = true); _startAutoCycle(); } }); } }

  Future<void> _toggleDualScreenAndPickMedia() async {
    setState(() { isMenuOpen = false; });
    if (isDualScreenMode) { setState(() { isDualScreenMode = false; dualMediaList.clear(); _bottomAdVideoController?.dispose(); _bottomAdVideoController = null; }); return; }
    try {
      final List<XFile> medias = await _picker.pickMultipleMedia(); 
      if (medias.isNotEmpty && mounted) { dualMediaList = medias.map((e) => e.path).toList(); currentDualMediaIndex = 0; setState(() { isDualScreenMode = true; }); _playDualMedia(dualMediaList[0]); }
    } catch (e) {}
  }

  void _playDualMedia(String path) {
    if (path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov')) { _bottomAdVideoController?.dispose(); _bottomAdVideoController = VideoPlayerController.file(File(path))..initialize().then((_) { if (mounted) { _bottomAdVideoController!.setLooping(true); _bottomAdVideoController!.play(); setState(() {}); } }); }
  }
  void _prevDualMedia() { if (dualMediaList.isEmpty) return; currentDualMediaIndex = (currentDualMediaIndex - 1) < 0 ? dualMediaList.length - 1 : currentDualMediaIndex - 1; _playDualMedia(dualMediaList[currentDualMediaIndex]); }
  void _nextDualMedia() { if (dualMediaList.isEmpty) return; currentDualMediaIndex = (currentDualMediaIndex + 1) % dualMediaList.length; _playDualMedia(dualMediaList[currentDualMediaIndex]); }
  void _toggleDualMediaPause() { if (_bottomAdVideoController != null) { _bottomAdVideoController!.value.isPlaying ? _bottomAdVideoController!.pause() : _bottomAdVideoController!.play(); setState(() {}); } }

  Future<void> _startLiveAndLock() async {
    await _saveLinks();
    String url = restreamRtmpController.text.isNotEmpty ? restreamRtmpController.text : cableRtmpController.text;
    if (url.isEmpty) { _showMsg("RTMP లింక్ ఇవ్వండి.", Colors.red); return; }
    bool success = await StreamServiceManager.startLiveStream(url);
    if (success) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
      setState(() { isLiveBroadcasting = true; isLivePaused = false; hideControls = false; isMenuOpen = false; isLandscape = true; });
      _showMsg("లైవ్ మొదలైంది! అనుమతించండి.", Colors.green);
    } else { _showMsg("లైవ్ కనెక్ట్ కాలేదు.", Colors.red); }
  }

  Future<void> _stopLiveStream() async {
    bool success = await StreamServiceManager.stopLiveStream();
    if (success) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      setState(() { isLiveBroadcasting = false; }); _showMsg("లైవ్ ఆగిపోయింది ❌", Colors.blue);
    }
  }

  Widget _buildMainDisplay(bool isScreenLandscape, double screenWidth, double screenHeight, Widget phoneCameraWidget) {
    Widget actualCameraWidget = phoneCameraWidget;
    if (isExternalIpCamMode && _ipCamController != null && _ipCamController!.value.isInitialized) actualCameraWidget = SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _ipCamController!.value.size.width, height: _ipCamController!.value.size.height, child: VideoPlayer(_ipCamController!))));
    else if (isUsbCamMode && _usbTextureId != null) actualCameraWidget = SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: 1920, height: 1080, child: Texture(textureId: _usbTextureId!))));
    
    if (isDualScreenMode && dualMediaList.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.all(6.0), decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.amberAccent, width: 3)),
        child: isScreenLandscape ? Row(children: [ Expanded(child: actualCameraWidget), Container(width: 3, color: Colors.amber), Expanded(child: Column(children: [ Expanded(child: LayoutBuilder(builder: (c, cons) => GestureDetector(onTapUp: (det) { double dx = det.localPosition.dx; if (dx < cons.maxWidth / 3) _prevDualMedia(); else if (dx > cons.maxWidth * 2 / 3) _nextDualMedia(); else _toggleDualMediaPause(); }, child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized ? VideoPlayer(_bottomAdVideoController!) : Image.file(File(dualMediaList[currentDualMediaIndex]), fit: BoxFit.cover)))), Container(padding: const EdgeInsets.all(8), color: Colors.amber, child: Text(splitScreenMainHeadline, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))), Container(padding: const EdgeInsets.symmetric(vertical: 4), color: Colors.blueAccent, child: Text(splitScreenSubHeadline, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) ])) ]) : Column(children: [ Expanded(flex: 4, child: actualCameraWidget), Container(padding: const EdgeInsets.symmetric(vertical: 10), color: Colors.amber, child: Text(splitScreenMainHeadline, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))), Expanded(flex: 4, child: LayoutBuilder(builder: (c, cons) => GestureDetector(onTapUp: (det) { double dx = det.localPosition.dx; if (dx < cons.maxWidth / 3) _prevDualMedia(); else if (dx > cons.maxWidth * 2 / 3) _nextDualMedia(); else _toggleDualMediaPause(); }, child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized ? VideoPlayer(_bottomAdVideoController!) : Image.file(File(dualMediaList[currentDualMediaIndex]), fit: BoxFit.cover)))) ])
      );
    }

    if (isAdCurrentlyShowing || isNewsBulletinMode) {
      double lAdW = screenWidth * 0.20; double vW = screenWidth - lAdW; double vH = vW * (9 / 16); double bAdH = screenHeight - vH;
      if (bAdH < screenHeight * 0.15) { bAdH = screenHeight * 0.15; vH = screenHeight - bAdH; vW = vH * (16 / 9); lAdW = screenWidth - vW; }
      
      Widget mainPlayer = (isNewsBulletinMode && _bulletinVideoController != null && _bulletinVideoController!.value.isInitialized) ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bulletinVideoController!.value.size.width, height: _bulletinVideoController!.value.size.height, child: VideoPlayer(_bulletinVideoController!)))) : actualCameraWidget;

      return Container(
        color: Colors.black, child: Stack(children: [
          Positioned(left: isAdCurrentlyShowing ? (isLBandRight ? 0 : lAdW) : 0, top: 0, width: isAdCurrentlyShowing ? vW : screenWidth, height: isAdCurrentlyShowing ? vH : screenHeight, child: mainPlayer),
          if (isAdCurrentlyShowing) Positioned(left: isLBandRight ? vW : 0, top: 0, width: lAdW, height: screenHeight, child: GestureDetector(onTap: leftAdPaths.isEmpty ? () => _pickAds('left') : null, onLongPress: leftAdPaths.isNotEmpty ? () => _manageAdsDialog('left') : null, child: Container(color: Colors.black, child: leftAdPaths.isNotEmpty ? (_leftAdVideoCtrl != null && _leftAdVideoCtrl!.value.isInitialized ? VideoPlayer(_leftAdVideoCtrl!) : Image.file(File(leftAdPaths[leftAdIndex]), fit: BoxFit.fill)) : const Center(child: Text("LEFT ADS", style: TextStyle(color: Colors.white)))))),
          if (isAdCurrentlyShowing) Positioned(left: isLBandRight ? 0 : lAdW, top: vH, width: vW, height: bAdH, child: GestureDetector(onTap: bottomAdPaths.isEmpty ? () => _pickAds('bottom') : null, onLongPress: bottomAdPaths.isNotEmpty ? () => _manageAdsDialog('bottom') : null, child: Container(color: Colors.black, child: bottomAdPaths.isNotEmpty ? (_bottomAdVideoCtrlForAds != null && _bottomAdVideoCtrlForAds!.value.isInitialized ? VideoPlayer(_bottomAdVideoCtrlForAds!) : Image.file(File(bottomAdPaths[bottomAdIndex]), fit: BoxFit.fill)) : const Center(child: Text("BOTTOM ADS", style: TextStyle(color: Colors.white)))))),
        ])
      );
    }
    return actualCameraWidget;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newsTimer?.cancel(); _adCycleTimer?.cancel();
    controller?.dispose(); _bulletinVideoController?.dispose(); _bottomAdVideoController?.dispose();
    _leftAdVideoCtrl?.dispose(); _rightAdVideoCtrl?.dispose(); _bottomAdVideoCtrlForAds?.dispose();
    _logoVideoCtrl?.dispose(); _ipCamController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isScreenLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    Widget phoneCameraWidget = (!isCameraVisible) ? Container(color: Colors.black) : (_isCameraInitialized && controller != null && controller!.value.isInitialized) ? GestureDetector(onScaleStart: (det) => _baseScale = _currentZoomLevel, onScaleUpdate: (det) async { double z = _baseScale * det.scale; if(z<_minZoomLevel)z=_minZoomLevel; if(z>_maxZoomLevel)z=_maxZoomLevel; setState(()=>_currentZoomLevel=z); await controller?.setZoomLevel(z); }, child: ClipRect(child: SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: controller!.value.previewSize?.height, height: controller!.value.previewSize?.width, child: CameraPreview(controller!)))))) : const Center(child: CircularProgressIndicator(color: Colors.amber));

    Widget logoWidget = GestureDetector(onTap: _changeLogoPosition, child: channelLogoPath.isNotEmpty ? SizedBox(width: logoWidth, height: logoHeight, child: channelLogoPath.toLowerCase().endsWith('.mp4') ? (_logoVideoCtrl != null && _logoVideoCtrl!.value.isInitialized ? VideoPlayer(_logoVideoCtrl!) : const SizedBox()) : Image.file(File(channelLogoPath), fit: BoxFit.contain)) : Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.amber)), child: const Text("SS YATRA", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))));

    return Scaffold(
      backgroundColor: Colors.black, 
      body: SafeArea(
        child: GestureDetector(
          onTap: () { if (!isLiveLocked) setState(() { isMenuOpen ? isMenuOpen = false : hideControls = !hideControls; }); },
          child: LayoutBuilder(builder: (context, constraints) {
            double screenW = constraints.maxWidth; double screenH = constraints.maxHeight; double tickerH = 55.0; double topAreaH = screenH - tickerH;
            return Stack(children: [
              Positioned(top: 0, left: 0, right: 0, height: topAreaH, child: _buildMainDisplay(isScreenLandscape, screenW, topAreaH, phoneCameraWidget)),
              Positioned(top: (logoPosition == 0 || logoPosition == 1) ? 15.0 : null, bottom: (logoPosition == 2 || logoPosition == 3) ? 70.0 : null, left: (logoPosition == 0 || logoPosition == 3) ? 15.0 : null, right: (logoPosition == 1 || logoPosition == 2) ? 15.0 : null, child: logoWidget),
              if (!isDualScreenMode && !isNewsBulletinMode) Positioned(bottom: 65, left: 15, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(watermarkText, style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 11)), Container(color: Colors.red.shade800, padding: const EdgeInsets.all(3), child: Text(locationText, style: const TextStyle(color: Colors.white, fontSize: 11))), Container(color: Colors.white, padding: const EdgeInsets.all(4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12))), Container(color: Colors.red.shade800, padding: const EdgeInsets.all(3), child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontSize: 11))) ])),
              Positioned(bottom: 0, left: 0, right: 0, height: tickerH, child: Row(children: [ Container(width: 110, color: Colors.red.shade900, alignment: Alignment.center, child: const Text("BREAKING\nNEWS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))), Expanded(child: Container(color: const Color(0xFF1A1A2E), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), blankSpace: 100.0))) ])),
              
              if (!hideControls) Positioned(bottom: 75, right: 20, child: Row(children: [
                if (isLiveBroadcasting) ...[
                  ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: _stopLiveStream, icon: const Icon(Icons.stop, color: Colors.white), label: const Text("STOP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: () async { if(isLivePaused) { await StreamServiceManager.startLiveStream(restreamRtmpController.text); setState(()=>isLivePaused=false); } else { await StreamServiceManager.pauseLiveStream(); setState(()=>isLivePaused=true); } }, icon: Icon(isLivePaused ? Icons.play_arrow : Icons.pause, color: Colors.white), label: Text(isLivePaused ? "RESUME" : "PAUSE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ] else ...[
                  ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700), onPressed: _startLiveAndLock, icon: const Icon(Icons.sensors, color: Colors.white), label: const Text("GO LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ],
                const SizedBox(width: 10),
                FloatingActionButton(backgroundColor: Colors.blue.shade800, onPressed: () => setState(() => isMenuOpen = !isMenuOpen), child: Icon(isMenuOpen ? Icons.close : Icons.menu, color: Colors.white))
              ])),

              if (isMenuOpen && !hideControls)
                Positioned.fill(child: Container(color: Colors.black87, child: Center(child: SingleChildScrollView(child: Wrap(alignment: WrapAlignment.center, spacing: 30, runSpacing: 35, children: [
                  _buildMenuBtn(Icons.live_tv, "Live Links", _showMultiStreamDialog, Colors.redAccent),
                  _buildMenuBtn(Icons.dashboard_customize, "PCR Board", () { setState(()=>isMenuOpen=false); Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterPCRBoard())); }, Colors.yellowAccent),
                  _buildMenuBtn(Icons.bar_chart, "Election Results", () { setState(()=>isMenuOpen=false); Navigator.push(context, MaterialPageRoute(builder: (_) => const ElectionBoardScreen())); }, Colors.blueAccent),
                  _buildMenuBtn(Icons.flip_camera_android, "Phone Cam", _switchCamera, Colors.white),
                  
                  _buildMenuBtn(isCameraVisible ? Icons.videocam : Icons.videocam_off, isCameraVisible ? "Cam ON" : "Cam OFF", _toggleCameraVisibility, isCameraVisible ? Colors.greenAccent : Colors.redAccent),
                  _buildMenuBtn(Icons.video_call, "Ext. Cams", _showExternalCamsDialog, Colors.cyanAccent),
                  _buildMenuBtn(Icons.grid_on, "Dual Screen", _toggleDualScreenAndPickMedia, Colors.orangeAccent),
                  _buildMenuBtn(Icons.visibility, adDisplayMode == 0 ? "Ads OFF" : (adDisplayMode == 1 ? "Ads ON" : "Auto Ads"), _toggleAdMode, Colors.redAccent),
                  
                  _buildMenuBtn(Icons.dashboard, adShapeMode == 0 ? "Shape: L-Band" : "Shape: U-Band", _toggleAdShapeMode, Colors.orangeAccent),
                  _buildMenuBtn(Icons.picture_in_picture_alt, "Logo Pos", _changeLogoPosition, Colors.lightGreenAccent),
                  _buildMenuBtn(Icons.swap_horiz, "L-Band L/R", _toggleLBandDirection, Colors.orange),
                  _buildMenuBtn(Icons.screen_rotation, "Rotate", _toggleRotation, Colors.purpleAccent),
                  _buildMenuBtn(Icons.settings, "Settings", _showEditDialog, Colors.blue),
                ]))))))
            ]);
          }),
        ),
      ),
    );
  }

  Widget _buildMenuBtn(IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [ CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade800, child: Icon(icon, color: color, size: 28)), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)) ]));
  }
}

// ============================================================================
// 3. MASTER PCR BOARD (1+6 Layout)
// ============================================================================
class MasterPCRBoard extends StatefulWidget {
  const MasterPCRBoard({Key? key}) : super(key: key);
  @override
  State<MasterPCRBoard> createState() => _MasterPCRBoardState();
}
class _MasterPCRBoardState extends State<MasterPCRBoard> {
  CameraController? _phoneCamCtrl;
  String mainCameraId = "REPORTER_CAM"; 
  List<String> hexCams = ["IP_1", "IP_2", "DRONE_1", "IP_3", "IP_4", "HDMI_1"]; 

  @override
  void initState() {
    super.initState();
    _initPhoneCamera();
  }

  Future<void> _initPhoneCamera() async {
    try { 
      if (cameras.isNotEmpty) {
        _phoneCamCtrl = CameraController(cameras.first, ResolutionPreset.medium);
        await _phoneCamCtrl!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {}
  }

  @override
  void dispose() { _phoneCamCtrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(children: [ IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)), const Text("MASTER PCR BOARD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) ]),
            Expanded(child: Row(children: [
              Expanded(flex: 2, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2)), child: _phoneCamCtrl != null && _phoneCamCtrl!.value.isInitialized ? CameraPreview(_phoneCamCtrl!) : const Center(child: Text("Main Cam", style: TextStyle(color: Colors.white))))),
              Expanded(flex: 3, child: Column(children: [ Expanded(child: Row(children: [ _buildHexBox(0), _buildHexBox(1), _buildHexBox(2) ])), Expanded(child: Row(children: [ _buildHexBox(3), _buildHexBox(4), _buildHexBox(5) ])) ]))
            ])),
            Container(height: 50, color: Colors.blue.shade900, child: Row(children: [ Container(width: 90, color: Colors.red, alignment: Alignment.center, child: const Text("PCR NEWS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), Expanded(child: Marquee(text: "బహుళ కెమెరాల కంట్రోల్ రూమ్ లోడ్ అయింది...", style: const TextStyle(color: Colors.white, fontSize: 16))) ]))
          ],
        ),
      ),
    );
  }

  Widget _buildHexBox(int i) { return Expanded(child: GestureDetector(onTap: () => setState(() { String temp = mainCameraId; mainCameraId = hexCams[i]; hexCams[i] = temp; }), child: Container(margin: const EdgeInsets.all(2), color: Colors.grey.shade900, child: Center(child: Text(hexCams[i], style: const TextStyle(color: Colors.white)))))); }
}

// ============================================================================
// 4. ELECTION BOARD SCREEN (Dynamic Refresh & Fixes)
// ============================================================================
class ElectionBoardScreen extends StatefulWidget {
  const ElectionBoardScreen({Key? key}) : super(key: key);
  @override
  State<ElectionBoardScreen> createState() => _ElectionBoardScreenState();
}
class _ElectionBoardScreenState extends State<ElectionBoardScreen> {
  CameraController? _cameraController;
  Map<String, dynamic> electionData = {"bjp": 150, "tmc": 103, "cong": 5, "left": 2, "oth": 2};

  @override
  void initState() { super.initState(); _initCamera(); }

  Future<void> _initCamera() async {
    try {
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first), ResolutionPreset.medium);
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {}
  }

  void _refreshData() { setState(() { electionData = {"bjp": 156, "tmc": 98, "cong": 8, "left": 4, "oth": 2}; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("రిజల్ట్స్ అప్‌డేట్ అయ్యాయి! ✔️"), backgroundColor: Colors.green)); }

  @override
  void dispose() { _cameraController?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(padding: const EdgeInsets.all(8), color: Colors.black, child: Row(children: [ Container(padding: const EdgeInsets.all(6), color: Colors.red.shade900, child: const Column(children: [Text("WEST BENGAL", style: TextStyle(color: Colors.white, fontSize: 11)), Text("262/294", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))])), const SizedBox(width: 5), _buildPartyBox("BJP+", "${electionData['bjp']}", Colors.orange.shade800), _buildPartyBox("TMC+", "${electionData['tmc']}", Colors.green.shade800), _buildPartyBox("CONG", "${electionData['cong']}", Colors.blue.shade800), _buildPartyBox("LEFT", "${electionData['left']}", Colors.red.shade800) ])),
                Expanded(child: Row(children: [ Container(width: 170, color: Colors.grey.shade900, padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text("PUDUCHERRY", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), const Text("17/30", style: TextStyle(color: Colors.amber, fontSize: 11)), const Divider(color: Colors.white24), _buildStateRow("NRC+", "11", Colors.red.shade800), _buildStateRow("TVK+", "4", Colors.red.shade800), _buildStateRow("CONG+", "2", Colors.red.shade800) ])), Expanded(child: Container(color: Colors.black, child: Stack(children: [ Positioned(left: 10, top: 10, bottom: 10, width: 140, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2)), child: _cameraController != null && _cameraController!.value.isInitialized ? CameraPreview(_cameraController!) : const CircularProgressIndicator())), Positioned(left: 160, right: 10, top: 20, bottom: 20, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade800, border: Border.all(color: Colors.amber)), child: const Center(child: Text("BREAKING: MAMATA TRAILING", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))))) ]))), Container(width: 170, color: Colors.grey.shade900, padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text("ASSAM", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), const Text("96/126", style: TextStyle(color: Colors.amber, fontSize: 11)), const Divider(color: Colors.white24), _buildStateRow("BJP+", "71", Colors.red.shade800), _buildStateRow("CONG", "23", Colors.red.shade800), _buildStateRow("OTH", "2", Colors.red.shade800) ])) ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), color: Colors.black, child: Row(children: [ Container(width: 130, padding: const EdgeInsets.all(4), color: Colors.red.shade900, child: const Column(children: [Text("TAMIL NADU", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), Text("142/234", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900))])), const SizedBox(width: 4), Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ _buildBottomPartyItem("DMK+", "63", Colors.amber), _buildBottomPartyItem("TVK", "41", Colors.brown.shade700), _buildBottomPartyItem("ADMK+", "37", Colors.teal.shade800), _buildBottomPartyItem("OTH", "1", Colors.grey.shade700) ])) ]))
              ],
            ),
            Positioned(top: 15, left: 15, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
            Positioned(top: 15, right: 15, child: ElevatedButton.icon(onPressed: _refreshData, icon: const Icon(Icons.refresh), label: const Text("Refresh Data"))),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyBox(String party, String seats, Color bgColor) { return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 4), color: bgColor, child: Column(children: [Text(party, style: const TextStyle(color: Colors.white, fontSize: 12)), Text(seats, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))]))); }
  Widget _buildStateRow(String party, String seats, Color bgColor) { return Container(margin: const EdgeInsets.symmetric(vertical: 3), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), color: bgColor, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(party, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), Text(seats, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))])); }
  Widget _buildBottomPartyItem(String party, String seats, Color bgColor) { return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 4), color: bgColor, child: Column(children: [Text(party, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)), Text(seats, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))]))); }
}
