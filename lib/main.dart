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
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt; // 🔴 యాడ్ చేయబడింది
import 'editor_tool.dart';
import 'news_production/ui/news_desk_screen.dart';
import 'election_board.dart'; // 🔴 యాడ్ చేయబడింది

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
      title: 'KINGJVR',
      debugShowCheckedModeBanner: false,
      home: StudioScreen(),
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

  static Future<bool> startLiveStreamMulti(String cableUrl, String restreamUrl, String satUrl) async {
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
    try {
      final result = await _streamChannel.invokeMethod<bool>('stopScreenCaptureStreaming');
      return result == true;
    } catch (e) { return false; }
  }

  static Future<bool> pauseLiveStream() async { return stopLiveStream(); }

  static Future<int?> startUsbCamera() async {
    try { return await const MethodChannel('com.kingjvr.pocket_pcr/uvc').invokeMethod<int>('startUsbCamera'); } 
    catch (e) { return null; }
  }

  static Future<void> stopUsbCamera() async {
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

  CameraController? controller;

  VlcPlayerController? _vlcBulletinCtrl;
  List<String> localVideoPlaylist = [];
  int currentLocalVideoIndex = 0;

  YoutubePlayerController? _ytController;
  VideoPlayerController? _bulletinVideoController; 
  VideoPlayerController? _bottomAdVideoController;
  VideoPlayerController? _leftAdVideoCtrl;
  VideoPlayerController? _rightAdVideoCtrl;
  VideoPlayerController? _bottomAdVideoCtrlForAds;
  VideoPlayerController? _logoVideoCtrl;
  VlcPlayerController? _vlcIpCamController;

  List<String> dualMediaList = [];
  int currentDualMediaIndex = 0;

  bool isLiveLocked = false;
  bool hideControls = false;
  bool isMenuOpen = false;
  bool showReporterDetails = true; 

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
  bool isYoutubeMode = false;
  bool isBulletinMuted = false;
  bool isCameraVisible = true;
  bool isYoutubeLoading = false;
  bool isNoiseCancellationEnabled = true;
  bool _isCameraInitialized = false;

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  double _baseScale = 1.0;

  final ImagePicker _picker = ImagePicker();

  String channelLogoPath = "";
  String studioBgImagePath = ""; 
  double logoWidth = 95.0;
  double logoHeight = 95.0;

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

  List<TextEditingController> extraIpCtrls = List.generate(4, (i) => TextEditingController());
  List<TextEditingController> extraUsbCtrls = List.generate(4, (i) => TextEditingController());
  List<TextEditingController> droneCtrls = List.generate(2, (i) => TextEditingController());

  Timer? _newsTimer;
  Timer? _adCycleTimer;

  int _tickerBgColorIndex = 0;
  Timer? _tickerColorTimer;
  final List<Color> bgColors = [
    const Color(0xFF0D47A1), 
    const Color(0xFF800000), 
    Colors.purple.shade900, 
    Colors.teal.shade900
  ];

  List<String> leftAdPaths = [];
  List<String> rightAdPaths = [];
  List<String> bottomAdPaths = [];
  int leftAdIndex = 0;
  int rightAdIndex = 0;
  int bottomAdIndex = 0;

  bool isExternalIpCamMode = false;
  bool isUsbCamMode = false;
  int? _usbTextureId;

  Widget _buildStandbyScreen() {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.satellite_alt, color: Colors.white24, size: 60),
            SizedBox(height: 15),
            Text(
              "STANDBY / NO SIGNAL", 
              style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 3.0)
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);

    _loadSavedData();   
    _requestPermissionsAndInitCamera();  
    _fetchBreakingNews();  

    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) { _fetchBreakingNews(); });
    _tickerColorTimer = Timer.periodic(const Duration(seconds: 2), (timer) { 
      if (mounted) setState(() => _tickerBgColorIndex++); 
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
          titles.add(item.findElements('title').first.innerText.replaceAll(RegExp(r'^[0-9]+[smh]\sTrend:\s', caseSensitive: false), ''));
        }
        if (titles.isNotEmpty && mounted) {
          setState(() { breakingNewsText = titles.join("   ♦   "); });
        }
      }
    } catch (e) {}
  }

  void _setLogo(String path) {
    setState(() { channelLogoPath = path; });
    if (_logoVideoCtrl != null) {
      _logoVideoCtrl!.dispose();
      _logoVideoCtrl = null;
    }
    if (path.toLowerCase().endsWith('.mp4')) {
      _logoVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) {
        if (mounted) { 
          _logoVideoCtrl!.setLooping(true); 
          _logoVideoCtrl!.setVolume(0); 
          _logoVideoCtrl!.play(); 
          setState(() {}); 
        }
      });
    }
  }

  Future<void> _loadSavedData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
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
        restreamRtmpController.text = prefs.getString('restreamRtmp') ?? "";
        satelliteSrtController.text = prefs.getString('satelliteSrt') ?? "";
        youtubeVideoUrlCtrl.text = prefs.getString('youtubeVideoUrl') ?? "";
        networkVideoUrlCtrl.text = prefs.getString('networkVideoUrl') ?? "";

        watermarkCtrl.text = watermarkText;
        locCtrl.text = locationText;
        nameCtrl.text = reporterName;
        roleCtrl.text = reporterRole;
        mainHeadlineCtrl.text = splitScreenMainHeadline;
        subHeadlineCtrl.text = splitScreenSubHeadline;

        ipCamUrlCtrl.text = prefs.getString('ipCamUrl') ?? "http://192.168.1.100:8080/video";
        usbCamUrlCtrl.text = prefs.getString('usbCamUrl') ?? "/dev/video0";

        for (int i = 0; i < 4; i++) {
          extraIpCtrls[i].text = prefs.getString('extraIp_$i') ?? "";
          extraUsbCtrls[i].text = prefs.getString('extraUsb_$i') ?? "";
        }

        for (int i = 0; i < 2; i++) {
          droneCtrls[i].text = prefs.getString('drone_$i') ?? "";
        }

        String savedLogo = prefs.getString('channelLogoPath') ?? "";
        if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) {
          _setLogo(savedLogo);
        } else {
          channelLogoPath = "";
        }

        studioBgImagePath = prefs.getString('studioBgImagePath') ?? "";

        leftAdPaths = (prefs.getStringList('leftAdPaths') ?? [])
            .where((p) => File(p).existsSync()).toList();

        rightAdPaths = (prefs.getStringList('rightAdPaths') ?? [])
            .where((p) => File(p).existsSync()).toList();

        bottomAdPaths = (prefs.getStringList('bottomAdPaths') ?? [])
            .where((p) => File(p).existsSync()).toList();

        if (leftAdPaths.isNotEmpty) _initAdVideo('left');
        if (rightAdPaths.isNotEmpty) _initAdVideo('right');
        if (bottomAdPaths.isNotEmpty) _initAdVideo('bottom');
      });
    } catch (e) {}
  }

  void _initAdVideo(String pos) {
    String path = "";

    if (pos == 'left' && leftAdPaths.isNotEmpty) {
      path = leftAdPaths[leftAdIndex % leftAdPaths.length];
    }

    if (pos == 'right' && rightAdPaths.isNotEmpty) {
      path = rightAdPaths[rightAdIndex % rightAdPaths.length];
    }

    if (pos == 'bottom' && bottomAdPaths.isNotEmpty) {
      path = bottomAdPaths[bottomAdIndex % bottomAdPaths.length];
    }

    if (path.isEmpty) return;

    bool isVideo = path.toLowerCase().endsWith('.mp4') ||
        path.toLowerCase().endsWith('.mov') ||
        path.toLowerCase().endsWith('.gif');

    if (pos == 'left') {
      if (_leftAdVideoCtrl != null) {
        _leftAdVideoCtrl!.dispose();
        _leftAdVideoCtrl = null;
      }

      if (isVideo) {
        _leftAdVideoCtrl =
            VideoPlayerController.file(File(path))
              ..initialize().then((_) {
                if (mounted) {
                  _leftAdVideoCtrl!.setLooping(true);
                  _leftAdVideoCtrl!.setVolume(0.0);
                  _leftAdVideoCtrl!.play();
                  setState(() {});
                }
              });
      }
    } else if (pos == 'right') {
      if (_rightAdVideoCtrl != null) {
        _rightAdVideoCtrl!.dispose();
        _rightAdVideoCtrl = null;
      }

      if (isVideo) {
        _rightAdVideoCtrl =
            VideoPlayerController.file(File(path))
              ..initialize().then((_) {
                if (mounted) {
                  _rightAdVideoCtrl!.setLooping(true);
                  _rightAdVideoCtrl!.setVolume(0.0);
                  _rightAdVideoCtrl!.play();
                  setState(() {});
                }
              });
      }
    } else if (pos == 'bottom') {
      if (_bottomAdVideoCtrlForAds != null) {
        _bottomAdVideoCtrlForAds!.dispose();
        _bottomAdVideoCtrlForAds = null;
      }

      if (isVideo) {
        _bottomAdVideoCtrlForAds =
            VideoPlayerController.file(File(path))
              ..initialize().then((_) {
                if (mounted) {
                  _bottomAdVideoCtrlForAds!.setLooping(true);
                  _bottomAdVideoCtrlForAds!.setVolume(0.0);
                  _bottomAdVideoCtrlForAds!.play();
                  setState(() {});
                }
              });
      }
    }
  }
  Future<void> _saveTextSettings() async {
    try {
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
    } catch (e) {}
  }

  void _saveLinks() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cableRtmp', cableRtmpController.text.trim());
      prefs.setString('restreamRtmp', restreamRtmpController.text.trim());
      prefs.setString('satelliteSrt', satelliteSrtController.text.trim());
      prefs.setString('youtubeVideoUrl', youtubeVideoUrlCtrl.text.trim());
      prefs.setString('networkVideoUrl', networkVideoUrlCtrl.text.trim());
      prefs.setString('ipCamUrl', ipCamUrlCtrl.text.trim());
      prefs.setString('usbCamUrl', usbCamUrlCtrl.text.trim());

      for (int i = 0; i < 4; i++) {
        prefs.setString('extraIp_$i', extraIpCtrls[i].text.trim());
        prefs.setString('extraUsb_$i', extraUsbCtrls[i].text.trim());
      }

      for (int i = 0; i < 2; i++) {
        prefs.setString('drone_$i', droneCtrls[i].text.trim());
      }
    });
  }

  Future<void> _saveAdPaths(String pos, List<String> paths) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      if (pos == 'left') {
        await prefs.setStringList('leftAdPaths', paths);
      }

      if (pos == 'right') {
        await prefs.setStringList('rightAdPaths', paths);
      }

      if (pos == 'bottom') {
        await prefs.setStringList('bottomAdPaths', paths);
      }
    } catch (e) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (isCameraVisible &&
          !isExternalIpCamMode &&
          !isUsbCamMode &&
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

    _vlcBulletinCtrl?.removeListener(_vlcListener);
    _vlcBulletinCtrl?.dispose();

    _bulletinVideoController?.removeListener(_videoListener);
    _bulletinVideoController?.dispose();

    _ytController?.dispose();
    _bottomAdVideoController?.dispose();
    _leftAdVideoCtrl?.dispose();
    _rightAdVideoCtrl?.dispose();
    _bottomAdVideoCtrlForAds?.dispose();
    _logoVideoCtrl?.dispose();
    _vlcIpCamController?.dispose();

    restreamRtmpController.dispose();
    cableRtmpController.dispose();
    satelliteSrtController.dispose();
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

    for (var c in extraIpCtrls) {
      c.dispose();
    }

    for (var c in extraUsbCtrls) {
      c.dispose();
    }

    for (var c in droneCtrls) {
      c.dispose();
    }

    super.dispose();
  }

  Future<void> _requestPermissionsAndInitCamera() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
      Permission.photos,
      Permission.videos,
      Permission.notification,
    ].request();

    if (!mounted) return;

    setState(() {
      isCameraVisible = true;
    });

    await _initCamera();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
      } catch (e) {
        debugPrint("Camera Discovery Error: $e");
      }
    }

    if (cameras.isEmpty) return;

    try {
      if (currentCameraIndex >= cameras.length) {
        currentCameraIndex = 0;
      }

      if (controller != null) {
        await controller!.dispose();
      }

      final camController = CameraController(
        cameras[currentCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      controller = camController;

      await camController.initialize();

      if (!mounted) return;

      _minZoomLevel = await camController.getMinZoomLevel();
      _maxZoomLevel = await camController.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint("Camera Initialization Error: $e");
    }
  }

  void _switchCamera() async {
    if (isExternalIpCamMode || isUsbCamMode) {
      showCustomToast(
        context,
        "ఎక్స్‌టర్నల్ కెమెరా మోడ్‌లో ఫోన్ కెమెరా స్విచ్ పనిచేయదు.",
        isLive: isLiveBroadcasting,
      );
      return;
    }

    if (cameras.length < 2) return;

    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;

    if (isCameraVisible) {
      await _initCamera();
    }

    if (!mounted) return;

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
        _usbTextureId = null;
      });

      _vlcIpCamController?.dispose();
      _vlcIpCamController = null;

      try {
        await StreamServiceManager.stopUsbCamera();
      } catch (e) {
        debugPrint("USB Camera Stop Error: $e");
      }

      return;
    }

    if (isCameraVisible) {
      setState(() {
        isCameraVisible = false;
        _isCameraInitialized = false;
      });

      await controller?.dispose();
      controller = null;
    } else {
      setState(() {
        isCameraVisible = true;
      });

      await _initCamera();
    }
  }

  Future<void> _startIpCamera(String url) async {
    if (url.isEmpty) return;

    showCustomToast(
      context,
      "IP కెమెరాకు కనెక్ట్ అవుతోంది...",
      isLive: isLiveBroadcasting,
    );

    try {
      _vlcIpCamController?.dispose();

      _vlcIpCamController = VlcPlayerController.network(
        url,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(),
      );

      if (!mounted) return;

      setState(() {
        isExternalIpCamMode = true;
        isUsbCamMode = false;
        isCameraVisible = true;
        isNewsBulletinMode = false;
        isYoutubeMode = false;
        isNetworkVideoMode = false;
        isDualScreenMode = false;
      });
    } catch (e) {
      debugPrint("IP Camera Error: $e");

      if (mounted) {
        showCustomToast(
          context,
          "IP కెమెరా కనెక్ట్ కాలేదు. లింక్ చెక్ చేయండి.",
          isLive: isLiveBroadcasting,
        );
      }
    }
  }

  Future<void> _startUsbCamera(String url) async {
    try {
      final int? textureId =
          await StreamServiceManager.startUsbCamera();

      if (textureId != null) {
        if (!mounted) return;

        setState(() {
          isUsbCamMode = true;
          isExternalIpCamMode = false;
          isCameraVisible = true;
          isNewsBulletinMode = false;
          isYoutubeMode = false;
          isNetworkVideoMode = false;
          _usbTextureId = textureId;
        });

        showCustomToast(
          context,
          "USB Capture Card కనెక్ట్ అయ్యింది!",
          isLive: isLiveBroadcasting,
        );
      }
    } on PlatformException catch (e) {
      debugPrint("USB Camera Platform Error: $e");

      if (mounted) {
        showCustomToast(
          context,
          "USB క్యాప్చర్ కార్డ్ ఎర్రర్.",
          isLive: isLiveBroadcasting,
        );
      }
    } catch (e) {
      debugPrint("USB Camera Error: $e");
    }
  }

  void _showExternalCamsDialog() {
    setState(() {
      isMenuOpen = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: DefaultTabController(
            length: 3,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "External Cameras & PCR Setup",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  const TabBar(
                    indicatorColor: Colors.amber,
                    labelColor: Colors.amber,
                    unselectedLabelColor: Colors.white54,
                    tabs: [
                      Tab(
                        icon: Icon(
                          Icons.wifi_tethering,
                          size: 20,
                        ),
                        text: "IP Cams",
                      ),
                      Tab(
                        icon: Icon(
                          Icons.usb,
                          size: 20,
                        ),
                        text: "USB Cams",
                      ),
                      Tab(
                        icon: Icon(
                          Icons.flight,
                          size: 20,
                        ),
                        text: "Drones",
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: TabBarView(
                      children: [

                        // IP CAMERA TAB
                        ListView(
                          children: [
                            const Text(
                              "1. Main IP Camera (Studio Connect)",
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 5),

                            TextField(
                              controller: ipCamUrlCtrl,
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: "rtsp://...",
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),

                            const SizedBox(height: 5),

                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                              ),
                              onPressed: () {
                                _saveLinks();
                                Navigator.pop(dialogContext);

                                _startIpCamera(
                                  ipCamUrlCtrl.text.trim(),
                                );
                              },
                              icon: const Icon(
                                Icons.cast,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                "Connect to Main Screen",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),

                            const Divider(
                              color: Colors.white24,
                              height: 25,
                            ),

                            const Text(
                              "PCR Board IP Cameras (2 to 5)",
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 5),

                            for (int i = 0; i < 4; i++) ...[
                              Text(
                                "IP Cam ${i + 2}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),

                              TextField(
                                controller: extraIpCtrls[i],
                                style: const TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 12,
                                ),
                                decoration: const InputDecoration(
                                  hintText: "rtsp://...",
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),
                            ],
                          ],
                        ),

                        // USB CAMERA TAB
                        ListView(
                          children: [
                            const Text(
                              "1. Main USB Camera (Studio Connect)",
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 5),

                            TextField(
                              controller: usbCamUrlCtrl,
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: "/dev/video0",
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),

                            const SizedBox(height: 5),

                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent,
                              ),
                              onPressed: () {
                                Navigator.pop(dialogContext);

                                _startUsbCamera(
                                  usbCamUrlCtrl.text.trim(),
                                );
                              },
                              icon: const Icon(
                                Icons.usb,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                "Start USB Camera",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),

                            const Divider(
                              color: Colors.white24,
                              height: 25,
                            ),

                            const Text(
                              "PCR Board USB Cameras (2 to 5)",
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 5),

                            for (int i = 0; i < 4; i++) ...[
                              Text(
                                "USB Cam ${i + 2}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),

                              TextField(
                                controller: extraUsbCtrls[i],
                                style: const TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 12,
                                ),
                                decoration: const InputDecoration(
                                  hintText: "Device Path or Link",
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white24,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),
                            ],
                          ],
                        ),

                        // DRONE CAMERA TAB
                        ListView(
                          children: [
                            const Text(
                              "PCR Board Drones (1 & 2)",
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 10),

                            for (int i = 0; i < 2; i++) ...[
                              Text(
                                "Drone ${i + 1}",
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 11,
                                ),
                              ),

                              TextField(
                                controller: droneCtrls[i],
                                style: const TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  hintText: "rtsp://...",
                                  filled: true,
                                  fillColor: Colors.black26,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 15),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        child: const Text(
                          "Close",
                          style: TextStyle(
                            color: Colors.redAccent,
                          ),
                        ),
                      ),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();

                          _saveLinks();

                          if (mounted) {
                            showCustomToast(
                              context,
                              "కెమెరా లింక్స్ అన్నీ సేవ్ అయ్యాయి!",
                              isLive: isLiveBroadcasting,
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.save,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          "Save All Links",
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLiveControlDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Live Control Room", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  _buildLinkEditor("1. Primary Live Stream (Cable / RTMP)", cableRtmpController, dialogContext, onPlay: null),
                  const Divider(color: Colors.white24, height: 25),

                  _buildLinkEditor("2. Secondary Live Stream (Restream / YT)", restreamRtmpController, dialogContext, onPlay: null),
                  const Divider(color: Colors.white24, height: 25),

                  _buildLinkEditor("3. Backup Stream (Satellite SRT)", satelliteSrtController, dialogContext, onPlay: null),
                  const Divider(color: Colors.white24, height: 25),

                  _buildLinkEditor("4. YouTube Live Video Link", youtubeVideoUrlCtrl, dialogContext, onPlay: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    _startYoutubeVideo(youtubeVideoUrlCtrl.text.trim());
                  }),
                  const Divider(color: Colors.white24, height: 25),

                  _buildLinkEditor("5. Direct Network Video (MP4/m3u8)", networkVideoUrlCtrl, dialogContext, onPlay: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    _startNetworkVideoMp4(networkVideoUrlCtrl.text.trim());
                  }),
                  const Divider(color: Colors.white24, height: 25),

                  const Text("6. గ్యాలరీ వీడియో (MP4, HD, 4K)", style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        _playLocalGalleryVideo();
                      },
                      icon: const Icon(Icons.video_library, color: Colors.white, size: 20),
                      label: const Text("గ్యాలరీ వీడియో తీసుకోండి (Multiple)", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))
                    )
                  ),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context, rootNavigator: true).pop();
                        },
                        child: const Text("Close", style: TextStyle(color: Colors.white, fontSize: 15))
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          _saveLinks();
                          Navigator.of(context, rootNavigator: true).pop();
                          Future.delayed(const Duration(milliseconds: 300), () {
                            _startLiveAndLock();
                          });
                        },
                        child: const Text("START BROADCAST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))
                      )
                    ]
                  )
                ]
              )
            ),
          ),
        );
      }
    );
  }

  Widget _buildLinkEditor(String label, TextEditingController controller, BuildContext dialogContext, {VoidCallback? onPlay}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.yellow, fontSize: 13, fontWeight: FontWeight.bold),
                onChanged: (val) { _saveLinks(); },
                decoration: const InputDecoration(
                  hintText: "Paste link here...",
                  hintStyle: TextStyle(color: Colors.white24, fontWeight: FontWeight.normal),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent))
                )
              )
            ),
            IconButton(
              icon: const Icon(Icons.save, color: Colors.blueAccent, size: 28),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                _saveLinks();
                if (mounted) {
                  showCustomToast(context, "✔️ లింక్ సేవ్ అయ్యింది!", isLive: isLiveBroadcasting);
                }
              }
            ),
            if (onPlay != null)
              IconButton(
                icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 34),
                onPressed: onPlay
              )
          ]
        )
      ]
    );
  }

    Future<void> _startYoutubeVideo(String url) async {
    if (url.isEmpty) return;
    String cleanUrl = url.trim();

    setState(() { isYoutubeLoading = true; isCameraVisible = false; });  
    showCustomToast(context, "యూట్యూబ్ వీడియో లోడ్ అవుతోంది...", isLive: isLiveBroadcasting);  

    try {  
      String finalPlayUrl = "";  
      
      if (cleanUrl.contains("youtube.com") || cleanUrl.contains("youtu.be")) {  
        var ytExplode = yt.YoutubeExplode();  
        
        // 🔴 1. లింక్ నుండి ఒరిజినల్ ఐడీని పక్కాగా లాగే మ్యాజిక్ కోడ్
        var videoId = yt.VideoId(cleanUrl);  
        var video = await ytExplode.videos.get(videoId);  
          
        if (video.isLive) {  
          finalPlayUrl = await ytExplode.videos.streamsClient.getHttpLiveStreamUrl(video.id);  
        } else {  
          var manifest = await ytExplode.videos.streamsClient.getManifest(video.id);  
          var muxedStreams = manifest.muxed;
          
          if (muxedStreams.isNotEmpty) {  
            finalPlayUrl = muxedStreams.withHighestBitrate().url.toString();  
          } else {
            throw Exception("డైరెక్ట్ MP4 ఫార్మాట్ దొరకలేదు.");
          }
        }  
        ytExplode.close();  
      } else {
        // ఒకవేళ యూట్యూబ్ లింక్ కాకపోతే డైరెక్ట్ గా తీసుకుంటుంది
        finalPlayUrl = cleanUrl;
      }

      if (finalPlayUrl.isNotEmpty) {  
        _playNetworkBulletin(finalPlayUrl);  
      } else {  
        throw Exception("వీడియో లింక్ క్రియేట్ అవ్వలేదు.");  
      }  
    } catch (e) {  
      debugPrint("YouTube Extract Error: $e");
      if (mounted) {  
        setState(() { isYoutubeLoading = false; hideControls = false; isCameraVisible = true; isNewsBulletinMode = false; });  
        showCustomToast(context, "యూట్యూబ్ వీడియో ప్లే కాలేదు. వేరే లింక్ ట్రై చేయండి.", isLive: isLiveBroadcasting);  
      }  
    }
  }

  void _playNetworkBulletin(String playUrl) {
    void _playNetworkBulletin(String playUrl) {
    if (_bulletinVideoController != null) {
      _bulletinVideoController!.removeListener(_videoListener);
      _bulletinVideoController!.dispose();
      _bulletinVideoController = null;
    }

    _bulletinVideoController = VideoPlayerController.networkUrl(
      Uri.parse(playUrl),
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
      },
    )..initialize().then((_) {   
        if (!mounted) return;   
        _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);   
        setState(() {   
          isNewsBulletinMode = true; 
          isNetworkVideoMode = false; 
          isDualScreenMode = false; 
          hideControls = false; 
          isYoutubeLoading = false; 
          isCameraVisible = false;  
        });   
        _bulletinVideoController?.play();   
        _bulletinVideoController?.addListener(_videoListener);   
          
        if (!isLiveBroadcasting) { _startLiveAndLock(); }  
      }).catchError((e) {   
        debugPrint("Video Player Error: $e");
        if (mounted) {  
          setState(() { isYoutubeLoading = false; isCameraVisible = true; isNewsBulletinMode = false; });  
          showCustomToast(context, "వీడియో ప్లే అవ్వడం లేదు.", isLive: isLiveBroadcasting);  
        }  
      });
    } 

    void _playNetworkBulletin(String playUrl) {
    if (_bulletinVideoController != null) {
      _bulletinVideoController!.removeListener(_videoListener);
      _bulletinVideoController!.dispose();
      _bulletinVideoController = null;
    }

    // 🔴 హెడర్స్ ఎర్రర్ రాకుండా సింపుల్ నెట్‌వర్క్ యూఆర్ఎల్ వాడాము
    _bulletinVideoController = VideoPlayerController.networkUrl(Uri.parse(playUrl))
      ..initialize().then((_) {   
        if (!mounted) return;   
        _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);   
        setState(() {   
          isNewsBulletinMode = true; 
          isNetworkVideoMode = false; 
          isDualScreenMode = false; 
          hideControls = false; 
          isYoutubeLoading = false; 
          isCameraVisible = false;  
        });   
        _bulletinVideoController?.play();   
        _bulletinVideoController?.addListener(_videoListener);   
          
        if (!isLiveBroadcasting) { _startLiveAndLock(); }  
      }).catchError((e) {   
        debugPrint("Video Player Error: $e");
        if (mounted) {  
          setState(() { isYoutubeLoading = false; isCameraVisible = true; isNewsBulletinMode = false; });  
          showCustomToast(context, "వీడియో ప్లే అవ్వడం లేదు.", isLive: isLiveBroadcasting);  
        }  
      });
  }

  Future<void> _startNetworkVideoMp4(String url) async {
    if (url.isEmpty) return;
    _playNetworkBulletin(url.trim());
  }

  Future<void> _startLiveAndLock() async {
    _saveLinks();
    String cableUrl = cableRtmpController.text.trim();
    String restreamUrl = restreamRtmpController.text.trim();
    String satUrl = satelliteSrtController.text.trim();

    if (cableUrl.isEmpty && restreamUrl.isEmpty && satUrl.isEmpty) {
      showCustomToast(context, "దయచేసి కనీసం ఒక లైవ్ లింక్ ఇవ్వండి.", isLive: isLiveBroadcasting);
      return;
    }

    try {
      try {
        var micStatus = await Permission.microphone.status;
        if (!micStatus.isGranted) {
          await Permission.microphone.request();
        }
      } catch (e) {}

      setState(() {
        hideControls = true;
        isMenuOpen = false;
        isLandscape = true;
      });

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft
      ]);

      showCustomToast(context, "లైవ్ కనెక్ట్ అవుతోంది... దయచేసి వేచి ఉండండి", isLive: false);

      await Future.delayed(const Duration(milliseconds: 3000));

      bool success = await StreamServiceManager.startLiveStreamMulti(
        cableUrl,
        restreamUrl,
        satUrl
      ).timeout(const Duration(seconds: 60));

      if (success) {
        setState(() {
          isLiveBroadcasting = true;
          isLivePaused = false;
          isLiveLocked = false;
        });
        showCustomToast(context, "లైవ్ మొదలైంది", isLive: true);
      } else {
        setState(() {
          hideControls = false;
        });
        showCustomToast(context, "బ్రాడ్ కాస్ట్ ఫెయిల్. సిస్టమ్ ఫాల్స్ ఇచ్చింది.", isLive: false);
      }
    } on TimeoutException catch (_) {
      setState(() {
        hideControls = false;
      });
      showCustomToast(context, "టైమ్ అవుట్: కనెక్ట్ అవ్వడానికి సమయం పట్టింది.", isLive: false);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight
      ]);
    } catch (e) {
      setState(() {
        hideControls = false;
      });
      showCustomToast(context, "ఎర్రర్: $e", isLive: false);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight
      ]);
    }
  }

  Future<void> _playLocalGalleryVideo() async {
    try {
      final List<XFile> mediaFiles = await _picker.pickMultipleMedia();
      if (mediaFiles.isNotEmpty) {
        List<String> videoPaths = mediaFiles.map((e) => e.path).where((path) {
          String lower = path.toLowerCase();
          return lower.endsWith('.mp4') ||
              lower.endsWith('.mov') ||
              lower.endsWith('.mkv') ||
              lower.endsWith('.avi');
        }).toList();

        if (videoPaths.isEmpty) {
          if (mounted) {
            showCustomToast(
              context,
              "వీడియోలను మాత్రమే సెలెక్ట్ చేయండి.",
              isLive: isLiveBroadcasting,
            );
          }
          return;
        }

        localVideoPlaylist = videoPaths;
        currentLocalVideoIndex = 0;
        _playNextVlcVideo();
      }
    } catch (e) {
      debugPrint("Gallery Video Selection Error: $e");
    }
  }

  void _playNextVlcVideo() {
    if (currentLocalVideoIndex >= localVideoPlaylist.length) {
      setState(() {
        isNewsBulletinMode = false;
        isCameraVisible = true;
      });
      return;
    }

    if (mounted) {
      showCustomToast(
        context,
        "వీడియో ${currentLocalVideoIndex + 1}/${localVideoPlaylist.length} ప్లే అవుతోంది...",
        isLive: isLiveBroadcasting,
      );
    }

    if (_vlcBulletinCtrl != null) {
      _vlcBulletinCtrl!.removeListener(_vlcListener);
      _vlcBulletinCtrl!.dispose();
      _vlcBulletinCtrl = null;
    }

    _vlcBulletinCtrl = VlcPlayerController.file(
      File(localVideoPlaylist[currentLocalVideoIndex]),
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(),
    )..initialize().then((_) {
        if (!mounted) return;

        _vlcBulletinCtrl?.setVolume(isBulletinMuted ? 0 : 100);

        setState(() {
          isNewsBulletinMode = true;
          isYoutubeMode = false;
          isNetworkVideoMode = false;
          isDualScreenMode = false;
          hideControls = false;
          isCameraVisible = false;
        });

        _vlcBulletinCtrl?.play();
        _vlcBulletinCtrl?.addListener(_vlcListener);

        if (!isLiveBroadcasting) {
          _startLiveAndLock();
        }
      }).catchError((e) {
        if (mounted) {
          showCustomToast(
            context,
            "వీడియో ప్లే కాలేదు. ఫార్మాట్ ఎర్రర్.",
            isLive: isLiveBroadcasting,
          );
          currentLocalVideoIndex++;
          _playNextVlcVideo();
        }
      });
  }

  void _vlcListener() {
    final ctrl = _vlcBulletinCtrl;
    if (ctrl == null) return;

    if (ctrl.value.isEnded) {
      ctrl.removeListener(_vlcListener);
      currentLocalVideoIndex++;
      _playNextVlcVideo();
    }
  }

  void _toggleMute() {
    HapticFeedback.mediumImpact();

    setState(() {
      isBulletinMuted = !isBulletinMuted;

      if (isNewsBulletinMode && _vlcBulletinCtrl != null) {
        _vlcBulletinCtrl?.setVolume(isBulletinMuted ? 0 : 100);
      }

      if (isYoutubeMode && _ytController != null) {
        isBulletinMuted
            ? _ytController!.mute()
            : _ytController!.unMute();
      }
    });
  }

  Future<void> _stopLiveStream() async {
    try {
      bool success = await StreamServiceManager.stopLiveStream();

      if (success) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);

        setState(() {
          isLiveBroadcasting = false;
          isLiveLocked = false;
          isLivePaused = false;
        });

        if (mounted) {
          showCustomToast(
            context,
            "లైవ్ ఆగిపోయింది ❌",
            isLive: false,
          );
        }
      }
    } catch (e) {}
  }

  Future<void> _pickAds(String pos) async {
    try {
      final List<XFile> medias = await _picker.pickMultipleMedia();

      if (medias.isNotEmpty && mounted) {
        setState(() {
          if (pos == 'left') {
            leftAdPaths.addAll(medias.map((e) => e.path));
            leftAdIndex = leftAdPaths.length - 1;
            _saveAdPaths(pos, leftAdPaths);
          }

          if (pos == 'right') {
            rightAdPaths.addAll(medias.map((e) => e.path));
            rightAdIndex = rightAdPaths.length - 1;
            _saveAdPaths(pos, rightAdPaths);
          }

          if (pos == 'bottom') {
            bottomAdPaths.addAll(medias.map((e) => e.path));
            bottomAdIndex = bottomAdPaths.length - 1;
            _saveAdPaths(pos, bottomAdPaths);
          }

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
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(
                "Manage ${pos.toUpperCase()} Ads",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: currentPaths.isEmpty
                    ? const Text(
                        "యాడ్స్ ఏమీ లేవు.",
                        style: TextStyle(color: Colors.white54),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: currentPaths.length,
                        itemBuilder: (ctx, idx) {
                          String path = currentPaths[idx];

                          bool isVideo =
                              path.toLowerCase().endsWith('.mp4') ||
                              path.toLowerCase().endsWith('.mov') ||
                              path.toLowerCase().endsWith('.gif');

                          return ListTile(
                            leading: isVideo
                                ? const Icon(
                                    Icons.video_file,
                                    color: Colors.blueAccent,
                                    size: 40,
                                  )
                                : Image.file(
                                    File(path),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                            title: Text(
                              "Ad ${idx + 1}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () {
                                setState(() {
                                  currentPaths.removeAt(idx);
                                  _saveAdPaths(pos, currentPaths);

                                  if (pos == 'left') {
                                    if (leftAdIndex >= leftAdPaths.length) {
                                      leftAdIndex = 0;
                                    }
                                    _initAdVideo('left');
                                  }

                                  if (pos == 'right') {
                                    if (rightAdIndex >= rightAdPaths.length) {
                                      rightAdIndex = 0;
                                    }
                                    _initAdVideo('right');
                                  }

                                  if (pos == 'bottom') {
                                    if (bottomAdIndex >=
                                        bottomAdPaths.length) {
                                      bottomAdIndex = 0;
                                    }
                                    _initAdVideo('bottom');
                                  }
                                });

                                setDialogState(() {});
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  child: const Text(
                    "Clear All",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onPressed: () {
                    setState(() {
                      currentPaths.clear();
                      _saveAdPaths(pos, currentPaths);

                      if (pos == 'left') {
                        leftAdIndex = 0;
                        _leftAdVideoCtrl?.dispose();
                        _leftAdVideoCtrl = null;
                      }

                      if (pos == 'right') {
                        rightAdIndex = 0;
                        _rightAdVideoCtrl?.dispose();
                        _rightAdVideoCtrl = null;
                      }

                      if (pos == 'bottom') {
                        bottomAdIndex = 0;
                        _bottomAdVideoCtrlForAds?.dispose();
                        _bottomAdVideoCtrlForAds = null;
                      }
                    });

                    Navigator.pop(ctx);
                  },
                ),
                TextButton(
                  child: const Text(
                    "Close",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            );
          },
        );
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
                          SharedPreferences prefs = await SharedPreferences.getInstance(); 
                          await prefs.setString('channelLogoPath', media.path); 
                          _setLogo(media.path); 
                          setDialogState(() {}); 
                        } 
                      } catch (e) {} 
                    }, 
                    icon: const Icon(Icons.upload), 
                    label: const Text("ఛానల్ లోగో అప్లోడ్ (MP4/GIF/JPEG)")
                  ), 
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async { 
                      try { 
                        final XFile? img = await _picker.pickImage(source: ImageSource.gallery); 
                        if (img != null) { 
                          SharedPreferences prefs = await SharedPreferences.getInstance(); 
                          await prefs.setString('studioBgImagePath', img.path); 
                          setState(() => studioBgImagePath = img.path); 
                          setDialogState(() {}); 
                          if(mounted) showCustomToast(context, "స్టూడియో బ్యాక్‌గ్రౌండ్ ఇమేజ్ సెట్ అయ్యింది!", isLive: isLiveBroadcasting);
                        } 
                      } catch (e) {} 
                    }, 
                    icon: const Icon(Icons.wallpaper), 
                    label: const Text("స్టూడియో బ్యాక్‌గ్రౌండ్ ఇమేజ్ సెట్ చేయండి", style: TextStyle(fontSize: 12))
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
                    onChanged: (val) { setState(() => isNoiseCancellationEnabled = val); setDialogState(() {}); }, 
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

  Future<void> _toggleDualScreenAndPickMedia() async {
    setState(() { isMenuOpen = false; });
    if (isDualScreenMode) { 
      setState(() { 
        isDualScreenMode = false; 
        dualMediaList.clear(); 
        if (_bottomAdVideoController != null) { 
          _bottomAdVideoController!.dispose(); 
          _bottomAdVideoController = null; 
        } 
      }); 
      return; 
    }
    try {
      final List<XFile> medias = await _picker.pickMultipleMedia();
      if (medias.isNotEmpty && mounted) { 
        dualMediaList = medias.map((e) => e.path).toList(); 
        currentDualMediaIndex = 0; 
        setState(() { 
          isDualScreenMode = true; 
          isNewsBulletinMode = false; 
          isNetworkVideoMode = false;
          isYoutubeMode = false; 
        }); 
        _playDualMedia(dualMediaList[currentDualMediaIndex]); 
      }
    } catch (e) {}
  }

  void _playDualMedia(String path) {
    if (_bottomAdVideoController != null) { _bottomAdVideoController!.dispose(); _bottomAdVideoController = null; }
    if (path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov')) { 
      _bottomAdVideoController = VideoPlayerController.file(File(path))..initialize().then((_) { 
        if (mounted) { 
          _bottomAdVideoController!.setLooping(true); 
          _bottomAdVideoController!.setVolume(1.0); 
          _bottomAdVideoController!.play(); 
          setState(() {}); 
        } 
      }); 
    } else { 
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
        showCustomToast(context, "Ads OFF", isLive: isLiveBroadcasting);
      } else if (adDisplayMode == 1) {
        isAdCurrentlyShowing = true;
        _startPermanentCycle();
        showCustomToast(context, "Ads ON", isLive: isLiveBroadcasting);
      } else if (adDisplayMode == 2) {
        isAdCurrentlyShowing = true;
        _startAutoCycle();
        showCustomToast(context, "Auto Ads", isLive: isLiveBroadcasting);
      }
    });
  }

  void _startPermanentCycle() { 
    _adCycleTimer?.cancel(); 
    _adCycleTimer = Timer.periodic(const Duration(seconds: 20), (timer) { 
      if (mounted && adDisplayMode == 1) { 
        setState(() { 
          if (leftAdPaths.isNotEmpty) leftAdIndex = ((leftAdIndex + 1) % leftAdPaths.length).toInt(); 
          if (rightAdPaths.isNotEmpty) rightAdIndex = ((rightAdIndex + 1) % rightAdPaths.length).toInt(); 
          if (bottomAdPaths.isNotEmpty) bottomAdIndex = ((bottomAdIndex + 1) % bottomAdPaths.length).toInt(); 
          _initAdVideo('left'); 
          _initAdVideo('right'); 
          _initAdVideo('bottom'); 
        }); 
      } 
    }); 
  }

  void _startAutoCycle() { 
    _adCycleTimer?.cancel(); 
    if (isAdCurrentlyShowing) { 
      _adCycleTimer = Timer(const Duration(seconds: 20), () { 
        if (mounted && adDisplayMode == 2) { 
          setState(() => isAdCurrentlyShowing = false); 
          _startAutoCycle(); 
        } 
      }); 
    } else { 
      _adCycleTimer = Timer(const Duration(seconds: 40), () { 
        if (mounted && adDisplayMode == 2) { 
          setState(() { 
            isAdCurrentlyShowing = true; 
            if (leftAdPaths.isNotEmpty) leftAdIndex = ((leftAdIndex + 1) % leftAdPaths.length).toInt(); 
            if (rightAdPaths.isNotEmpty) rightAdIndex = ((rightAdIndex + 1) % rightAdPaths.length).toInt(); 
            if (bottomAdPaths.isNotEmpty) bottomAdIndex = ((bottomAdIndex + 1) % bottomAdPaths.length).toInt(); 
            _initAdVideo('left'); 
            _initAdVideo('right'); 
            _initAdVideo('bottom'); 
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

  void _toggleReporterDetails() {
    setState(() {
      showReporterDetails = !showReporterDetails;
      isMenuOpen = false;
    });
    showCustomToast(context, showReporterDetails ? "రిపోర్టర్ డీటెయిల్స్ ఆన్ చేయబడ్డాయి" : "రిపోర్టర్ డీటెయిల్స్ ఆఫ్ చేయబడ్డాయి", isLive: isLiveBroadcasting);
  }

  Widget _buildMainDisplay(
    bool isScreenLandscape,
    double screenWidth,
    double screenHeight,
    Widget phoneCameraWidget,
  ) {
    Widget actualCameraWidget;

    if (isLivePaused) {
      actualCameraWidget = Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            "LIVE PAUSED",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else if (isExternalIpCamMode && _vlcIpCamController != null) {
      actualCameraWidget = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 1920,
            height: 1080,
            child: VlcPlayer(
              controller: _vlcIpCamController!,
              aspectRatio: 16 / 9,
              placeholder: const Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            ),
          ),
        ),
      );
    } else if (isUsbCamMode && _usbTextureId != null) {
      actualCameraWidget = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 1920,
            height: 1080,
            child: Texture(textureId: _usbTextureId!),
          ),
        ),
      );
    } else if (phoneCameraWidget is Container &&
        phoneCameraWidget.color == Colors.transparent) {
      actualCameraWidget = _buildStandbyScreen();
    } else {
      actualCameraWidget = phoneCameraWidget;
    }

    if (isDualScreenMode && dualMediaList.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: const Color(0xFF800000),
            width: 3.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
            ),
          ],
        ),
        child: isScreenLandscape
            ? Row(
                children: [
                  Expanded(child: actualCameraWidget),
                  Container(
                    width: 3,
                    color: const Color(0xFF800000),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (details) {
                                  double dx = details.localPosition.dx;

                                  if (dx < constraints.maxWidth / 3) {
                                    _prevDualMedia();
                                  } else if (dx >
                                      constraints.maxWidth * 2 / 3) {
                                    _nextDualMedia();
                                  } else {
                                    _toggleDualMediaPause();
                                  }
                                },
                                child: _bottomAdVideoController != null &&
                                        _bottomAdVideoController!
                                            .value.isInitialized
                                    ? FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _bottomAdVideoController!
                                              .value.size.width,
                                          height: _bottomAdVideoController!
                                              .value.size.height,
                                          child: VideoPlayer(
                                            _bottomAdVideoController!,
                                          ),
                                        ),
                                      )
                                    : Image.file(
                                        File(
                                          dualMediaList[currentDualMediaIndex],
                                        ),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                              );
                            },
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          color: Colors.amber,
                          child: Text(
                            splitScreenMainHeadline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.blueAccent,
                          child: Text(
                            splitScreenSubHeadline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: actualCameraWidget,
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 15,
                    ),
                    color: Colors.amber,
                    child: Text(
                      splitScreenMainHeadline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    color: Colors.blueAccent,
                    child: Text(
                      splitScreenSubHeadline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (details) {
                            double dx = details.localPosition.dx;

                            if (dx < constraints.maxWidth / 3) {
                              _prevDualMedia();
                            } else if (dx >
                                constraints.maxWidth * 2 / 3) {
                              _nextDualMedia();
                            } else {
                              _toggleDualMediaPause();
                            }
                          },
                          child: _bottomAdVideoController != null &&
                                  _bottomAdVideoController!
                                      .value.isInitialized
                              ? FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _bottomAdVideoController!
                                        .value.size.width,
                                    height: _bottomAdVideoController!
                                        .value.size.height,
                                    child: VideoPlayer(
                                      _bottomAdVideoController!,
                                    ),
                                  ),
                                )
                              : Image.file(
                                  File(
                                    dualMediaList[currentDualMediaIndex],
                                  ),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      );
    }

    double availableHeight = screenHeight;
    double leftAdWidth = screenWidth * 0.20;
    double videoWidth = screenWidth - leftAdWidth;
    double videoHeight = videoWidth * (9 / 16);
    double bottomAdHeight = availableHeight - videoHeight;

    if (bottomAdHeight < availableHeight * 0.18) {
      bottomAdHeight = availableHeight * 0.18;
      videoHeight = availableHeight - bottomAdHeight;
      videoWidth = videoHeight * (16 / 9);
      leftAdWidth = screenWidth - videoWidth;
    }

    if (isNewsBulletinMode ||
        isNetworkVideoMode ||
        isAdCurrentlyShowing ||
        isYoutubeMode) {
      Widget mainPlayer;

      if (isYoutubeMode && _ytController != null) {
        mainPlayer = YoutubePlayer(
          controller: _ytController!,
          showVideoProgressIndicator: false,
        );
      } else if (isNewsBulletinMode && _vlcBulletinCtrl != null) {
        mainPlayer = SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 1920,
              height: 1080,
              child: VlcPlayer(
                controller: _vlcBulletinCtrl!,
                aspectRatio: 16 / 9,
                placeholder: const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                ),
              ),
            ),
          ),
        );
      } else {
        mainPlayer = actualCameraWidget;
      }

      return Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              left: isAdCurrentlyShowing
                  ? (isLBandRight ? 0 : leftAdWidth)
                  : 0,
              top: 0,
              width: isAdCurrentlyShowing ? videoWidth : screenWidth,
              height: isAdCurrentlyShowing ? videoHeight : availableHeight,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF800000),
                          width: 3.0,
                        ),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: mainPlayer,
                      ),
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
                  onTap: leftAdPaths.isEmpty
                      ? () => _pickAds('left')
                      : null,
                  onLongPress: leftAdPaths.isNotEmpty
                      ? () => _manageAdsDialog('left')
                      : null,
                  child: Container(
                    color: Colors.transparent,
                    child: leftAdPaths.isNotEmpty
                        ? (_leftAdVideoCtrl != null &&
                                _leftAdVideoCtrl!.value.isInitialized
                            ? FittedBox(
                                fit: BoxFit.fill,
                                child: SizedBox(
                                  width:
                                      _leftAdVideoCtrl!.value.size.width,
                                  height:
                                      _leftAdVideoCtrl!.value.size.height,
                                  child: VideoPlayer(_leftAdVideoCtrl!),
                                ),
                              )
                            : SizedBox.expand(
                                child: Image.file(
                                  File(leftAdPaths[leftAdIndex]),
                                  fit: BoxFit.fill,
                                ),
                              ))
                        : const Center(
                            child: Text(
                              "LEFT ADS",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            if (isAdCurrentlyShowing)
              Positioned(
                left: isLBandRight ? 0 : leftAdWidth,
                top: videoHeight,
                width: videoWidth,
                height: bottomAdHeight,
                child: GestureDetector(
                  onTap: bottomAdPaths.isEmpty
                      ? () => _pickAds('bottom')
                      : null,
                  onLongPress: bottomAdPaths.isNotEmpty
                      ? () => _manageAdsDialog('bottom')
                      : null,
                  child: Container(
                    color: Colors.transparent,
                    child: bottomAdPaths.isNotEmpty
                        ? (_bottomAdVideoCtrlForAds != null &&
                                _bottomAdVideoCtrlForAds!
                                    .value.isInitialized
                            ? FittedBox(
                                fit: BoxFit.fill,
                                child: SizedBox(
                                  width: _bottomAdVideoCtrlForAds!
                                      .value.size.width,
                                  height: _bottomAdVideoCtrlForAds!
                                      .value.size.height,
                                  child: VideoPlayer(
                                    _bottomAdVideoCtrlForAds!,
                                  ),
                                ),
                              )
                            : SizedBox.expand(
                                child: Image.file(
                                  File(bottomAdPaths[bottomAdIndex]),
                                  fit: BoxFit.fill,
                                ),
                              ))
                        : const Center(
                            child: Text(
                              "BOTTOM ADS",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
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
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),
          ),
        ],
      );
    }

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFF800000),
            width: 3.0,
          ),
        ),
        child: actualCameraWidget,
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    bool isScreenLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    double camW = 1080;
    double camH = 1920;

    if (_isCameraInitialized &&
        controller != null &&
        controller!.value.isInitialized) {
      final previewSize = controller!.value.previewSize;

      if (previewSize != null) {
        camW = previewSize.width;
        camH = previewSize.height;

        if (camW < camH) {
          double temp = camW;
          camW = camH;
          camH = temp;
        }
      }
    }

    double finalCamW = isScreenLandscape ? camW : camH;
    double finalCamH = isScreenLandscape ? camH : camW;

    Widget phoneCameraWidget = (!isCameraVisible)
        ? Container(color: Colors.transparent)
        : (_isCameraInitialized &&
                controller != null &&
                controller!.value.isInitialized)
            ? GestureDetector(
                onScaleStart: (details) {
                  _baseScale = _currentZoomLevel;
                },
                onScaleUpdate: (details) async {
                  if (controller == null ||
                      !controller!.value.isInitialized) {
                    return;
                  }

                  double zoom = _baseScale * details.scale;

                  if (zoom < _minZoomLevel) {
                    zoom = _minZoomLevel;
                  }

                  if (zoom > _maxZoomLevel) {
                    zoom = _maxZoomLevel;
                  }

                  setState(() {
                    _currentZoomLevel = zoom;
                  });

                  await controller?.setZoomLevel(zoom);
                },
                child: ClipRect(
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: finalCamW,
                        height: finalCamH,
                        child: CameraPreview(controller!),
                      ),
                    ),
                  ),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(
                  color: Colors.amber,
                ),
              );

    Widget reporterBadgeWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (watermarkText.isNotEmpty)
          Text(
            watermarkText,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 11.0,
            ),
          ),
        Container(
          color: Colors.red.shade800,
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 3,
          ),
          child: Text(
            locationText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11.0,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: Text(
            reporterName,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 12.0,
            ),
          ),
        ),
        Container(
          color: Colors.red.shade800,
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 3,
          ),
          child: Text(
            reporterRole,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11.0,
            ),
          ),
        ),
      ],
    );

    Widget visualScreenLogoWidget = GestureDetector(
      onTap: () {
        setState(() {
          logoPosition = (logoPosition + 1) % 4;
        });
      },
      child: channelLogoPath.isNotEmpty
          ? SizedBox(
              width: logoWidth,
              height: logoHeight,
              child: channelLogoPath.toLowerCase().endsWith('.mp4')
                  ? (_logoVideoCtrl != null &&
                          _logoVideoCtrl!.value.isInitialized
                      ? VideoPlayer(_logoVideoCtrl!)
                      : const SizedBox())
                  : Image.file(
                      File(channelLogoPath),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.red[900]?.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "SS YATRA TV",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFF800000),
            width: 4.0,
          ),
          image: studioBgImagePath.isNotEmpty &&
                  File(studioBgImagePath).existsSync()
              ? DecorationImage(
                  image: FileImage(File(studioBgImagePath)),
                  fit: BoxFit.cover,
                )
              : null,
          gradient: studioBgImagePath.isEmpty
              ? const LinearGradient(
                  colors: [
                    Color(0xFF000428),
                    Color(0xFF900000),
                    Color(0xFF004e92),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        padding: const EdgeInsets.all(2.0),
        child: SafeArea(
          top: false,
          bottom: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!isLiveLocked) {
                setState(() {
                  isMenuOpen
                      ? isMenuOpen = false
                      : hideControls = !hideControls;
                });
              }
            },
            onLongPress: () {
              if (isLiveLocked) {
                setState(() {
                  isLiveLocked = false;
                  hideControls = false;
                });

                showCustomToast(
                  context,
                  "స్క్రీన్ అన్‌లాక్ చేయబడింది.",
                  isLive: isLiveBroadcasting,
                );
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                double screenW = constraints.maxWidth;
                double screenH = constraints.maxHeight;
                double tickerH = 55.0;
                double topAreaH = screenH - tickerH;

                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: topAreaH,
                      child: _buildMainDisplay(
                        isScreenLandscape,
                        screenW,
                        topAreaH,
                        phoneCameraWidget,
                      ),
                    ),

                    Positioned(
                      top: (logoPosition == 0 || logoPosition == 1)
                          ? 5.0
                          : null,
                      bottom: (logoPosition == 2 || logoPosition == 3)
                          ? 75.0
                          : null,
                      left: (logoPosition == 0 || logoPosition == 3)
                          ? 10.0
                          : null,
                      right: (logoPosition == 1 || logoPosition == 2)
                          ? 10.0
                          : null,
                      child: visualScreenLogoWidget,
                    ),

                    if (!isDualScreenMode && showReporterDetails)
                      Positioned(
                        bottom: 65,
                        left: 15,
                        child: reporterBadgeWidget,
                      ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: tickerH,
                      child: Container(
                        height: tickerH,
                        decoration: BoxDecoration(
                          color: bgColors[
                              _tickerBgColorIndex % bgColors.length],
                          border: Border.all(
                            color: Colors.amber.shade400,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 120,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red.shade900,
                                    Colors.redAccent.shade700,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 6,
                                    offset: Offset(2, 0),
                                  ),
                                ],
                              ),
                              child: const Text(
                                "BREAKING\nNEWS",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 2,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                color: const Color(0xFF1A1A2E),
                                child: Marquee(
                                  text: breakingNewsText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  blankSpace: 100.0,
                                  velocity: 45.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (!hideControls && !isLiveLocked)
                      Positioned(
                        bottom: 75,
                        right: 20,
                        child: Row(
                          children: [
                            if (isLiveBroadcasting) ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                onPressed: _stopLiveStream,
                                icon: const Icon(
                                  Icons.stop,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "STOP",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                onPressed: () async {
                                  if (isLivePaused) {
                                    String cableUrl =
                                        cableRtmpController.text.trim();
                                    String restreamUrl =
                                        restreamRtmpController.text.trim();
                                    String satUrl =
                                        satelliteSrtController.text.trim();

                                    bool success =
                                        await StreamServiceManager
                                            .startLiveStreamMulti(
                                      cableUrl,
                                      restreamUrl,
                                      satUrl,
                                    );

                                    if (success) {
                                      setState(() {
                                        isLivePaused = false;
                                      });

                                      showCustomToast(
                                        context,
                                        "లైవ్ మళ్లీ మొదలైంది!",
                                        isLive: true,
                                      );
                                    }
                                  } else {
                                    bool success =
                                        await StreamServiceManager
                                            .pauseLiveStream();

                                    if (success) {
                                      setState(() {
                                        isLivePaused = true;
                                      });

                                      showCustomToast(
                                        context,
                                        "లైవ్ పాజ్ చేయబడింది.",
                                        isLive: true,
                                      );
                                    }
                                  }
                                },
                                icon: Icon(
                                  isLivePaused
                                      ? Icons.play_arrow
                                      : Icons.pause,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  isLivePaused ? "RESUME" : "PAUSE",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ] else ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                onPressed: _showLiveControlDialog,
                                icon: const Icon(
                                  Icons.sensors,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "GO LIVE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 10),
                            FloatingActionButton(
                              backgroundColor: Colors.blue.shade800,
                              onPressed: () {
                                setState(() {
                                  isMenuOpen = !isMenuOpen;
                                });
                              },
                              child: Icon(
                                isMenuOpen ? Icons.close : Icons.menu,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!hideControls && isMenuOpen && !isLiveLocked)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black87,
                          child: Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 30,
                              runSpacing: 35,
                              children: [
                                _buildControlButton(
                                  Icons.dashboard_customize,
                                  "PCR Board",
                                  () {
                                    setState(() => isMenuOpen = false);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const MasterPCRBoard(),
                                      ),
                                    );
                                  },
                                  Colors.yellowAccent,
                                ),
                                _buildControlButton(
                                  Icons.newspaper,
                                  "News Desk",
                                  () {
                                    setState(() => isMenuOpen = false);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const NewsDeskScreen(),
                                      ),
                                    );
                                  },
                                  Colors.redAccent,
                                ),
                                _buildControlButton(
                                  Icons.auto_awesome,
                                  "Pro Editor",
                                  () {
                                    setState(() => isMenuOpen = false);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const EditorToolScreen(),
                                      ),
                                    );
                                  },
                                  Colors.pinkAccent,
                                ),
                                // 🔴 ఎలక్షన్ బటన్ 🔴
                                _buildControlButton(
                                  Icons.bar_chart,
                                  "Election Results",
                                  () {
                                    setState(() => isMenuOpen = false);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ElectionBoardScreen(),
                                      ),
                                    );
                                  },
                                  Colors.blueAccent,
                                ),
                                _buildControlButton(
                                  Icons.flip_camera_android,
                                  "Phone Cam",
                                  _switchCamera,
                                  Colors.white,
                                ),
                                _buildControlButton(
                                  isCameraVisible
                                      ? Icons.videocam
                                      : Icons.videocam_off,
                                  isCameraVisible ? "Cam ON" : "Cam OFF",
                                  _toggleCameraVisibility,
                                  isCameraVisible
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                ),
                                _buildControlButton(
                                  Icons.video_call,
                                  "Ext. Cams",
                                  _showExternalCamsDialog,
                                  Colors.cyanAccent,
                                ),
                                _buildControlButton(
                                  Icons.grid_on,
                                  "Dual Screen",
                                  _toggleDualScreenAndPickMedia,
                                  Colors.orangeAccent,
                                ),
                                _buildControlButton(
                                  Icons.visibility,
                                  adDisplayMode == 0
                                      ? "Ads OFF"
                                      : (adDisplayMode == 1
                                          ? "Ads ON"
                                          : "Auto Ads"),
                                  _toggleAdMode,
                                  Colors.redAccent,
                                ),
                                _buildControlButton(
                                  Icons.dashboard,
                                  adShapeMode == 0
                                      ? "Shape: L-Band"
                                      : "Shape: U-Band",
                                  _toggleAdShapeMode,
                                  Colors.orangeAccent,
                                ),
                                _buildControlButton(
                                  Icons.picture_in_picture_alt,
                                  "Logo Pos",
                                  _changeLogoPosition,
                                  Colors.lightGreenAccent,
                                ),
                                _buildControlButton(
                                  Icons.swap_horiz,
                                  "L-Band L/R",
                                  _toggleLBandDirection,
                                  Colors.orange,
                                ),
                                _buildControlButton(
                                  Icons.screen_rotation,
                                  "Rotate",
                                  _toggleRotation,
                                  Colors.purpleAccent,
                                ),
                                _buildControlButton(
                                  Icons.settings,
                                  "Settings",
                                  _showEditDialog,
                                  Colors.blue,
                                ),
                                _buildControlButton(
                                  showReporterDetails
                                      ? Icons.badge
                                      : Icons.badge_outlined,
                                  showReporterDetails
                                      ? "Reporter ON"
                                      : "Reporter OFF",
                                  _toggleReporterDetails,
                                  showReporterDetails
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

    Widget _buildControlButton(
    IconData icon,
    String label,
    VoidCallback onTap,
    Color iconColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade800,
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
    }

// ============================================================================
// 3. MASTER PCR BOARD SCREEN
// ============================================================================
class MasterPCRBoard extends StatefulWidget {
  const MasterPCRBoard({Key? key}) : super(key: key);

  @override
  State<MasterPCRBoard> createState() => _MasterPCRBoardState();
}

class _MasterPCRBoardState extends State<MasterPCRBoard> {
  CameraController? _phoneCamCtrl;
  List<CameraDescription> _cameras = [];

  bool hideControls = false;
  bool isLiveBroadcasting = false;
  bool isLivePaused = false;
  bool isNoiseCancellationEnabled = true;

  int layoutMode = 6;
  String mainCameraId = "REPORTER_CAM";
  List<String> hexCams = [
    "IP_1",
    "IP_2",
    "DRONE_1",
    "IP_3",
    "IP_4",
    "HDMI_1"
  ];

  String channelLogoPath = "";
  String studioBgImagePath = "";
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

  final List<Color> bgColors = [
    const Color(0xFF0D47A1),
    const Color(0xFF800000),
    Colors.purple.shade900,
    Colors.teal.shade900
  ];

  final List<dynamic> cameraList = [ 
    {
      "id": "REPORTER_CAM",
      "name": "Reporter",
      "type": "PHONE",
      "active": true,
      "muted": false,
      "url": ""
    },
    {
      "id": "DRONE_1",
      "name": "DJI Drone",
      "type": "DRONE",
      "active": false,
      "muted": true,
      "url": "rtsp://192.168.1.1:554/live"
    },
    {
      "id": "HDMI_1",
      "name": "Sony Cam 1",
      "type": "USB",
      "active": false,
      "muted": false,
      "url": ""
    },
    {
      "id": "IP_1",
      "name": "CCTV Left",
      "type": "IP",
      "active": false,
      "muted": true,
      "url": "https://www.youtube.com/watch?v=5qap5aO4i9A"
    },
    {
      "id": "IP_2",
      "name": "CCTV Right",
      "type": "IP",
      "active": false,
      "muted": true,
      "url": "rtsp://192.168.1.100:8080/video"
    },
    {
      "id": "IP_3",
      "name": "Mobile WiFi 1",
      "type": "IP",
      "active": false,
      "muted": true,
      "url": "rtsp://192.168.1.101:8080/video"
    },
    {
      "id": "IP_4",
      "name": "Mobile WiFi 2",
      "type": "IP",
      "active": false,
      "muted": true,
      "url": "rtsp://192.168.1.102:8080/video"
    },
  ];

  @override
  void initState() {
    super.initState();
    _initPhoneCamera();

    _tickerColorTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() => _tickerBgColorIndex++);
      }
    });

    _loadSavedData();
  }

  Widget _buildStandbyScreen() {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.satellite_alt,
              color: Colors.white24,
              size: 60,
            ),
            SizedBox(height: 15),
            Text(
              "STANDBY / NO SIGNAL",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 3.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initPhoneCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isNotEmpty) {
        CameraDescription cam = _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );

        _phoneCamCtrl = CameraController(
          cam,
          ResolutionPreset.max,
          enableAudio: false,
        );

        await _phoneCamCtrl!.initialize();

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint("Phone Camera Error: $e");
    }
  }

  Future<void> _loadSavedData() async {
    try {
      SharedPreferences prefs =
          await SharedPreferences.getInstance();

      setState(() {
        layoutMode = prefs.getInt('pcr_layoutMode') ?? 6;
        adShapeMode = prefs.getInt('adShapeMode') ?? 0;
        logoPosition = prefs.getInt('logoPosition') ?? 0;

        isNoiseCancellationEnabled =
            prefs.getBool('noiseCancel') ?? true;

        breakingNewsText =
            prefs.getString('breakingNewsText') ??
                "తాజా వార్తలు లోడ్ అవుతున్నాయి...";

        cableRtmpController.text =
            prefs.getString('cableRtmp') ?? "";

        restreamRtmpController.text =
            prefs.getString('restreamRtmp') ?? "";

        satelliteSrtController.text =
            prefs.getString('satelliteSrt') ?? "";

        String savedLogo =
            prefs.getString('channelLogoPath') ?? "";

        if (savedLogo.isNotEmpty &&
            File(savedLogo).existsSync()) {
          _setLogo(savedLogo);
        } else {
          channelLogoPath = "";
        }

        studioBgImagePath =
            prefs.getString('studioBgImagePath') ?? "";

        leftAdPaths =
            (prefs.getStringList('leftAdPaths') ?? [])
                .where((p) => File(p).existsSync())
                .toList();

        rightAdPaths =
            (prefs.getStringList('rightAdPaths') ?? [])
                .where((p) => File(p).existsSync())
                .toList();

        bottomAdPaths =
            (prefs.getStringList('bottomAdPaths') ?? [])
                .where((p) => File(p).existsSync())
                .toList();

        if (leftAdPaths.isNotEmpty) {
          _initAdVideo('left');
        }

        if (rightAdPaths.isNotEmpty) {
          _initAdVideo('right');
        }

        if (bottomAdPaths.isNotEmpty) {
          _initAdVideo('bottom');
        }
      });
    } catch (e) {
      debugPrint("Load Saved Data Error: $e");
    }
  }

  void _setLogo(String path) {
    setState(() {
      channelLogoPath = path;
    });

    if (_logoVideoCtrl != null) {
      _logoVideoCtrl!.dispose();
      _logoVideoCtrl = null;
    }

    if (path.toLowerCase().endsWith('.mp4')) {
      _logoVideoCtrl =
          VideoPlayerController.file(File(path))
            ..initialize().then((_) {
              if (mounted) {
                _logoVideoCtrl!.setLooping(true);
                _logoVideoCtrl!.setVolume(0);
                _logoVideoCtrl!.play();
                setState(() {});
              }
            });
    }
  }

  void _initAdVideo(String pos) {
    String path = "";

    if (pos == 'left' && leftAdPaths.isNotEmpty) {
      leftAdIndex = (leftAdIndex % leftAdPaths.length).toInt();
      path = leftAdPaths[leftAdIndex];
    }

    if (pos == 'right' && rightAdPaths.isNotEmpty) {
      rightAdIndex = (rightAdIndex % rightAdPaths.length).toInt(); 
      path = rightAdPaths[rightAdIndex];
    }

    if (pos == 'bottom' && bottomAdPaths.isNotEmpty) {
      bottomAdIndex = (bottomAdIndex % bottomAdPaths.length).toInt();
      path = bottomAdPaths[bottomAdIndex];
    }

    if (path.isEmpty) return;

    bool isVideo =
        path.toLowerCase().endsWith('.mp4') ||
        path.toLowerCase().endsWith('.mov') ||
        path.toLowerCase().endsWith('.gif');

    if (pos == 'left') {
      if (_leftAdVideoCtrl != null) {
        _leftAdVideoCtrl!.dispose();
        _leftAdVideoCtrl = null;
      }

      if (isVideo) {
        _leftAdVideoCtrl =
            VideoPlayerController.file(File(path))
              ..initialize().then((_) {
                if (mounted) {
                  _leftAdVideoCtrl!.setLooping(true);
                  _leftAdVideoCtrl!.setVolume(0.0);
                  _leftAdVideoCtrl!.play();
                  setState(() {});
                }
              });
      }
    } else if (pos == 'right') {
      if (_rightAdVideoCtrl != null) {
        _rightAdVideoCtrl!.dispose();
        _rightAdVideoCtrl = null;
      }

      if (isVideo) {
        _rightAdVideoCtrl =
            VideoPlayerController.file(File(path))
              ..initialize().then((_) {
                if (mounted) {
                  _rightAdVideoCtrl!.setLooping(true);
                  _rightAdVideoCtrl!.setVolume(0.0);
                  _rightAdVideoCtrl!.play();
                  setState(() {});
                }
              });
      }
    } else if (pos == 'bottom') {
      if (_bottomAdVideoCtrlForAds != null) {
        _bottomAdVideoCtrlForAds!.dispose();
        _bottomAdVideoCtrlForAds = null;
      }

      if (isVideo) {
        _bottomAdVideoCtrlForAds =
            VideoPlayerController.file(File(path))
              ..initialize().then((_) {
                if (mounted) {
                  _bottomAdVideoCtrlForAds!.setLooping(true);
                  _bottomAdVideoCtrlForAds!.setVolume(0.0);
                  _bottomAdVideoCtrlForAds!.play();
                  setState(() {});
                }
              });
      }
    }
  }

  void _swapCamera(int gridIndex) {
    setState(() {
      String temp = mainCameraId;
      mainCameraId = hexCams[gridIndex];
      hexCams[gridIndex] = temp;
    });
  }

  void _toggleMute(Map<String, dynamic> cam) {
    setState(() {
      cam['muted'] = !cam['muted'];
    });
  }

  void _saveLinks() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cableRtmp', cableRtmpController.text.trim());
      prefs.setString('restreamRtmp', restreamRtmpController.text.trim());
      prefs.setString('satelliteSrt', satelliteSrtController.text.trim());
    });
  }

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
