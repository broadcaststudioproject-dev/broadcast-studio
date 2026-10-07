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
import 'pcr_board.dart';
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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StudioScreen(),
    );
  }
}

class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  
  CameraController? controller;
  VideoPlayerController? _bulletinVideoController;
  
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
  bool isLBandRight = true;

  bool isNewsBulletinMode = false;
  bool isBulletinMuted = false;
  bool isCameraVisible = false;
  
  double pipTop = 60.0;
  double pipLeft = 0.0;
  bool isPipPositionInitialized = false;

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

  String splitScreenMainHeadline = "రైతు పొలంలో కలకలం.. గట్లపై భారీ పులి అడుగుల గుర్తులు!";
  String splitScreenSubHeadline = "వార్తా అప్డేట్";

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

  Timer? _newsTimer;
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
  bool isDroneCamMode = false;
  VideoPlayerController? _ipCamController;
  VideoPlayerController? _droneCamController;
  TextEditingController ipCamUrlCtrl = TextEditingController();
  TextEditingController droneCamUrlCtrl = TextEditingController();
  int? _usbTextureId;

  int adDisplayMode = 0;
  bool isAdCurrentlyShowing = false;
  Timer? _adCycleTimer;

  int adShapeMode = 0;

  int _tickerBgColorIndex = 0;
  Timer? _tickerColorTimer;
  late AnimationController _motionController;

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
    cableRtmpController.text = "rtmp://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY_HERE";
    satelliteSrtController.text = "";
    ipCamUrlCtrl.text = "http://192.168.1.100:8080/video";
    droneCamUrlCtrl.text = "rtsp://192.168.1.1:554/live";

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);

    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _tickerColorTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _tickerBgColorIndex++;
        });
      }
    });

    _loadSavedData();
    _requestPermissions();
    _fetchBreakingNews();

    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _fetchBreakingNews();
    });
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      watermarkText = prefs.getString('watermarkText') ?? "SS YATRA TV";
      locationText = prefs.getString('locationText') ?? "LIVE KOTHAKOTA";
      reporterName = prefs.getString('reporterName') ?? "JANAMPALLY VINOD KUMAR";
      reporterRole = prefs.getString('reporterRole') ?? "SPECIAL CORRESPONDENT";
      breakingNewsText = prefs.getString('breakingNewsText') ?? "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";
      splitScreenMainHeadline = prefs.getString('splitScreenMainHeadline') ?? "రైతు పొలంలో కలకలం.. గట్లపై భారీ పులి అడుగుల గుర్తులు!";
      splitScreenSubHeadline = prefs.getString('splitScreenSubHeadline') ?? "వార్తా అప్డేట్";
      
      adShapeMode = prefs.getInt('adShapeMode') ?? 0;
      logoPosition = prefs.getInt('logoPosition') ?? 0;

      cableRtmpController.text = prefs.getString('cableRtmp') ?? "rtmp://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY_HERE";
      satelliteSrtController.text = prefs.getString('satelliteSrt') ?? "";
      youtubeVideoUrlCtrl.text = prefs.getString('youtubeVideoUrl') ?? "";
      networkVideoUrlCtrl.text = prefs.getString('networkVideoUrl') ?? "";
      ipCamUrlCtrl.text = prefs.getString('ipCamUrl') ?? "http://192.168.1.100:8080/video";
      droneCamUrlCtrl.text = prefs.getString('droneCamUrl') ?? "rtsp://192.168.1.1:554/live";

      watermarkCtrl.text = watermarkText;
      locCtrl.text = locationText;
      nameCtrl.text = reporterName;
      roleCtrl.text = reporterRole;
      mainHeadlineCtrl.text = splitScreenMainHeadline;
      subHeadlineCtrl.text = splitScreenSubHeadline;

      String savedLogo = prefs.getString('channelLogoPath') ?? "";
      if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) {
        channelLogoPath = savedLogo;
      }

      leftAdPaths = (prefs.getStringList('leftAdPaths') ?? [])
          .where((path) => File(path).existsSync())
          .toList();
      rightAdPaths = (prefs.getStringList('rightAdPaths') ?? [])
          .where((path) => File(path).existsSync())
          .toList();
      bottomAdPaths = (prefs.getStringList('bottomAdPaths') ?? [])
          .where((path) => File(path).existsSync())
          .toList();

      if (leftAdPaths.isNotEmpty) _initAdVideo('left');
      if (rightAdPaths.isNotEmpty) _initAdVideo('right');
      if (bottomAdPaths.isNotEmpty) _initAdVideo('bottom');
    });
  }

  void _initAdVideo(String pos) {
    String path = "";
    if (pos == 'left' && leftAdPaths.isNotEmpty) {
      if (leftAdIndex >= leftAdPaths.length) leftAdIndex = 0;
      path = leftAdPaths[leftAdIndex];
    }
    if (pos == 'right' && rightAdPaths.isNotEmpty) {
      if (rightAdIndex >= rightAdPaths.length) rightAdIndex = 0;
      path = rightAdPaths[rightAdIndex];
    }
    if (pos == 'bottom' && bottomAdPaths.isNotEmpty) {
      if (bottomAdIndex >= bottomAdPaths.length) bottomAdIndex = 0;
      path = bottomAdPaths[bottomAdIndex];
    }

    if (path.isEmpty) return;

    bool isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov');

    if (pos == 'left') {
      _leftAdVideoCtrl?.dispose();
      _leftAdVideoCtrl = null;
      if (isVideo) {
        _leftAdVideoCtrl = VideoPlayerController.file(File(path))
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
      _rightAdVideoCtrl?.dispose();
      _rightAdVideoCtrl = null;
      if (isVideo) {
        _rightAdVideoCtrl = VideoPlayerController.file(File(path))
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
      _bottomAdVideoCtrlForAds?.dispose();
      _bottomAdVideoCtrlForAds = null;
      if (isVideo) {
        _bottomAdVideoCtrlForAds = VideoPlayerController.file(File(path))
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('watermarkText', watermarkText);
    await prefs.setString('locationText', locationText);
    await prefs.setString('reporterName', reporterName);
    await prefs.setString('reporterRole', reporterRole);
    await prefs.setString('splitScreenMainHeadline', splitScreenMainHeadline);
    await prefs.setString('splitScreenSubHeadline', splitScreenSubHeadline);
    await prefs.setString('breakingNewsText', breakingNewsText);
    await prefs.setInt('adShapeMode', adShapeMode);
    await prefs.setInt('logoPosition', logoPosition);
  }

  Future<void> _saveLinks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cableRtmp', cableRtmpController.text);
    await prefs.setString('satelliteSrt', satelliteSrtController.text);
    await prefs.setString('youtubeVideoUrl', youtubeVideoUrlCtrl.text);
    await prefs.setString('networkVideoUrl', networkVideoUrlCtrl.text);
    await prefs.setString('ipCamUrl', ipCamUrlCtrl.text);
    await prefs.setString('droneCamUrl', droneCamUrlCtrl.text);
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
    _motionController.dispose();

    controller?.dispose();
    _bulletinVideoController?.removeListener(_videoListener);
    _bulletinVideoController?.dispose();
    _bottomAdVideoController?.dispose();

    _leftAdVideoCtrl?.dispose();
    _rightAdVideoCtrl?.dispose();
    _bottomAdVideoCtrlForAds?.dispose();
    _ipCamController?.dispose();
    _droneCamController?.dispose();

    cableRtmpController.dispose();
    satelliteSrtController.dispose();
    networkVideoUrlCtrl.dispose();
    youtubeVideoUrlCtrl.dispose();
    ipCamUrlCtrl.dispose();
    droneCamUrlCtrl.dispose();
    watermarkCtrl.dispose();
    locCtrl.dispose();
    nameCtrl.dispose();
    roleCtrl.dispose();
    manualTickerCtrl.dispose();
    mainHeadlineCtrl.dispose();
    subHeadlineCtrl.dispose();
    
    super.dispose();
  }
  
  void _videoListener() {
    final vController = _bulletinVideoController;
    if (vController == null || !vController.value.isInitialized) return;
    if (vController.value.position >= vController.value.duration && vController.value.duration != Duration.zero) {
      vController.removeListener(_videoListener);
      setState(() { isNewsBulletinMode = false; });
    }
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
          setState(() {
            breakingNewsText = titles.join("   ♦   ");
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
      Permission.photos,
      Permission.videos
    ].request();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;
    try {
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
      
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint("Init Camera Error: $e");
    }
  }

  void _switchCamera() async {
    if (isExternalIpCamMode || isUsbCamMode || isDroneCamMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ఎక్స్‌టర్నల్ / డ్రోన్ కెమెరా మోడ్‌లో ఫోన్ కెమెరా స్విచ్ పనిచేయదు."))
      );
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

    if (isExternalIpCamMode || isUsbCamMode || isDroneCamMode) {
      setState(() {
        isExternalIpCamMode = false;
        isUsbCamMode = false;
        isDroneCamMode = false;
        isCameraVisible = false;
        _usbTextureId = null;
      });
      _ipCamController?.dispose();
      _ipCamController = null;
      _droneCamController?.dispose();
      _droneCamController = null;
      try {
        await StreamServiceManager.stopUsbCamera();
      } catch (_) {}
      return;
    }

    if (isCameraVisible) {
      setState(() {
        isCameraVisible = false;
      });
      await controller?.dispose();
      controller = null;
      setState(() {
        _isCameraInitialized = false;
      });
    } else {
      setState(() {
        isCameraVisible = true;
      });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("యాడ్స్ ఆఫ్ (వీడియో ఫుల్ జూమ్)"), backgroundColor: Colors.red)
        );
      } else if (adDisplayMode == 1) {
        isAdCurrentlyShowing = true;
        _startPermanentCycle();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("యాడ్స్ ఆన్ (నిరంతరం మారుతాయి)"), backgroundColor: Colors.blueAccent)
        );
      } else if (adDisplayMode == 2) {
        isAdCurrentlyShowing = true;
        _startAutoCycle();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ఆటో టైమర్ (20s ON / 40s OFF)"), backgroundColor: Colors.green)
        );
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
          setState(() {
            isAdCurrentlyShowing = false;
          });
          _startAutoCycle();
        }
      });
    } else {
      _adCycleTimer = Timer(const Duration(seconds: 40), () {
        if (mounted && adDisplayMode == 2) {
          setState(() {
            isAdCurrentlyShowing = true;
            if (leftAdPaths.isNotEmpty) leftAdIndex = (leftAdIndex + 1) % leftAdPaths.length;
            if (rightAdPaths.isNotEmpty) rightAdIndex = (rightAdIndex + 1) % rightAdPaths.length;
            if (bottomAdPaths.isNotEmpty) bottomAdIndex = (bottomAdIndex + 1) % bottomAdPaths.length;
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
    setState(() {
      adShapeMode = (adShapeMode + 1) % 3;
      isMenuOpen = false;
    });
    await _saveTextSettings();
    String shapeName = adShapeMode == 0 ? "L-Band" : (adShapeMode == 1 ? "2-Sides" : "U-Band");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("డిజైన్ మారింది: $shapeName"), backgroundColor: Colors.purpleAccent)
    );
  }

  void _toggleLBandDirection() {
    setState(() {
      isLBandRight = !isLBandRight;
      isMenuOpen = false;
    });
  }

  void _changeLogoPosition() async {
    setState(() {
      logoPosition = (logoPosition + 1) % 4;
      isMenuOpen = false;
    });
    await _saveTextSettings();
    String posName = "";
    if (logoPosition == 0) posName = "Top Left";
    if (logoPosition == 1) posName = "Top Right";
    if (logoPosition == 2) posName = "Bottom Left";
    if (logoPosition == 3) posName = "Bottom Right";
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("లోగో స్థానం మారింది: $posName"), backgroundColor: Colors.amber)
    );
  }

  Future<void> _startIpCamera(String url) async {
    if (url.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("IP కెమెరాకు కనెక్ట్ అవుతోంది..."), backgroundColor: Colors.orange)
    );
    
    _ipCamController?.dispose();
    _ipCamController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          isExternalIpCamMode = true;
          isUsbCamMode = false;
          isDroneCamMode = false;
          isCameraVisible = true;
          isNewsBulletinMode = false;
          isDualScreenMode = false;
        });
        _ipCamController?.play();
      }).catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("IP కెమెరా కనెక్ట్ కాలేదు. లింక్ చెక్ చేయండి."), backgroundColor: Colors.red)
        );
      });
  }

  Future<void> _startDroneCamera(String url) async {
    if (url.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("డ్రోన్ సిగ్నల్ ప్రాసెస్ అవుతోంది..."), backgroundColor: Colors.orange)
    );
    
    _droneCamController?.dispose();
    _droneCamController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          isDroneCamMode = true;
          isExternalIpCamMode = false;
          isUsbCamMode = false;
          isCameraVisible = true;
          isNewsBulletinMode = false;
          isDualScreenMode = false;
        });
        _droneCamController?.play();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("డ్రోన్ కనెక్ట్ అయ్యింది! (Live)"), backgroundColor: Colors.green)
        );
      }).catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("డ్రోన్ ఫీడ్ కనెక్ట్ కాలేదు. RTMP/RTSP చెక్ చేయండి."), backgroundColor: Colors.red)
        );
      });
  }

  Future<void> _startUsbCamera() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("USB Capture Card కోసం వెతుకుతోంది..."), backgroundColor: Colors.orange)
    );
    try {
      final int? textureId = await StreamServiceManager.startUsbCamera();
      if (textureId != null) {
        setState(() {
          _usbTextureId = textureId;
          isUsbCamMode = true;
          isExternalIpCamMode = false;
          isDroneCamMode = false;
          isCameraVisible = true;
          isNewsBulletinMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("USB Capture Card కనెక్ట్ అయ్యింది!"), backgroundColor: Colors.green)
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("USB కెమెరా కనెక్ట్ కాలేదు. OTG చెక్ చేయండి."), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Android UVC కోడ్ ఇంకా సెటప్ చేయబడలేదు."), backgroundColor: Colors.redAccent)
      );
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("కొత్త యాడ్స్ విజయవంతంగా యాడ్ అయ్యాయి!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint("Pick Ads Error: $e");
    }
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
              title: Text("Manage ${pos.toUpperCase()} Ads", style: const TextStyle(color: Colors.white, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: currentPaths.isEmpty
                    ? const Text("యాడ్స్ ఏమీ లేవు.", style: TextStyle(color: Colors.white54))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: currentPaths.length,
                        itemBuilder: (ctx, idx) {
                          String path = currentPaths[idx];
                          bool isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov');
                          return ListTile(
                            leading: isVideo
                                ? const Icon(Icons.video_file, color: Colors.blueAccent, size: 40)
                                : Image.file(File(path), width: 50, height: 50, fit: BoxFit.cover),
                            title: Text("Ad ${idx + 1}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  currentPaths.removeAt(idx);
                                  _saveAdPaths(pos, currentPaths);
                                  if (pos == 'left') {
                                    if (leftAdIndex >= leftAdPaths.length) leftAdIndex = 0;
                                    _initAdVideo('left');
                                  }
                                  if (pos == 'right') {
                                    if (rightAdIndex >= rightAdPaths.length) rightAdIndex = 0;
                                    _initAdVideo('right');
                                  }
                                  if (pos == 'bottom') {
                                    if (bottomAdIndex >= bottomAdPaths.length) bottomAdIndex = 0;
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
                  child: const Text("Clear All", style: TextStyle(color: Colors.redAccent)),
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
                  child: const Text("Close", style: TextStyle(color: Colors.white)),
                  onPressed: () => Navigator.pop(ctx),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showExternalCamsDialog() {
    setState(() {
      isMenuOpen = false;
    });
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("External Cameras & Drone Setup", style: TextStyle(color: Colors.white, fontSize: 15)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("1. IP Camera / Wi-Fi CCTV", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: ipCamUrlCtrl,
                      style: const TextStyle(color: Colors.yellow, fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: "http://... or rtsp://...",
                        hintStyle: TextStyle(color: Colors.white30),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
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
                      label: const Text("Connect IP Cam", style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    
                    const Text("2. Drone Camera (DJI / RTMP / RTSP)", style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: droneCamUrlCtrl,
                      style: const TextStyle(color: Colors.yellow, fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: "rtmp://... or rtsp://...",
                        hintStyle: TextStyle(color: Colors.white30),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      onPressed: () async {
                        await _saveLinks();
                        Navigator.pop(context);
                        _startDroneCamera(droneCamUrlCtrl.text.trim());
                      },
                      icon: const Icon(Icons.flight, color: Colors.white, size: 18),
                      label: const Text("Connect Drone", style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    
                    const Divider(color: Colors.white24, height: 20),
                    const Text("3. USB / Type-C Capture Card (UVC)", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                      onPressed: () {
                        Navigator.pop(context);
                        _startUsbCamera();
                      },
                      icon: const Icon(Icons.usb, color: Colors.white, size: 18),
                      label: const Text("Start USB Camera", style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close", style: TextStyle(color: Colors.white, fontSize: 11)),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog() {
    setState(() {
      isMenuOpen = false;
    });
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                          final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
                          if (image != null) {
                            setState(() {
                              channelLogoPath = image.path;
                            });
                            SharedPreferences prefs = await SharedPreferences.getInstance();
                            await prefs.setString('channelLogoPath', image.path);
                            setDialogState(() {});
                          }
                        } catch (e) {}
                      },
                      icon: const Icon(Icons.upload),
                      label: const Text("ఛానల్ లోగో అప్లోడ్"),
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    TextField(
                      controller: mainHeadlineCtrl,
                      style: const TextStyle(color: Colors.yellow),
                      decoration: const InputDecoration(labelText: "మెయిన్ హెడ్‌‌లైన్"),
                    ),
                    TextField(
                      controller: subHeadlineCtrl,
                      style: const TextStyle(color: Colors.cyanAccent),
                      decoration: const InputDecoration(labelText: "సబ్ హెడ్‌‌లైన్"),
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    TextField(
                      controller: manualTickerCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "మాన్యువల్ బ్రేకింగ్ టిక్కర్"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      onPressed: () async {
                        if (manualTickerCtrl.text.trim().isNotEmpty) {
                          setState(() {
                            breakingNewsText = manualTickerCtrl.text.trim();
                          });
                          await _saveTextSettings();
                          manualTickerCtrl.clear();
                          setDialogState(() {});
                        }
                      },
                      child: const Text("టిక్కర్ అప్‌‌డేట్ చేయి", style: TextStyle(color: Colors.black)),
                    ),
                    TextField(
                      controller: watermarkCtrl,
                      style: const TextStyle(color: Colors.yellow),
                      decoration: const InputDecoration(labelText: "వాటర్ మార్క్"),
                    ),
                    TextField(
                      controller: locCtrl,
                      style: const TextStyle(color: Colors.yellow),
                      decoration: const InputDecoration(labelText: "లొకేషన్"),
                    ),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.yellow),
                      decoration: const InputDecoration(labelText: "రిపోర్టర్ పేరు"),
                    ),
                    TextField(
                      controller: roleCtrl,
                      style: const TextStyle(color: Colors.yellow),
                      decoration: const InputDecoration(labelText: "హోదా"),
                    ),
                  ],
                ),
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
                  child: const Text("Save & Close"),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showMultiStreamDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(
      context: context, 
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text("Live Control Room (Multi-Live)", style: TextStyle(color: Colors.white, fontSize: 15)),
            content: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                _buildLinkEditor("1. Local Cable — RTMP/SRT", cableRtmpController, setDialogState),
                const Divider(color: Colors.white24, height: 20),
                _buildLinkEditor("2. Satellite/Playout — SRT/RTMP", satelliteSrtController, setDialogState),
                const Divider(color: Colors.white24, height: 20),
                _buildLinkEditor("3. YouTube Video Link (Player)", youtubeVideoUrlCtrl, setDialogState, onPlay: () { Navigator.pop(context); _startNetworkBulletin(youtubeVideoUrlCtrl.text.trim()); }),
                const Divider(color: Colors.white24, height: 20),
                _buildLinkEditor("4. Direct Network Video (MP4)", networkVideoUrlCtrl, setDialogState, onPlay: () { Navigator.pop(context); _startNetworkBulletin(networkVideoUrlCtrl.text.trim()); }),
                const Divider(color: Colors.white24, height: 20),
                const Text("5. గ్యాలరీ వీడియో (MP4, HD, 4K)", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity, 
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 10)), 
                    onPressed: () { Navigator.pop(context); _playLocalGalleryVideo(); }, 
                    icon: const Icon(Icons.video_library, color: Colors.white, size: 20), 
                    label: const Text("గ్యాలరీ నుండి సెలెక్ట్ చేయండి", style: TextStyle(color: Colors.white, fontSize: 12))
                  )
                ),
              ])
            ),
            actions: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () { Navigator.pop(context); _startLiveAndLock(); }, child: const Text("Go Live", style: TextStyle(color: Colors.white, fontSize: 11))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), 
                  onPressed: () async { 
                    Navigator.pop(context); 
                    if (isLivePaused) { 
                      bool success = await StreamServiceManager.startLiveStream(cableRtmpController.text.trim(), satelliteSrtController.text.trim()); 
                      if (success) { setState(() { isLivePaused = false; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ మళ్లీ మొదలైంది!"))); } 
                    } else { 
                      bool success = await StreamServiceManager.stopLiveStream(); 
                      if (success) { setState(() { isLivePaused = true; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ పాజ్ చేయబడింది."))); } 
                    } 
                  }, 
                  child: Text(isLivePaused ? "Resume Live" : "Live Pause", style: const TextStyle(color: Colors.white, fontSize: 11))
                ),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { Navigator.pop(context); _stopLiveStream(); }, child: const Text("Live Close", style: TextStyle(color: Colors.white, fontSize: 11))),
              ])
            ]
          );
        });
      }
    );
  }

  Widget _buildLinkEditor(String label, TextEditingController controller, StateSetter setDialogState, {VoidCallback? onPlay}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
      Row(children: [
        Expanded(child: TextField(controller: controller, style: const TextStyle(color: Colors.yellow, fontSize: 12), decoration: const InputDecoration(hintText: "Paste link here...", hintStyle: TextStyle(color: Colors.white30), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))))),
        IconButton(icon: const Icon(Icons.save, color: Colors.blueAccent, size: 22), onPressed: () async { await _saveLinks(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"))); }),
        if (onPlay != null) IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 28), onPressed: onPlay)
      ])
    ]);
  }

  Future<void> _startNetworkBulletin(String url) async {
    if (url.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("యూట్యూబ్ లింక్ ప్రాసెస్ అవుతోంది..."), backgroundColor: Colors.orange));
    String finalPlayUrl = url;
    if (url.contains("youtube.com") || url.contains("youtu.be")) {
      try {
        var ytExplode = yt.YoutubeExplode(); String? videoId; 
        try { videoId = yt.VideoId.parseVideoId(url); } catch (_) {}
        if (videoId == null) { 
          RegExp regExp = RegExp(r'(?:v=|/v/|embed/|youtu\.be/|/live/)([a-zA-Z0-9_-]{11})', caseSensitive: false); 
          Match? match = regExp.firstMatch(url); 
          if (match != null && match.groupCount >= 1) { videoId = match.group(1); } 
        }
        if (videoId == null) { ytExplode.close(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("తప్పు యూట్యూబ్ లింక్."), backgroundColor: Colors.red)); return; }
        var video = await ytExplode.videos.get(yt.VideoId(videoId));
        if (video.isLive) { 
          finalPlayUrl = await ytExplode.videos.streamsClient.getHttpLiveStreamUrl(video.id); 
        } else { 
          var manifest = await ytExplode.videos.streamsClient.getManifest(video.id); 
          finalPlayUrl = manifest.muxed.withHighestBitrate().url.toString(); 
        }
        ytExplode.close();
      } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఈ లింక్‌‌ను ప్లే చేయలేము."), backgroundColor: Colors.red)); return; }
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("వీడియో ప్లే అవుతోంది..."), backgroundColor: Colors.green));
    _bulletinVideoController?.removeListener(_videoListener); 
    _bulletinVideoController?.dispose();
    _bulletinVideoController = VideoPlayerController.networkUrl(Uri.parse(finalPlayUrl))..initialize().then((_) { 
      if (!mounted) return; 
      _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0); 
      setState(() { isNewsBulletinMode = true; isDualScreenMode = false; hideControls = true; }); 
      _bulletinVideoController?.play(); 
      _bulletinVideoController?.addListener(_videoListener); 
    }).catchError((e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("వీడియో ప్లే అవ్వడం లేదు."), backgroundColor: Colors.red)); });
  }

  Future<void> _playLocalGalleryVideo() async {
    try {
      final XFile? videoFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (videoFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("గ్యాలరీ వీడియో లోడ్ అవుతోంది..."), backgroundColor: Colors.orange));
        _bulletinVideoController?.removeListener(_videoListener); 
        _bulletinVideoController?.dispose();
        _bulletinVideoController = VideoPlayerController.file(File(videoFile.path))..initialize().then((_) { 
          if (!mounted) return; 
          _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0); 
          setState(() { isNewsBulletinMode = true; isDualScreenMode = false; hideControls = true; }); 
          _bulletinVideoController?.play(); 
          _bulletinVideoController?.addListener(_videoListener); 
        }).catchError((e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("వీడియో ప్లే అవ్వడం లేదు. ఫార్మాట్ సపోర్ట్ చేయకపోవచ్చు."), backgroundColor: Colors.red)); });
      }
    } catch (e) { debugPrint("Gallery Video Error: $e"); }
  }

  void _toggleRotation() {
    setState(() {
      isMenuOpen = false;
      isLandscape = !isLandscape;
      if (isLandscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeRight,
          DeviceOrientation.landscapeLeft
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp
        ]);
      }
    });
  }

  Future<void> _startLiveAndLock() async {
    String cableUrl = cableRtmpController.text.trim();
    String satUrl = satelliteSrtController.text.trim();

    if (cableUrl.isEmpty && satUrl.isEmpty) {
      _showMultiStreamDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("దయచేసి కనీసం ఒక లింక్ (Cable/Satellite) ఇవ్వండి."), backgroundColor: Colors.red)
      );
      return;
    }
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
    }
    try {
      bool success = await StreamServiceManager.startLiveStream(cableUrl, satUrl);
      if (success) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeRight,
          DeviceOrientation.landscapeLeft
        ]);
        setState(() {
          isLiveBroadcasting = true;
          isLivePaused = false;
          isLiveLocked = true;
          hideControls = true;
          isMenuOpen = false;
          isLandscape = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Multi-Live ప్రసారం ప్రారంభమైంది!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {}
  }

  Future<void> _stopLiveStream() async {
    try {
      bool success = await StreamServiceManager.stopLiveStream();
      if (success) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight
        ]);
        setState(() {
          isLiveBroadcasting = false;
          isLiveLocked = false;
          isLivePaused = false;
        });
      }
    } catch (e) {}
  }

  Future<void> _toggleDualScreenAndPickMedia() async {
    setState(() {
      isMenuOpen = false;
    });
    if (isDualScreenMode) {
      setState(() {
        isDualScreenMode = false;
        dualMediaList.clear();
        _bottomAdVideoController?.dispose();
        _bottomAdVideoController = null;
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
        });
        _playDualMedia(dualMediaList[currentDualMediaIndex]);
      }
    } catch (e) {}
  }

  void _playDualMedia(String path) {
    if (path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov')) {
      _bottomAdVideoController?.dispose();
      _bottomAdVideoController = VideoPlayerController.file(File(path))
        ..initialize().then((_) {
          if (mounted) {
            _bottomAdVideoController!.setLooping(true);
            _bottomAdVideoController!.setVolume(1.0);
            _bottomAdVideoController!.play();
            setState(() {});
          }
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

  Widget _buildMainDisplay(bool isScreenLandscape, double screenWidth, double screenHeight, Widget phoneCameraWidget) {
    
    Widget actualCameraWidget;
    if (isLivePaused) {
      actualCameraWidget = Container(
        color: Colors.black,
        child: const Center(
          child: Text("LIVE PAUSED", style: TextStyle(color: Colors.redAccent, fontSize: 30, fontWeight: FontWeight.bold))
        )
      );
    } else if (isDroneCamMode && _droneCamController != null && _droneCamController!.value.isInitialized) {
      actualCameraWidget = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _droneCamController!.value.size.width,
            height: _droneCamController!.value.size.height,
            child: VideoPlayer(_droneCamController!)
          )
        )
      );
    } else if (isExternalIpCamMode && _ipCamController != null && _ipCamController!.value.isInitialized) {
      actualCameraWidget = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _ipCamController!.value.size.width,
            height: _ipCamController!.value.size.height,
            child: VideoPlayer(_ipCamController!)
          )
        )
      );
    } else if (isUsbCamMode && _usbTextureId != null) {
      actualCameraWidget = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 1920,
            height: 1080,
            child: Texture(textureId: _usbTextureId!)
          )
        )
      );
    } else {
      actualCameraWidget = phoneCameraWidget;
    }

    if (isDualScreenMode && dualMediaList.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.amberAccent, width: 3.5),
          boxShadow: const [BoxShadow(color: Colors.redAccent, blurRadius: 10)]
        ),
        child: isScreenLandscape
            ? Row(
                children: [
                  Expanded(child: actualCameraWidget),
                  Container(width: 3, color: Colors.amberAccent),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return GestureDetector(
                                onTapUp: (details) {
                                  double dx = details.localPosition.dx;
                                  if (dx < constraints.maxWidth / 3) {
                                    _prevDualMedia();
                                  } else if (dx > constraints.maxWidth * 2 / 3) {
                                    _nextDualMedia();
                                  } else {
                                    _toggleDualMediaPause();
                                  }
                                },
                                child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized
                                    ? FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _bottomAdVideoController!.value.size.width,
                                          height: _bottomAdVideoController!.value.size.height,
                                          child: VideoPlayer(_bottomAdVideoController!)
                                        )
                                      )
                                    : Image.file(
                                        File(dualMediaList[currentDualMediaIndex]),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity
                                      )
                              );
                            }
                          )
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          color: Colors.amber,
                          child: Text(
                            splitScreenMainHeadline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)
                          )
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.blueAccent,
                          child: Text(
                            splitScreenSubHeadline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)
                          )
                        )
                      ]
                    )
                  )
                ]
              )
            : Column(
                children: [
                  Expanded(flex: 4, child: actualCameraWidget),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    color: Colors.amber,
                    child: Text(
                      splitScreenMainHeadline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)
                    )
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    color: Colors.blueAccent,
                    child: Text(
                      splitScreenSubHeadline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)
                    )
                  ),
                  Expanded(
                    flex: 4,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onTapUp: (details) {
                            double dx = details.localPosition.dx;
                            if (dx < constraints.maxWidth / 3) {
                              _prevDualMedia();
                            } else if (dx > constraints.maxWidth * 2 / 3) {
                              _nextDualMedia();
                            } else {
                              _toggleDualMediaPause();
                            }
                          },
                          child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized
                              ? FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _bottomAdVideoController!.value.size.width,
                                    height: _bottomAdVideoController!.value.size.height,
                                    child: VideoPlayer(_bottomAdVideoController!)
                                  )
                                )
                              : Image.file(
                                  File(dualMediaList[currentDualMediaIndex]),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity
                                )
                        );
                      }
                    )
                  )
                ]
              )
      );
    }

    bool showAds = isNewsBulletinMode || isAdCurrentlyShowing;
    
    double topAreaH = screenHeight; 
    double lAdW = 0; 
    double rAdW = 0; 
    double bAdH = 0;
    double vW = screenWidth; 
    double vH = topAreaH;
    double vLeft = 0;

    if (showAds) {
      if (adShapeMode == 0) { 
        double adW = screenWidth * 0.20;
        vW = screenWidth - adW; 
        vH = vW * (9 / 16); 
        bAdH = topAreaH - vH;
        if (bAdH < topAreaH * 0.15) { 
          bAdH = topAreaH * 0.15; 
          vH = topAreaH - bAdH; 
          vW = vH * (16 / 9); 
          adW = screenWidth - vW; 
        }
        if (isLBandRight) { 
          lAdW = 0; 
          rAdW = adW; 
          vLeft = 0; 
        } else { 
          lAdW = adW; 
          rAdW = 0; 
          vLeft = adW; 
        }
      } else if (adShapeMode == 1) { 
        lAdW = screenWidth * 0.18; 
        rAdW = screenWidth * 0.18;
        vW = screenWidth - lAdW - rAdW; 
        vH = topAreaH; 
        vLeft = lAdW; 
        bAdH = 0;
      } else if (adShapeMode == 2) { 
        lAdW = screenWidth * 0.15; 
        rAdW = screenWidth * 0.15;
        vW = screenWidth - lAdW - rAdW; 
        vH = vW * (9 / 16); 
        bAdH = topAreaH - vH;
        if (bAdH < topAreaH * 0.15) { 
          bAdH = topAreaH * 0.15; 
          vH = topAreaH - bAdH; 
          vW = vH * (16 / 9); 
          lAdW = (screenWidth - vW) / 2; 
          rAdW = lAdW; 
        }
        vLeft = lAdW;
      }
    }

    Widget mainPlayer = isNewsBulletinMode && (_bulletinVideoController != null && _bulletinVideoController!.value.isInitialized)
        ? SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _bulletinVideoController!.value.size.width,
                height: _bulletinVideoController!.value.size.height,
                child: VideoPlayer(_bulletinVideoController!)
              )
            )
          )
        : actualCameraWidget;

    return Container(
      color: Colors.black, 
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            left: showAds ? vLeft : 0,
            top: 0,
            width: showAds ? vW : screenWidth,
            height: showAds ? vH : topAreaH,
            child: Stack(
              children: [
                SizedBox.expand(
                  child: ClipRect(
                    child: mainPlayer
                  )
                ),
                if (isNewsBulletinMode && isCameraVisible)
                  Positioned(
                    top: pipTop,
                    left: pipLeft,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          pipTop += details.delta.dy;
                          pipLeft += details.delta.dx;
                        });
                      },
                      child: Container(
                        width: isScreenLandscape ? screenWidth * 0.28 : screenWidth * 0.38,
                        height: (isScreenLandscape ? screenWidth * 0.28 : screenWidth * 0.38) * (screenHeight / screenWidth),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.amber, width: 2.0),
                          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 8)]
                        ),
                        child: actualCameraWidget
                      )
                    )
                  )
              ]
            )
          ),
          
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            left: showAds && lAdW > 0 ? 0 : -screenWidth * 0.25,
            top: 0,
            width: lAdW > 0 ? lAdW : screenWidth * 0.20,
            height: topAreaH,
            child: GestureDetector(
              onTap: () => _pickAds('left'),
              onLongPress: () => _manageAdsDialog('left'),
              child: Container(
                color: Colors.black,
                child: leftAdPaths.isNotEmpty
                    ? (_leftAdVideoCtrl != null && _leftAdVideoCtrl!.value.isInitialized
                        ? FittedBox(
                            fit: BoxFit.fill,
                            child: SizedBox(
                              width: _leftAdVideoCtrl!.value.size.width,
                              height: _leftAdVideoCtrl!.value.size.height,
                              child: VideoPlayer(_leftAdVideoCtrl!)
                            )
                          )
                        : SizedBox.expand(
                            child: Image.file(
                              File(leftAdPaths[leftAdIndex]),
                              fit: BoxFit.fill
                            )
                          ))
                    : Center(
                        child: Text(
                          "LEFT ADS (${leftAdPaths.length})\nTap: Add\nLong Press: Edit",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                        )
                      )
              )
            )
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            right: showAds && rAdW > 0 ? 0 : -screenWidth * 0.25,
            top: 0,
            width: rAdW > 0 ? rAdW : screenWidth * 0.20,
            height: topAreaH,
            child: GestureDetector(
              onTap: () => _pickAds('right'),
              onLongPress: () => _manageAdsDialog('right'),
              child: Container(
                color: Colors.black,
                child: rightAdPaths.isNotEmpty
                    ? (_rightAdVideoCtrl != null && _rightAdVideoCtrl!.value.isInitialized
                        ? FittedBox(
                            fit: BoxFit.fill,
                            child: SizedBox(
                              width: _rightAdVideoCtrl!.value.size.width,
                              height: _rightAdVideoCtrl!.value.size.height,
                              child: VideoPlayer(_rightAdVideoCtrl!)
                            )
                          )
                        : SizedBox.expand(
                            child: Image.file(
                              File(rightAdPaths[rightAdIndex]),
                              fit: BoxFit.fill
                            )
                          ))
                    : Center(
                        child: Text(
                          "RIGHT ADS (${rightAdPaths.length})\nTap: Add\nLong Press: Edit",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                        )
                      )
              )
            )
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            left: showAds ? vLeft : 0,
            top: showAds && bAdH > 0 ? vH : topAreaH + 50,
            width: showAds ? vW : screenWidth,
            height: bAdH > 0 ? bAdH : 50,
            child: GestureDetector(
              onTap: () => _pickAds('bottom'),
              onLongPress: () => _manageAdsDialog('bottom'),
              child: Container(
                color: Colors.black,
                child: bottomAdPaths.isNotEmpty
                    ? (_bottomAdVideoCtrlForAds != null && _bottomAdVideoCtrlForAds!.value.isInitialized
                        ? FittedBox(
                            fit: BoxFit.fill,
                            child: SizedBox(
                              width: _bottomAdVideoCtrlForAds!.value.size.width,
                              height: _bottomAdVideoCtrlForAds!.value.size.height,
                              child: VideoPlayer(_bottomAdVideoCtrlForAds!)
                            )
                          )
                        : SizedBox.expand(
                            child: Image.file(
                              File(bottomAdPaths[bottomAdIndex]),
                              fit: BoxFit.fill
                            )
                          ))
                    : Center(
                        child: Text(
                          "BOTTOM ADS (${bottomAdPaths.length})\nTap to Add | Long Press to Edit",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)
                        )
                      )
              )
            )
          ),
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isScreenLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    double camW = 1080;
    double camH = 1920;
    if (_isCameraInitialized && controller != null && controller!.value.isInitialized) {
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
        : (_isCameraInitialized && controller != null && controller!.value.isInitialized)
            ? GestureDetector(
                onScaleStart: (details) {
                  _baseScale = _currentZoomLevel;
                },
                onScaleUpdate: (details) async {
                  if (controller == null || !controller!.value.isInitialized) return;
                  double zoom = _baseScale * details.scale;
                  if (zoom < _minZoomLevel) zoom = _minZoomLevel;
                  if (zoom > _maxZoomLevel) zoom = _maxZoomLevel;
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
                        child: CameraPreview(controller!)
                      )
                    )
                  )
                )
              )
            : const Center(child: CircularProgressIndicator(color: Colors.amber));

    Widget animatedReporterBadge = ScaleTransition(
      scale: Tween<double>(begin: 0.96, end: 1.04).animate(
        CurvedAnimation(parent: _motionController, curve: Curves.easeInOut)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (watermarkText.isNotEmpty)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                watermarkText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0)
              )
            ),
          Container(
            color: Colors.red.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              locationText,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0)
            )
          ),
          const SizedBox(height: 2),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              reporterName,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13.0)
            )
          ),
          Container(
            color: Colors.red.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              reporterRole,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0)
            )
          )
        ]
      ),
    );

    Widget channelLogoWidget = channelLogoPath.isNotEmpty
        ? SizedBox(
            width: logoWidth,
            height: logoHeight,
            child: Image.file(
              File(channelLogoPath),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high
            )
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.red[900]?.withOpacity(0.9),
            child: const Text(
              "SS YATRA TV",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
            )
          );

    String getAdButtonLabel() {
      if (adDisplayMode == 0) return "Ads OFF";
      if (adDisplayMode == 1) return "Ads ON";
      return "Auto Ads";
    }

    Color getAdButtonColor() {
      if (adDisplayMode == 0) return Colors.redAccent;
      if (adDisplayMode == 1) return Colors.blueAccent;
      return Colors.greenAccent;
    }

    String getShapeButtonLabel() {
      if (adShapeMode == 0) return "Shape: L-Band";
      if (adShapeMode == 1) return "Shape: 2-Sides";
      return "Shape: U-Band";
    }

    Color getShapeButtonColor() {
      if (adShapeMode == 0) return Colors.orange;
      if (adShapeMode == 1) return Colors.purpleAccent;
      return Colors.teal;
    }

    final List<Color> bgColors = [
      const Color(0xFF0D47A1),
      Colors.red.shade900,
      Colors.purple.shade900,
      Colors.teal.shade900
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!isLiveLocked) {
              setState(() {
                isMenuOpen ? isMenuOpen = false : hideControls = !hideControls;
              });
            }
          },
          onLongPress: () {
            if (isLiveLocked) {
              setState(() {
                isLiveLocked = false;
                hideControls = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("స్క్రీన్ అన్‌‌లాక్ చేయబడింది."))
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
                    child: _buildMainDisplay(isScreenLandscape, screenW, topAreaH, phoneCameraWidget)
                  ),
                  
                  Positioned(
                    top: (logoPosition == 0 || logoPosition == 1) ? 15.0 : null,
                    bottom: (logoPosition == 2 || logoPosition == 3) ? 65.0 : null,
                    left: (logoPosition == 0 || logoPosition == 2) ? 15.0 : null,
                    right: (logoPosition == 1 || logoPosition == 3) ? 15.0 : null,
                    child: channelLogoWidget
                  ),

                  if (!isDualScreenMode && !isAdCurrentlyShowing && !isNewsBulletinMode)
                    Positioned(
                      bottom: 65,
                      left: 15.0,
                      child: animatedReporterBadge
                    ),

                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: tickerH,
                    child: AnimatedContainer(
                      duration: const Duration(seconds: 2),
                      decoration: BoxDecoration(
                        color: bgColors[_tickerBgColorIndex % bgColors.length],
                        border: Border.all(color: Colors.amber.shade400, width: 1.5)
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 95,
                            color: Colors.red.shade900,
                            alignment: Alignment.center,
                            child: const Text(
                              "BREAKING\nNEWS",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)
                            )
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0),
                              child: AnimatedBuilder(
                                animation: _motionController,
                                builder: (context, child) {
                                  return ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: const [
                                        Colors.yellowAccent,
                                        Colors.white,
                                        Colors.cyanAccent,
                                        Colors.yellowAccent
                                      ],
                                      stops: const [0.0, 0.33, 0.66, 1.0],
                                      transform: GradientRotation(_motionController.value * 2 * 3.1415),
                                    ).createShader(bounds),
                                    child: child,
                                  );
                                },
                                child: Marquee(
                                  text: breakingNewsText,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                  blankSpace: 100.0,
                                  velocity: 45.0
                                ),
                              ),
                            )
                          )
                        ]
                      ),
                    ),
                  ),

                  if (!hideControls && !isLiveLocked)
                    Positioned(
                      bottom: 75,
                      right: 20,
                      child: FloatingActionButton(
                        backgroundColor: Colors.blueAccent,
                        onPressed: () {
                          setState(() {
                            isMenuOpen = !isMenuOpen;
                          });
                        },
                        child: Icon(isMenuOpen ? Icons.close : Icons.menu, color: Colors.white)
                      )
                    ),

                  if (!hideControls && isMenuOpen && !isLiveLocked)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black87,
                        child: Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 25,
                            runSpacing: 25,
                            children: [
                              _buildControlButton(Icons.flip_camera_android, "Phone Cam", _switchCamera, Colors.white),
                              _buildControlButton(
                                isCameraVisible ? Icons.videocam_off : Icons.videocam,
                                isCameraVisible ? "Cam OFF" : "Cam ON",
                                _toggleCameraVisibility,
                                isCameraVisible ? Colors.redAccent : Colors.greenAccent
                              ),
                              _buildControlButton(Icons.video_call, "Ext. Cams", _showExternalCamsDialog, Colors.tealAccent),
                              
                              _buildControlButton(Icons.dashboard_customize, "PCR Board", () {
                                setState(() { isMenuOpen = false; }); 
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const MasterPCRBoard()),
                                );
                              }, Colors.amberAccent),

                              _buildControlButton(Icons.live_tv, "Multi-Live", _showMultiStreamDialog, Colors.redAccent),
                              _buildControlButton(Icons.grid_on, "Dual Screen", _toggleDualScreenAndPickMedia, Colors.orangeAccent),
                              if (isLiveBroadcasting) _buildControlButton(Icons.stop, "Stop Live", _stopLiveStream, Colors.red),

                              _buildControlButton(Icons.settings, "Settings", _showEditDialog, Colors.blue),
                              
                              _buildControlButton(Icons.visibility, getAdButtonLabel(), _toggleAdMode, getAdButtonColor()),
                              _buildControlButton(Icons.dashboard, getShapeButtonLabel(), _toggleAdShapeMode, getShapeButtonColor()),
                              
                              _buildControlButton(Icons.picture_in_picture_alt, "Logo Pos", _changeLogoPosition, Colors.lightGreenAccent),
                              
                              if (adShapeMode == 0)
                                _buildControlButton(Icons.swap_horiz, "L-Band L/R", _toggleLBandDirection, Colors.orange),
                              
                              _buildControlButton(Icons.screen_rotation, "Rotate", _toggleRotation, Colors.purple),
                              
                              _buildControlButton(Icons.bar_chart, "Election Results", () {
                              setState(() { isMenuOpen = false; }); 
                              Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ElectionBoardScreen())
                              );
                              }, Colors.indigoAccent),
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
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white30,
            child: Icon(icon, color: iconColor, size: 26)
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12)
          )
        ]
      )
    );
  }
}

class StreamServiceManager {
  static const platform = MethodChannel('com.kingjvk.pocket_pcr/stream');
  
  static Future<bool> startLiveStream(String cableRtmp, String satelliteSrt) async {
    try {
      String safeCable = cableRtmp.replaceFirst('rtmps://', 'rtmp://');
      await platform.invokeMethod('startScreenCaptureStreaming', {
        'cableRtmp': safeCable,
        'satelliteSrt': satelliteSrt
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
