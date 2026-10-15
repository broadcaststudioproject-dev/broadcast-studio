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
  static const platform = MethodChannel('com.ssyatratv.pocket_pcr/stream');
  
  static Future<bool> startLiveStream(String rtmpUrl, {bool noiseCancel = true}) async {
    try {
      String safeUrl = rtmpUrl.replaceFirst('rtmps://', 'rtmp://');
      await platform.invokeMethod('startScreenStream', {
        'rtmpUrl': safeUrl,
        'recordAudio': true,
        'noiseCancel': noiseCancel
      }); 
      return true; 
    } catch (e) {
      return false;
    }
  }
  
  static Future<bool> stopLiveStream() async {
    try {
      await platform.invokeMethod('stopScreenStream');
      return true;
    } catch (e) {
      return false;
    }
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

class _StudioScreenState extends State<StudioScreen> with WidgetsBindingObserver {
  
  CameraController? controller;
  VideoPlayerController? _bulletinVideoController;
  VlcPlayerController? _networkVideoController;
  
  List<String> dualMediaList = [];
  int currentDualMediaIndex = 0;
  VideoPlayerController? _bottomAdVideoController;

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

  final ImagePicker _picker = ImagePicker();

  String channelLogoPath = "";
  double logoWidth = 70.0;
  double logoHeight = 70.0;
  VideoPlayerController? _logoVideoCtrl; // Added missing controller

  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA";
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String breakingNewsText = "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";

  String splitScreenMainHeadline = "తాజా వార్తలు";
  String splitScreenSubHeadline = "వార్తా అప్డేట్";

  TextEditingController cableRtmpController = TextEditingController();
  TextEditingController satelliteUplinkController = TextEditingController();
  TextEditingController satelliteDownlinkController = TextEditingController();

  TextEditingController networkVideoUrlCtrl = TextEditingController();
  TextEditingController youtubeVideoUrlCtrl = TextEditingController();
  TextEditingController watermarkCtrl = TextEditingController();
  TextEditingController locCtrl = TextEditingController();
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController roleCtrl = TextEditingController();
  TextEditingController manualTickerCtrl = TextEditingController();
  TextEditingController mainHeadlineCtrl = TextEditingController();
  TextEditingController subHeadlineCtrl = TextEditingController();

  Timer? _newsTimer;
  Timer? _adCycleTimer;
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

  bool isExternalIpCamMode = false;
  bool isUsbCamMode = false;
  VideoPlayerController? _ipCamController;
  TextEditingController ipCamUrlCtrl = TextEditingController();
  TextEditingController usbCamUrlCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    watermarkCtrl.text = watermarkText;
    locCtrl.text = locationText;
    nameCtrl.text = reporterName;
    roleCtrl.text = reporterRole;
    mainHeadlineCtrl.text = splitScreenMainHeadline;
    subHeadlineCtrl.text = splitScreenSubHeadline;
    
    cableRtmpController.text = "rtmp://...";
    satelliteUplinkController.text = "srt://...";
    satelliteDownlinkController.text = "http://...";
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

    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) { 
      _fetchBreakingNews(); 
    });
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
    } catch (e) {
      debugPrint("News Fetch Error: $e");
    }
  }

  void _setLogo(String path) {
    channelLogoPath = path;
    if (path.toLowerCase().endsWith('.mp4')) {
      _logoVideoCtrl?.dispose();
      _logoVideoCtrl = VideoPlayerController.file(File(path))
        ..initialize().then((_) { 
          if (mounted) { 
            _logoVideoCtrl!.setLooping(true); 
            _logoVideoCtrl!.setVolume(0); 
            _logoVideoCtrl!.play(); 
            setState(() {}); 
          } 
        });
    } else { 
      _logoVideoCtrl?.dispose(); 
      _logoVideoCtrl = null; 
    }
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      watermarkText = prefs.getString('watermarkText') ?? "SS YATRA TV";
      locationText = prefs.getString('locationText') ?? "LIVE KOTHAKOTA";
      reporterName = prefs.getString('reporterName') ?? "JANAMPALLY VINOD KUMAR";
      reporterRole = prefs.getString('reporterRole') ?? "SPECIAL CORRESPONDENT";
      breakingNewsText = prefs.getString('breakingNewsText') ?? "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";
      splitScreenMainHeadline = prefs.getString('splitScreenMainHeadline') ?? "తాజా వార్తలు";
      splitScreenSubHeadline = prefs.getString('splitScreenSubHeadline') ?? "వార్తా అప్డేట్";
      isNoiseCancellationEnabled = prefs.getBool('noiseCancel') ?? true;
      adShapeMode = prefs.getInt('adShapeMode') ?? 0;
      logoPosition = prefs.getInt('logoPosition') ?? 1;

      cableRtmpController.text = prefs.getString('cableRtmp') ?? "";
      satelliteUplinkController.text = prefs.getString('satelliteUplink') ?? "";
      satelliteDownlinkController.text = prefs.getString('satelliteDownlink') ?? "";

      youtubeVideoUrlCtrl.text = prefs.getString('youtubeVideoUrl') ?? "";
      networkVideoUrlCtrl.text = prefs.getString('networkVideoUrl') ?? "";
      ipCamUrlCtrl.text = prefs.getString('ipCamUrl') ?? "http://192.168.1.100:8080/video";
      usbCamUrlCtrl.text = prefs.getString('usbCamUrl') ?? "/dev/video0";

      watermarkCtrl.text = watermarkText;
      locCtrl.text = locationText;
      nameCtrl.text = reporterName;
      roleCtrl.text = reporterRole;
      mainHeadlineCtrl.text = splitScreenMainHeadline;
      subHeadlineCtrl.text = splitScreenSubHeadline;

      String savedLogo = prefs.getString('channelLogoPath') ?? "";
      if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) {
        _setLogo(savedLogo);
      }
      
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

  Future<void> _saveTextSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('watermarkText', watermarkText);
    await prefs.setString('locationText', locationText);
    await prefs.setString('reporterName', reporterName);
    await prefs.setString('reporterRole', reporterRole);
    await prefs.setString('splitScreenMainHeadline', splitScreenMainHeadline);
    await prefs.setString('splitScreenSubHeadline', splitScreenSubHeadline);
    await prefs.setString('breakingNewsText', breakingNewsText);
    await prefs.setBool('noiseCancel', isNoiseCancellationEnabled);
    await prefs.setInt('adShapeMode', adShapeMode);
    await prefs.setInt('logoPosition', logoPosition);
  }

  Future<void> _saveLinks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cableRtmp', cableRtmpController.text);
    await prefs.setString('satelliteUplink', satelliteUplinkController.text);
    await prefs.setString('satelliteDownlink', satelliteDownlinkController.text);
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
      if (isCameraVisible && !isExternalIpCamMode && !isUsbCamMode && (controller == null || !controller!.value.isInitialized)) { 
        _initCamera(); 
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newsTimer?.cancel();
    _adCycleTimer?.cancel();
    controller?.dispose();
    _bulletinVideoController?.removeListener(_videoListener);
    _bulletinVideoController?.dispose();
    _networkVideoController?.dispose();
    _bottomAdVideoController?.dispose();
    
    _leftAdVideoCtrl?.dispose();
    _rightAdVideoCtrl?.dispose();
    _bottomAdVideoCtrlForAds?.dispose();
    _logoVideoCtrl?.dispose();
    _ipCamController?.dispose();

    cableRtmpController.dispose();
    satelliteUplinkController.dispose();
    satelliteDownlinkController.dispose();
    networkVideoUrlCtrl.dispose();
    youtubeVideoUrlCtrl.dispose();
    ipCamUrlCtrl.dispose();
    usbCamUrlCtrl.dispose();
    watermarkCtrl.dispose();
    locCtrl.dispose();
    nameCtrl.dispose();
    roleCtrl.dispose();
    manualTickerCtrl.dispose();
    mainHeadlineCtrl.dispose();
    subHeadlineCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionsAndInitCamera() async {
    await [
      Permission.camera, 
      Permission.microphone, 
      Permission.storage, 
      Permission.photos, 
      Permission.videos
    ].request();
    
    setState(() { isCameraVisible = true; });
    await _initCamera();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) {
      try { cameras = await availableCameras(); } catch (e) { debugPrint("Camera Error: $e"); }
    }
    if (cameras.isEmpty) return;
    try {
      if (controller != null) { 
        await controller!.dispose(); 
      }
      final camController = CameraController(
        cameras[currentCameraIndex], 
        ResolutionPreset.high, 
        enableAudio: false
      );
      controller = camController;
      await camController.initialize();
      if (!mounted) return;
      _minZoomLevel = await camController.getMinZoomLevel();
      _maxZoomLevel = await camController.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      setState(() { 
        _isCameraInitialized = true; 
      });
    } catch (e) { 
      debugPrint("Init Camera Error: $e");
    }
  }

  void _switchCamera() async {
    if (isExternalIpCamMode || isUsbCamMode) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఎక్స్‌టర్నల్ కెమెరా మోడ్‌లో ఫోన్ కెమెరా స్విచ్ పనిచేయదు.")));
      return;
    }
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    if (isCameraVisible) {
      await _initCamera();
    }
    setState(() { 
      isMenuOpen = false; 
    });
  }

  void _toggleCameraVisibility() async {
    setState(() { 
      isMenuOpen = false; 
    });
    
    if (isExternalIpCamMode || isUsbCamMode) {
      setState(() {
        isExternalIpCamMode = false;
        isUsbCamMode = false;
        isCameraVisible = false;
      });
      _ipCamController?.dispose();
      _ipCamController = null;
      try { await const MethodChannel('com.ssyatratv.pocket_pcr/uvc').invokeMethod('stopUsbCamera'); } catch (_) {}
      return;
    }

    if (isCameraVisible) {
      setState(() { isCameraVisible = false; });
      await controller?.dispose();
      controller = null;
      setState(() { _isCameraInitialized = false; });
    } else {
      setState(() { isCameraVisible = true; });
      await _initCamera();
    }
  }

  Future<void> _startIpCamera(String url) async {
    if (url.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("IP కెమెరాకు కనెక్ట్ అవుతోంది..."), backgroundColor: Colors.orange));
    
    _ipCamController?.dispose();
    _ipCamController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          isExternalIpCamMode = true;
          isUsbCamMode = false;
          isCameraVisible = true;
          isNewsBulletinMode = false;
          isNetworkVideoMode = false;
          isDualScreenMode = false;
        });
        _ipCamController?.play();
      }).catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("IP కెమెరా కనెక్ట్ కాలేదు. లింక్ లేదా నెట్‌వర్క్ చెక్ చేయండి."), backgroundColor: Colors.red));
      });
  }

  Future<void> _startUsbCamera(String url) async {
    try {
      final String result = await const MethodChannel('com.ssyatratv.pocket_pcr/uvc').invokeMethod('startUsbCamera', {'url': url});
      if (result == 'success') {
        setState(() {
          isUsbCamMode = true;
          isExternalIpCamMode = false;
          isCameraVisible = true;
          isNewsBulletinMode = false;
          isNetworkVideoMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("USB Capture Card కనెక్ట్ అయ్యింది!"), backgroundColor: Colors.green));
      }
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("USB క్యాప్చర్ కార్డ్ కనెక్ట్ కావాలంటే నేటివ్ UVC కోడ్ అవసరం."), backgroundColor: Colors.redAccent));
    }
  }

  void _showExternalCamsDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(
      context: context, 
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text("External Cameras Setup", style: TextStyle(color: Colors.white, fontSize: 15)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, 
                children: [
                  const Text("1. IP Camera / Wi-Fi CCTV Link", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: ipCamUrlCtrl, style: const TextStyle(color: Colors.yellow, fontSize: 12), 
                    decoration: const InputDecoration(hintText: "http://... or rtsp://...", hintStyle: TextStyle(color: Colors.white30), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    onPressed: () async { 
                      await _saveLinks();
                      Navigator.pop(context); 
                      _startIpCamera(ipCamUrlCtrl.text.trim()); 
                    },
                    icon: const Icon(Icons.wifi_tethering, color: Colors.white, size: 18),
                    label: const Text("Connect IP Cam", style: TextStyle(color: Colors.white, fontSize: 11))
                  ),
                  const Divider(color: Colors.white24, height: 30),
                  
                  const Text("2. USB Camera Connection Link", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: usbCamUrlCtrl, style: const TextStyle(color: Colors.yellow, fontSize: 12), 
                    decoration: const InputDecoration(hintText: "/dev/video0 or Link", hintStyle: TextStyle(color: Colors.white30), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                    onPressed: () async { 
                      await _saveLinks();
                      Navigator.pop(context); 
                      _startUsbCamera(usbCamUrlCtrl.text.trim()); 
                    },
                    icon: const Icon(Icons.usb, color: Colors.white, size: 18),
                    label: const Text("Start USB Camera", style: TextStyle(color: Colors.white, fontSize: 11))
                  ),
                ]
              )
            ),
            actions: [
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white, fontSize: 11))),
            ]
          );
        });
      }
    );
  }

  Future<void> _startYoutubeVideo(String url) async {
    if (url.isEmpty) return;
    String cleanUrl = url.trim(); 
    
    setState(() => isYoutubeLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("యూట్యూబ్ లైవ్ లోడ్ అవుతోంది..."), backgroundColor: Colors.orange));
    
    try {
      var ytExplode = yt.YoutubeExplode();
      String? videoIdStr;

      try {
        videoIdStr = yt.VideoId.parseVideoId(cleanUrl);
      } catch (_) {}

      if (videoIdStr == null) {
        RegExp regExp = RegExp(r'(?:v=|/v/|embed/|youtu\.be/|/live/)([a-zA-Z0-9_-]{11})', caseSensitive: false);
        Match? match = regExp.firstMatch(cleanUrl);
        if (match != null && match.groupCount >= 1) {
          videoIdStr = match.group(1);
        }
      }

      if (videoIdStr == null) {
        ytExplode.close();
        setState(() => isYoutubeLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("తప్పు యూట్యూబ్ లింక్."), backgroundColor: Colors.red));
        return; 
      }

      var vId = yt.VideoId(videoIdStr);
      var video = await ytExplode.videos.get(vId);
      String finalPlayUrl = "";

      if (video.isLive) {
        finalPlayUrl = await ytExplode.videos.streamsClient.getHttpLiveStreamUrl(vId);
      } else {
        var manifest = await ytExplode.videos.streamsClient.getManifest(vId);
        finalPlayUrl = manifest.muxed.withHighestBitrate().url.toString();
      }
      ytExplode.close();

      if (finalPlayUrl.isNotEmpty) {
        _playNetworkVideoInVlc(finalPlayUrl);
      } else {
        throw Exception("Stream URL దొరకలేదు");
      }
    } catch (e) {
      setState(() { isYoutubeLoading = false; isNewsBulletinMode = false; isNetworkVideoMode = false; hideControls = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("యూట్యూబ్ లింక్ ప్లే కాలేదు."), backgroundColor: Colors.red));
    }
  }

  Future<void> _startNetworkVideoMp4(String url) async {
    if (url.isEmpty) return;
    _playNetworkVideoInVlc(url.trim());
  }

  void _playNetworkVideoInVlc(String playUrl) {
    _bulletinVideoController?.removeListener(_videoListener); 
    _bulletinVideoController?.dispose();
    _networkVideoController?.dispose();
    
    _networkVideoController = VlcPlayerController.network(
      playUrl,
      hwAcc: HwAcc.auto,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([ VlcAdvancedOptions.networkCaching(3000), ]),
        http: VlcHttpOptions([ VlcHttpOptions.httpReconnect(true), ]),
      ),
    );
    
    setState(() { 
      isNetworkVideoMode = true;
      isNewsBulletinMode = false; 
      isDualScreenMode = false; 
      hideControls = true; 
      isYoutubeLoading = false;
      isCameraVisible = false; 
    }); 
  }

  Future<void> _playLocalGalleryVideo() async {
    try {
      final XFile? videoFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (videoFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("గ్యాలరీ వీడియో లోడ్ అవుతోంది..."), backgroundColor: Colors.orange)
        );

        _networkVideoController?.dispose();
        _bulletinVideoController?.removeListener(_videoListener);
        _bulletinVideoController?.dispose();
        
        _bulletinVideoController = VideoPlayerController.file(File(videoFile.path))
          ..initialize().then((_) {
            if (!mounted) return;
            _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
            setState(() { 
              isNewsBulletinMode = true; 
              isNetworkVideoMode = false;
              isDualScreenMode = false; 
              hideControls = true; 
              isCameraVisible = false; 
            });
            _bulletinVideoController?.play();
            _bulletinVideoController?.addListener(_videoListener);
          }).catchError((e) { 
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("వీడియో ప్లే అవ్వడం లేదు."), backgroundColor: Colors.red)); 
          });
      }
    } catch (e) {
      debugPrint("Gallery Video Error: $e");
    }
  }

  void _videoListener() {
    final vController = _bulletinVideoController;
    if (vController == null || !vController.value.isInitialized) return;
    if (vController.value.position >= vController.value.duration && vController.value.duration != Duration.zero) {
      vController.removeListener(_videoListener);
      setState(() { 
        isNewsBulletinMode = false; 
        isCameraVisible = true; 
      });
    }
  }

  void _showMultiStreamDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(
      context: context, 
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text("Live Control Room", style: TextStyle(color: Colors.white, fontSize: 15)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, 
                children: [
                  _buildLinkEditor("1. Cable TV (RTMP/RTMPS/SRT/HLS)", cableRtmpController, setDialogState),
                  const Divider(color: Colors.white24, height: 20),
                  _buildLinkEditor("2. Satellite TV Uplink (RTMP/SRT)", satelliteUplinkController, setDialogState),
                  const Divider(color: Colors.white24, height: 20),
                  _buildLinkEditor("3. Satellite TV Downlink", satelliteDownlinkController, setDialogState),
                  const Divider(color: Colors.white24, height: 20),
                  _buildLinkEditor("4. YouTube Live Video Link", youtubeVideoUrlCtrl, setDialogState, onPlay: () { Navigator.pop(context); _startYoutubeVideo(youtubeVideoUrlCtrl.text.trim()); }),
                  const Divider(color: Colors.white24, height: 20),
                  _buildLinkEditor("5. Direct Network Video (MP4/m3u8)", networkVideoUrlCtrl, setDialogState, onPlay: () { Navigator.pop(context); _startNetworkVideoMp4(networkVideoUrlCtrl.text.trim()); }),
                  const Divider(color: Colors.white24, height: 20),
                  const Text("6. గ్యాలరీ వీడియో (MP4, HD, 4K, 8K)", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 10)),
                      onPressed: () { Navigator.pop(context); _playLocalGalleryVideo(); },
                      icon: const Icon(Icons.video_library, color: Colors.white, size: 20),
                      label: const Text("గ్యాలరీ నుండి వీడియో సెలెక్ట్ చేయండి", style: TextStyle(color: Colors.white, fontSize: 12))
                    ),
                  ),
                ]
              )
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                children: [
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () { Navigator.pop(context); _startLiveAndLock(); }, child: const Text("Go Live", style: TextStyle(color: Colors.white, fontSize: 11))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), 
                    onPressed: () async {
                      Navigator.pop(context);
                      if (isLivePaused) {
                        bool success = await StreamServiceManager.startLiveStream(cableRtmpController.text.trim(), noiseCancel: isNoiseCancellationEnabled);
                        if (success) { setState(() { isLivePaused = false; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ మళ్లీ మొదలైంది!"))); }
                      } else {
                        bool success = await StreamServiceManager.stopLiveStream();
                        if (success) { setState(() { isLivePaused = true; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ పాజ్ చేయబడింది."))); }
                      }
                    }, 
                    child: Text(isLivePaused ? "Resume Live" : "Live Pause", style: const TextStyle(color: Colors.white, fontSize: 11))
                  ),
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { Navigator.pop(context); _stopLiveStream(); }, child: const Text("Live Close", style: TextStyle(color: Colors.white, fontSize: 11))),
                ]
              )
            ]
          );
        });
      }
    );
  }

  Widget _buildLinkEditor(String label, TextEditingController controller, StateSetter setDialogState, {VoidCallback? onPlay}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller, style: const TextStyle(color: Colors.yellow, fontSize: 12), 
                decoration: const InputDecoration(hintText: "Paste link here...", hintStyle: TextStyle(color: Colors.white30), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))
              )
            ),
            IconButton(icon: const Icon(Icons.save, color: Colors.blueAccent, size: 22), onPressed: () async { 
              await _saveLinks(); 
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"))); 
            }),
            if (onPlay != null) IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 28), onPressed: onPlay)
          ]
        )
      ]
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
    setState(() { isMenuOpen = false; });
    showDialog(
      context: context, 
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900], 
            title: const Text("స్టూడియో సెట్టింగ్స్", style: TextStyle(color: Colors.white, fontSize: 13)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final XFile? media = await _picker.pickMedia();
                        if (media != null) { 
                          setState(() { _setLogo(media.path); }); 
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          await prefs.setString('channelLogoPath', media.path);
                          setDialogState(() {}); 
                        }
                      } catch (e) {}
                    }, 
                    icon: const Icon(Icons.upload), 
                    label: const Text("ఛానల్ లోగో అప్లోడ్ (MP4/GIF/JPEG)")
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  TextField(controller: mainHeadlineCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "మెయిన్ హెడ్‌లైన్ (Yellow Box)")),
                  TextField(controller: subHeadlineCtrl, style: const TextStyle(color: Colors.cyanAccent), decoration: const InputDecoration(labelText: "సబ్ హెడ్‌‌లైన్ (Blue Box)")),
                  const Divider(color: Colors.white24, height: 20),
                  TextField(controller: manualTickerCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "మాన్యువల్ బ్రేకింగ్ టిక్కర్")),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), 
                    onPressed: () async {
                      if (manualTickerCtrl.text.trim().isNotEmpty) { 
                        setState(() { breakingNewsText = manualTickerCtrl.text.trim(); }); 
                        await _saveTextSettings();
                        manualTickerCtrl.clear(); 
                        setDialogState(() {}); 
                      }
                    }, 
                    child: const Text("టిక్కర్ అప్‌డేట్ చేయి", style: TextStyle(color: Colors.black))
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
                ]
              )
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  setState(() { 
                    splitScreenMainHeadline = mainHeadlineCtrl.text; 
                    splitScreenSubHeadline = subHeadlineCtrl.text; 
                    watermarkText = watermarkCtrl.text; 
                    locationText = locCtrl.text; 
                    reporterName = nameCtrl.text; 
                    reporterRole = roleCtrl.text; 
                  });
                  await _saveTextSettings(); 
                  Navigator.pop(context);
                }, 
                child: const Text("Save & Close")
              )
            ]
          );
        });
      }
    );
  }

  void _changeLogoPosition() async {
    setState(() { logoPosition = (logoPosition + 1) % 4; isMenuOpen = false; });
    await _saveTextSettings();
  }

  void _toggleRotation() {
    setState(() { 
      isMenuOpen = false; 
      isLandscape = !isLandscape;
      if (isLandscape) { 
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]); 
      } else { 
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); 
      }
    });
  }

  Future<void> _startLiveAndLock() async {
    await _saveLinks();
    String fullRtmpUrl = cableRtmpController.text.trim();
    if (fullRtmpUrl.isEmpty || !fullRtmpUrl.contains("rtmp")) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("దయచేసి సరైన Live RTMP లింక్ ఇవ్వండి."), backgroundColor: Colors.red)); 
      return; 
    }

    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) { micStatus = await Permission.microphone.request(); }

    try {
      bool success = await StreamServiceManager.startLiveStream(fullRtmpUrl, noiseCancel: isNoiseCancellationEnabled);
      if (success) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
        setState(() { isLiveBroadcasting = true; isLivePaused = false; isLiveLocked = true; hideControls = true; isMenuOpen = false; isLandscape = true; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Live ప్రారంభమైంది!"), backgroundColor: Colors.green));
      }
    } catch (e) {}
  }

  Future<void> _stopLiveStream() async {
    try {
      bool success = await StreamServiceManager.stopLiveStream();
      if (success) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
        setState(() { isLiveBroadcasting = false; isLiveLocked = false; isLivePaused = false; });
      }
    } catch (e) {}
  }

  Future<void> _toggleDualScreenAndPickMedia() async {
    setState(() { isMenuOpen = false; });
    if (isDualScreenMode) {
      setState(() { isDualScreenMode = false; dualMediaList.clear(); _bottomAdVideoController?.dispose(); _bottomAdVideoController = null; });
      return;
    }
    try {
      final List<XFile> medias = await _picker.pickMultipleMedia(); 
      if (medias.isNotEmpty && mounted) {
        dualMediaList = medias.map((e) => e.path).toList();
        currentDualMediaIndex = 0;
        setState(() { isDualScreenMode = true; isNewsBulletinMode = false; isNetworkVideoMode = false; });
        _playDualMedia(dualMediaList[currentDualMediaIndex]);
      }
    } catch (e) {}
  }

  void _playDualMedia(String path) {
    if (path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov')) {
      _bottomAdVideoController?.dispose();
      _bottomAdVideoController = VideoPlayerController.file(File(path))
        ..initialize().then((_) { 
          if (mounted) { _bottomAdVideoController!.setLooping(true); _bottomAdVideoController!.setVolume(1.0); _bottomAdVideoController!.play(); setState(() {}); } 
        });
    } else {
      _bottomAdVideoController?.dispose(); 
      _bottomAdVideoController = null; 
      setState(() {});
    }
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
    if (_bottomAdVideoController != null) {
      _bottomAdVideoController!.value.isPlaying ? _bottomAdVideoController!.pause() : _bottomAdVideoController!.play();
      setState(() {});
    }
  }

  void _toggleAdMode() {
    setState(() {
      adDisplayMode = (adDisplayMode + 1) % 3;
      isMenuOpen = false;
      _adCycleTimer?.cancel();
      if (adDisplayMode == 0) {
        isAdCurrentlyShowing = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ads OFF"), backgroundColor: Colors.red));
      } else if (adDisplayMode == 1) {
        isAdCurrentlyShowing = true; _startPermanentCycle();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ads ON"), backgroundColor: Colors.blueAccent));
      } else if (adDisplayMode == 2) {
        isAdCurrentlyShowing = true; _startAutoCycle();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Auto Ads"), backgroundColor: Colors.green));
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

  Widget _buildMainDisplay(bool isScreenLandscape, double screenWidth, double screenHeight, Widget phoneCameraWidget) {
    Widget actualCameraWidget;
    
    if (isLivePaused) {
      actualCameraWidget = Container(color: Colors.black, child: const Center(child: Text("LIVE PAUSED", style: TextStyle(color: Colors.redAccent, fontSize: 30, fontWeight: FontWeight.bold))));
    } else if (isExternalIpCamMode && _ipCamController != null && _ipCamController!.value.isInitialized) {
      actualCameraWidget = SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _ipCamController!.value.size.width, height: _ipCamController!.value.size.height, child: VideoPlayer(_ipCamController!))));
    } else if (isUsbCamMode) {
      actualCameraWidget = Container(color: Colors.black, child: const Center(child: Text("USB CAMERA ACTIVE", style: TextStyle(color: Colors.greenAccent, fontSize: 20))));
    } else {
      actualCameraWidget = phoneCameraWidget;
    }

    if (isDualScreenMode && dualMediaList.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.all(6.0), 
        decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.amberAccent, width: 3.5), boxShadow: const [BoxShadow(color: Colors.redAccent, blurRadius: 10)]),
        child: isScreenLandscape 
          ? Row(
              children: [ 
                Expanded(child: actualCameraWidget), 
                Container(width: 3, color: Colors.amberAccent), 
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(builder: (context, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) {
                              double dx = details.localPosition.dx;
                              if (dx < constraints.maxWidth / 3) { _prevDualMedia(); } else if (dx > constraints.maxWidth * 2 / 3) { _nextDualMedia(); } else { _toggleDualMediaPause(); }
                            },
                            child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized 
                                ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bottomAdVideoController!.value.size.width, height: _bottomAdVideoController!.value.size.height, child: VideoPlayer(_bottomAdVideoController!))) 
                                : Image.file(File(dualMediaList[currentDualMediaIndex]), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                          );
                        })
                      ),
                      Container(width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.amber, child: Text(splitScreenMainHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold))),
                      Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 4), color: Colors.blueAccent, child: Text(splitScreenSubHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                    ]
                  )
                ) 
              ]
            )
          : Column(
              children: [ 
                Expanded(flex: 4, child: actualCameraWidget), 
                Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15), color: Colors.amber, child: Text(splitScreenMainHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold))),
                Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 5), color: Colors.blueAccent, child: Text(splitScreenSubHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                Expanded(
                  flex: 4, 
                  child: LayoutBuilder(builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        double dx = details.localPosition.dx;
                        if (dx < constraints.maxWidth / 3) { _prevDualMedia(); } else if (dx > constraints.maxWidth * 2 / 3) { _nextDualMedia(); } else { _toggleDualMediaPause(); }
                      },
                      child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized 
                          ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bottomAdVideoController!.value.size.width, height: _bottomAdVideoController!.value.size.height, child: VideoPlayer(_bottomAdVideoController!))) 
                          : Image.file(File(dualMediaList[currentDualMediaIndex]), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                    );
                  })
                ) 
              ]
            )
      );
    }

    double availableHeight = screenHeight; 
    double leftAdWidth = screenWidth * 0.20; 
    double videoWidth = screenWidth - leftAdWidth; 
    double videoHeight = videoWidth * (9 / 16); 
    double bottomAdHeight = availableHeight - videoHeight;

    if (bottomAdHeight < availableHeight * 0.15) {
      bottomAdHeight = availableHeight * 0.15;
      videoHeight = availableHeight - bottomAdHeight;
      videoWidth = videoHeight * (16 / 9);
      leftAdWidth = screenWidth - videoWidth;
    }

    if (isNewsBulletinMode || isNetworkVideoMode || isAdCurrentlyShowing) {
      
      Widget mainPlayer;
      if (isNewsBulletinMode && _bulletinVideoController != null && _bulletinVideoController!.value.isInitialized) {
        mainPlayer = SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bulletinVideoController!.value.size.width, height: _bulletinVideoController!.value.size.height, child: VideoPlayer(_bulletinVideoController!))));
      } else if (isNetworkVideoMode && _networkVideoController != null) {
        mainPlayer = SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: 1920, height: 1080, child: VlcPlayer(controller: _networkVideoController!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.red))))));
      } else {
        mainPlayer = actualCameraWidget;
      }

      return Container(
        color: Colors.black, 
        child: Stack(
          children: [
            Positioned(
              left: isAdCurrentlyShowing ? (isLBandRight ? 0 : leftAdWidth) : 0,
              top: 0,
              width: isAdCurrentlyShowing ? videoWidth : screenWidth,
              height: isAdCurrentlyShowing ? videoHeight : availableHeight,
              child: Stack(
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: mainPlayer,
                    ),
                  ),
                ],
              ),
            ),
            
            if (isAdCurrentlyShowing)
              Positioned(
                left: isLBandRight ? videoWidth : 0,
                top: 0,
                width: leftAdWidth,
                height: availableHeight,
                child: GestureDetector(
                  onTap: leftAdPaths.isEmpty ? () => _pickAds('left') : null,
                  onLongPress: leftAdPaths.isNotEmpty ? () => _manageAdsDialog('left') : null,
                  child: Container(
                    color: Colors.black, 
                    child: leftAdPaths.isNotEmpty 
                        ? (_leftAdVideoCtrl != null && _leftAdVideoCtrl!.value.isInitialized 
                            ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _leftAdVideoCtrl!.value.size.width, height: _leftAdVideoCtrl!.value.size.height, child: VideoPlayer(_leftAdVideoCtrl!)))
                            : SizedBox.expand(child: Image.file(File(leftAdPaths[leftAdIndex]), fit: BoxFit.fill)))
                        : const Center(child: Text("LEFT ADS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))
                  )
                ),
              ),

            if (isAdCurrentlyShowing)
              Positioned(
                left: isLBandRight ? 0 : leftAdWidth,
                top: videoHeight,
                width: videoWidth, 
                height: bottomAdHeight,
                child: GestureDetector(
                  onTap: bottomAdPaths.isEmpty ? () => _pickAds('bottom') : null,
                  onLongPress: bottomAdPaths.isNotEmpty ? () => _manageAdsDialog('bottom') : null,
                  child: Container(
                    color: Colors.black, 
                    child: bottomAdPaths.isNotEmpty 
                        ? (_bottomAdVideoCtrlForAds != null && _bottomAdVideoCtrlForAds!.value.isInitialized 
                            ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _bottomAdVideoCtrlForAds!.value.size.width, height: _bottomAdVideoCtrlForAds!.value.size.height, child: VideoPlayer(_bottomAdVideoCtrlForAds!)))
                            : SizedBox.expand(child: Image.file(File(bottomAdPaths[bottomAdIndex]), fit: BoxFit.fill)))
                        : const Center(child: Text("BOTTOM ADS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))
                  )
                ),
              ),
          ],
        ),
      );
    }

    if (isYoutubeLoading) {
      return Stack(
        children: [
          Positioned.fill(child: actualCameraWidget),
          Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.red)))
        ]
      );
    }

    return Positioned.fill(child: actualCameraWidget);
  }

  @override
  Widget build(BuildContext context) {
    bool isScreenLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    double camW = 1080; 
    double camH = 1920;
    if (_isCameraInitialized && controller != null && controller!.value.isInitialized) {
      final previewSize = controller!.value.previewSize;
      if (previewSize != null) { 
        camW = previewSize.width; camH = previewSize.height; 
        if (camW < camH) { double temp = camW; camW = camH; camH = temp; } 
      }
    }
    double finalCamW = isScreenLandscape ? camW : camH; 
    double finalCamH = isScreenLandscape ? camH : camW;

    Widget phoneCameraWidget = (!isCameraVisible) 
      ? Container(color: Colors.transparent)
      : (_isCameraInitialized && controller != null && controller!.value.isInitialized)
        ? GestureDetector(
            onScaleStart: (details) { _baseScale = _currentZoomLevel; },
            onScaleUpdate: (details) async {
              if (controller == null || !controller!.value.isInitialized) return;
              double zoom = _baseScale * details.scale;
              if (zoom < _minZoomLevel) zoom = _minZoomLevel; if (zoom > _maxZoomLevel) zoom = _maxZoomLevel;
              setState(() { _currentZoomLevel = zoom; }); await controller?.setZoomLevel(zoom);
            },
            child: ClipRect(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover, 
                  child: SizedBox(width: finalCamW, height: finalCamH, child: CameraPreview(controller!))
                )
              )
            ),
          )
        : const Center(child: CircularProgressIndicator(color: Colors.amber));

    Widget reporterBadgeWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      mainAxisSize: MainAxisSize.min, 
      children: [
        if (watermarkText.isNotEmpty) 
          Text(watermarkText, style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 11.0)),
        Container(color: Colors.red.shade800, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12.0))),
        Container(color: Colors.red.shade800, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
      ]
    );

    Widget visualScreenLogoWidget = GestureDetector(
      onTap: () { setState(() { logoPosition = (logoPosition + 1) % 4; }); },
      child: channelLogoPath.isNotEmpty
          ? SizedBox(
              width: logoWidth, 
              height: logoHeight, 
              child: channelLogoPath.toLowerCase().endsWith('.mp4') 
                ? (_logoVideoCtrl != null && _logoVideoCtrl!.value.isInitialized ? VideoPlayer(_logoVideoCtrl!) : const SizedBox()) 
                : Image.file(File(channelLogoPath), fit: BoxFit.contain, filterQuality: FilterQuality.high)
            )
          : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: Colors.amber)), child: const Text("SS YATRA TV", textAlign: TextAlign.center, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14))),
    );

    return Scaffold(
      backgroundColor: Colors.black, 
      body: SafeArea(
        top: false, bottom: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () { if (!isLiveLocked) { setState(() { isMenuOpen ? isMenuOpen = false : hideControls = !hideControls; }); } },
          onLongPress: () { if (isLiveLocked) { setState(() { isLiveLocked = false; hideControls = false; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("స్క్రీన్ అన్‌లాక్ చేయబడింది."))); } },
          child: LayoutBuilder(
            builder: (context, constraints) {
              double screenW = constraints.maxWidth;
              double screenH = constraints.maxHeight;
              double tickerH = 55.0; 
              double topAreaH = screenH - tickerH; 

              return Stack(
                children: [
                  Positioned(
                    top: 0, left: 0, right: 0, height: topAreaH,
                    child: _buildMainDisplay(isScreenLandscape, screenW, topAreaH, phoneCameraWidget)
                  ),
                  
                  Positioned(
                    top: (logoPosition == 0 || logoPosition == 1) ? 15.0 : null,
                    bottom: (logoPosition == 2 || logoPosition == 3) ? 70.0 : null,
                    left: (logoPosition == 0 || logoPosition == 3) ? 15.0 : null,
                    right: (logoPosition == 1 || logoPosition == 2) ? 15.0 : null,
                    child: visualScreenLogoWidget
                  ),

                  if (!isDualScreenMode && !isNewsBulletinMode && !isNetworkVideoMode)
                    Positioned(bottom: 65, left: 15, child: reporterBadgeWidget),

                  Positioned(
                    bottom: 0, left: 0, right: 0, height: tickerH,
                    child: Row(
                      children: [
                        Container(
                          width: 110, 
                          color: Colors.red.shade900, 
                          alignment: Alignment.center, 
                          child: const Text("BREAKING\nNEWS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900))
                        ),
                        Expanded(
                          child: Container(
                            color: const Color(0xFF1A1A2E), 
                            child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 45.0)
                          )
                        )
                      ]
                    )
                  ),

                  if (!hideControls && !isLiveLocked)
                    Positioned(
                      bottom: 75, right: 20, 
                      child: Row(
                        children: [
                          if (isLiveBroadcasting) ...[
                            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _stopLiveStream, icon: const Icon(Icons.stop, color: Colors.white), label: const Text("STOP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          ] else ...[
                            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _startLiveAndLock, icon: const Icon(Icons.sensors, color: Colors.white), label: const Text("GO LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          ],
                          const SizedBox(width: 10),
                          FloatingActionButton(
                            backgroundColor: Colors.blue.shade800, 
                            onPressed: () { setState(() { isMenuOpen = !isMenuOpen; }); }, 
                            child: Icon(isMenuOpen ? Icons.close : Icons.menu, color: Colors.white)
                          )
                        ]
                      )
                    ),

                  if (!hideControls && isMenuOpen && !isLiveLocked)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black87,
                        child: Center(
                          child: Wrap(
                            alignment: WrapAlignment.center, spacing: 30, runSpacing: 35, 
                            children: [
                              _buildControlButton(Icons.live_tv, "Live Links", _showMultiStreamDialog, Colors.redAccent),
                              _buildControlButton(Icons.dashboard_customize, "PCR Board", () { setState(() => isMenuOpen = false); Navigator.push(context, MaterialPageRoute(builder: (context) => const MasterPCRBoard())); }, Colors.yellowAccent),
                              _buildControlButton(Icons.bar_chart, "Election Results", () { setState(() => isMenuOpen = false); Navigator.push(context, MaterialPageRoute(builder: (context) => const ElectionBoardScreen())); }, Colors.blueAccent),
                              _buildControlButton(Icons.flip_camera_android, "Phone Cam", _switchCamera, Colors.white),
                              
                              _buildControlButton(isCameraVisible ? Icons.videocam : Icons.videocam_off, isCameraVisible ? "Cam ON" : "Cam OFF", _toggleCameraVisibility, isCameraVisible ? Colors.greenAccent : Colors.redAccent),
                              _buildControlButton(Icons.video_call, "Ext. Cams", _showExternalCamsDialog, Colors.cyanAccent),
                              _buildControlButton(Icons.grid_on, "Dual Screen", _toggleDualScreenAndPickMedia, Colors.orangeAccent),
                              _buildControlButton(Icons.visibility, adDisplayMode == 0 ? "Ads OFF" : (adDisplayMode == 1 ? "Ads ON" : "Auto Ads"), _toggleAdMode, Colors.redAccent),
                              
                              _buildControlButton(Icons.dashboard, adShapeMode == 0 ? "Shape: L-Band" : "Shape: U-Band", _toggleAdShapeMode, Colors.orangeAccent),
                              _buildControlButton(Icons.picture_in_picture_alt, "Logo Pos", _changeLogoPosition, Colors.lightGreenAccent),
                              _buildControlButton(Icons.swap_horiz, "L-Band L/R", _toggleLBandDirection, Colors.orange),
                              _buildControlButton(Icons.screen_rotation, "Rotate", _toggleRotation, Colors.purpleAccent),
                              
                              _buildControlButton(Icons.settings, "Settings", _showEditDialog, Colors.blue),
                            ]
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }
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
          CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade800, child: Icon(icon, color: iconColor, size: 28)), 
          const SizedBox(height: 8), 
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
        ]
      )
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
  CameraController? _cameraController;
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
        _cameraController = CameraController(cam, ResolutionPreset.max, enableAudio: true); 
        await _cameraController!.initialize(); 
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
    bool success = await StreamServiceManager.startLiveStream(cableUrl, noiseCancel: isNoiseCancellationEnabled);
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
      if (_cameraController != null && _cameraController!.value.isInitialized) return CameraPreview(_cameraController!); 
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
    bool success = await StreamServiceManager.startLiveStream(cableUrl, noiseCancel: isNoiseCancellationEnabled);
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
