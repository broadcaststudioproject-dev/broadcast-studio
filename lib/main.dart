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

class _StudioScreenState extends State<StudioScreen> with WidgetsBindingObserver {
  
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
  int logoPosition = 1; 

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

  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA";
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String breakingNewsText = "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";

  String splitScreenMainHeadline = "రైతు పొలంలో కలకలం.. గట్లపై భారీ పులి అడుగుల గుర్తులు!";
  String splitScreenSubHeadline = "వార్తా అప్డేట్";

  TextEditingController youtubeUrlController = TextEditingController();
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

  // --- మల్టీపుల్ U-Band Ads Control Variables ---
  List<String> leftAdPaths = [];
  List<String> rightAdPaths = [];
  List<String> bottomAdPaths = [];
  
  int leftAdIndex = 0;
  int rightAdIndex = 0;
  int bottomAdIndex = 0;

  VideoPlayerController? _leftAdVideoCtrl;
  VideoPlayerController? _rightAdVideoCtrl;
  VideoPlayerController? _bottomAdVideoCtrlForAds; 

  // --- External IP Cam & USB UVC Cam Variables ---
  bool isExternalIpCamMode = false;
  bool isUsbCamMode = false;
  VideoPlayerController? _ipCamController;
  TextEditingController ipCamUrlCtrl = TextEditingController();
  int? _usbTextureId; 

  // --- 3-State ఆటోమేటిక్ యాడ్స్ టైమర్ ---
  int adDisplayMode = 0; // 0 = OFF, 1 = ON (Continuous), 2 = Auto Timer
  bool isAdCurrentlyShowing = false; 
  Timer? _adCycleTimer;

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
    youtubeUrlController.text = "rtmp://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY_HERE";
    ipCamUrlCtrl.text = "http://192.168.1.100:8080/video"; 

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, 
      DeviceOrientation.landscapeLeft, 
      DeviceOrientation.landscapeRight
    ]);

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

      youtubeUrlController.text = prefs.getString('youtubeUrl') ?? "rtmp://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY_HERE";
      youtubeVideoUrlCtrl.text = prefs.getString('youtubeVideoUrl') ?? "";
      networkVideoUrlCtrl.text = prefs.getString('networkVideoUrl') ?? "";
      ipCamUrlCtrl.text = prefs.getString('ipCamUrl') ?? "http://192.168.1.100:8080/video";

      watermarkCtrl.text = watermarkText;
      locCtrl.text = locationText;
      nameCtrl.text = reporterName;
      roleCtrl.text = reporterRole;
      mainHeadlineCtrl.text = splitScreenMainHeadline;
      subHeadlineCtrl.text = splitScreenSubHeadline;

      String savedLogo = prefs.getString('channelLogoPath') ?? "";
      if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) channelLogoPath = savedLogo;

      leftAdPaths = (prefs.getStringList('leftAdPaths') ?? []).where((path) => File(path).existsSync()).toList();
      rightAdPaths = (prefs.getStringList('rightAdPaths') ?? []).where((path) => File(path).existsSync()).toList();
      bottomAdPaths = (prefs.getStringList('bottomAdPaths') ?? []).where((path) => File(path).existsSync()).toList();

      if (leftAdPaths.isNotEmpty) _initAdVideo('left');
      if (rightAdPaths.isNotEmpty) _initAdVideo('right');
      if (bottomAdPaths.isNotEmpty) _initAdVideo('bottom');
    });
  }

  void _initAdVideo(String pos) {
    String path = "";
    if (pos == 'left' && leftAdPaths.isNotEmpty) {
      if(leftAdIndex >= leftAdPaths.length) leftAdIndex = 0;
      path = leftAdPaths[leftAdIndex];
    }
    if (pos == 'right' && rightAdPaths.isNotEmpty) {
      if(rightAdIndex >= rightAdPaths.length) rightAdIndex = 0;
      path = rightAdPaths[rightAdIndex];
    }
    if (pos == 'bottom' && bottomAdPaths.isNotEmpty) {
      if(bottomAdIndex >= bottomAdPaths.length) bottomAdIndex = 0;
      path = bottomAdPaths[bottomAdIndex];
    }

    if (path.isEmpty) return;

    bool isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov');

    if (pos == 'left') {
      _leftAdVideoCtrl?.dispose();
      _leftAdVideoCtrl = null;
      if (isVideo) {
        _leftAdVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) {
            if (mounted) { _leftAdVideoCtrl!.setLooping(true); _leftAdVideoCtrl!.setVolume(0.0); _leftAdVideoCtrl!.play(); setState(() {}); }
        });
      }
    } else if (pos == 'right') {
      _rightAdVideoCtrl?.dispose();
      _rightAdVideoCtrl = null;
      if (isVideo) {
        _rightAdVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) {
            if (mounted) { _rightAdVideoCtrl!.setLooping(true); _rightAdVideoCtrl!.setVolume(0.0); _rightAdVideoCtrl!.play(); setState(() {}); }
        });
      }
    } else if (pos == 'bottom') {
      _bottomAdVideoCtrlForAds?.dispose();
      _bottomAdVideoCtrlForAds = null;
      if (isVideo) {
        _bottomAdVideoCtrlForAds = VideoPlayerController.file(File(path))..initialize().then((_) {
            if (mounted) { _bottomAdVideoCtrlForAds!.setLooping(true); _bottomAdVideoCtrlForAds!.setVolume(0.0); _bottomAdVideoCtrlForAds!.play(); setState(() {}); }
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
  }

  Future<void> _saveLinks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('youtubeUrl', youtubeUrlController.text);
    await prefs.setString('youtubeVideoUrl', youtubeVideoUrlCtrl.text);
    await prefs.setString('networkVideoUrl', networkVideoUrlCtrl.text);
    await prefs.setString('ipCamUrl', ipCamUrlCtrl.text);
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
    _bottomAdVideoController?.dispose();
    
    _leftAdVideoCtrl?.dispose();
    _rightAdVideoCtrl?.dispose();
    _bottomAdVideoCtrlForAds?.dispose();
    _ipCamController?.dispose();

    youtubeUrlController.dispose();
    networkVideoUrlCtrl.dispose();
    youtubeVideoUrlCtrl.dispose();
    ipCamUrlCtrl.dispose();
    watermarkCtrl.dispose();
    locCtrl.dispose();
    nameCtrl.dispose();
    roleCtrl.dispose();
    manualTickerCtrl.dispose();
    mainHeadlineCtrl.dispose();
    subHeadlineCtrl.dispose();
    super.dispose();
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
      final camController = CameraController(cameras[currentCameraIndex], ResolutionPreset.high, enableAudio: false);
      controller = camController;
      await camController.initialize();
      if (!mounted) return;
      _minZoomLevel = await camController.getMinZoomLevel();
      _maxZoomLevel = await camController.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      setState(() { _isCameraInitialized = true; });
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
    setState(() { isMenuOpen = false; });
  }

  void _toggleCameraVisibility() async {
    setState(() { isMenuOpen = false; });
    
    if (isExternalIpCamMode || isUsbCamMode) {
      setState(() {
        isExternalIpCamMode = false;
        isUsbCamMode = false;
        isCameraVisible = false;
        _usbTextureId = null;
      });
      _ipCamController?.dispose();
      _ipCamController = null;
      try { await StreamServiceManager.stopUsbCamera(); } catch (_) {}
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

  // --- ఆటోమేటిక్ యాడ్స్ టైమర్ ---
  void _toggleAdMode() {
    setState(() {
      adDisplayMode = (adDisplayMode + 1) % 3;
      isMenuOpen = false;
      _adCycleTimer?.cancel();
      
      if (adDisplayMode == 0) {
        isAdCurrentlyShowing = false;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("యాడ్స్ ఆఫ్ చేయబడ్డాయి (OFF)"), backgroundColor: Colors.red));
      } else if (adDisplayMode == 1) {
        isAdCurrentlyShowing = true;
        _startPermanentCycle();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("యాడ్స్ ఆన్ (నిరంతరం ప్లే అవుతాయి)"), backgroundColor: Colors.blueAccent));
      } else if (adDisplayMode == 2) {
        isAdCurrentlyShowing = true;
        _startAutoCycle();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఆటో టైమర్ (20s ON / 40s OFF)"), backgroundColor: Colors.green));
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
          setState(() { isAdCurrentlyShowing = false; });
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

  // --- మల్టీపుల్ మీడియా అప్‌లోడ్ లాజిక్ ---
  Future<void> _pickLeftAds() async { 
    try { 
      final List<XFile> medias = await _picker.pickMultipleMedia(); 
      if (medias.isNotEmpty && mounted) {
        setState(() { 
          leftAdPaths.addAll(medias.map((e) => e.path).toList()); 
          leftAdIndex = leftAdPaths.length - medias.length; // కొత్తగా యాడ్ చేసినది ప్లే అవ్వడానికి
        }); 
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('leftAdPaths', leftAdPaths);
        _initAdVideo('left');
      } 
    } catch (e) {} 
  }

  Future<void> _pickRightAds() async { 
    try { 
      final List<XFile> medias = await _picker.pickMultipleMedia(); 
      if (medias.isNotEmpty && mounted) {
        setState(() { 
          rightAdPaths.addAll(medias.map((e) => e.path).toList()); 
          rightAdIndex = rightAdPaths.length - medias.length;
        }); 
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('rightAdPaths', rightAdPaths);
        _initAdVideo('right');
      } 
    } catch (e) {} 
  }

  Future<void> _pickBottomAds() async { 
    try { 
      final List<XFile> medias = await _picker.pickMultipleMedia(); 
      if (medias.isNotEmpty && mounted) {
        setState(() { 
          bottomAdPaths.addAll(medias.map((e) => e.path).toList()); 
          bottomAdIndex = bottomAdPaths.length - medias.length;
        }); 
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('bottomAdPaths', bottomAdPaths);
        _initAdVideo('bottom');
      } 
    } catch (e) {} 
  }

  // --- కొత్తగా: స్మార్ట్ డిలీట్ / క్లియర్ ఆప్షన్స్ (Long Press Action) ---
  void _showAdDeleteOptions(String pos) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("యాడ్స్ సెట్టింగ్స్", style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.orange),
                title: const Text("ప్రస్తుతం కనిపిస్తున్న యాడ్ తీసేయండి", style: TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteCurrentAd(pos);
                }
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("అన్ని యాడ్స్ క్లియర్ చేయండి", style: TextStyle(color: Colors.white, fontSize: 13)),
                onTap: () {
                  Navigator.pop(context);
                  _clearAllAds(pos);
                }
              )
            ]
          )
        );
      }
    );
  }

  Future<void> _deleteCurrentAd(String pos) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      if (pos == 'left' && leftAdPaths.isNotEmpty) {
        leftAdPaths.removeAt(leftAdIndex);
        if (leftAdPaths.isEmpty) {
          _leftAdVideoCtrl?.dispose(); _leftAdVideoCtrl = null; leftAdIndex = 0;
        } else {
          if (leftAdIndex >= leftAdPaths.length) leftAdIndex = 0;
          _initAdVideo('left');
        }
        prefs.setStringList('leftAdPaths', leftAdPaths);
      }
      else if (pos == 'right' && rightAdPaths.isNotEmpty) {
        rightAdPaths.removeAt(rightAdIndex);
        if (rightAdPaths.isEmpty) {
          _rightAdVideoCtrl?.dispose(); _rightAdVideoCtrl = null; rightAdIndex = 0;
        } else {
          if (rightAdIndex >= rightAdPaths.length) rightAdIndex = 0;
          _initAdVideo('right');
        }
        prefs.setStringList('rightAdPaths', rightAdPaths);
      }
      else if (pos == 'bottom' && bottomAdPaths.isNotEmpty) {
        bottomAdPaths.removeAt(bottomAdIndex);
        if (bottomAdPaths.isEmpty) {
          _bottomAdVideoCtrlForAds?.dispose(); _bottomAdVideoCtrlForAds = null; bottomAdIndex = 0;
        } else {
          if (bottomAdIndex >= bottomAdPaths.length) bottomAdIndex = 0;
          _initAdVideo('bottom');
        }
        prefs.setStringList('bottomAdPaths', bottomAdPaths);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("యాడ్ డిలీట్ అయింది.")));
  }

  Future<void> _clearAllAds(String pos) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      if (pos == 'left') {
        leftAdPaths.clear(); leftAdIndex = 0; _leftAdVideoCtrl?.dispose(); _leftAdVideoCtrl = null;
        prefs.setStringList('leftAdPaths', []);
      } else if (pos == 'right') {
        rightAdPaths.clear(); rightAdIndex = 0; _rightAdVideoCtrl?.dispose(); _rightAdVideoCtrl = null;
        prefs.setStringList('rightAdPaths', []);
      } else if (pos == 'bottom') {
        bottomAdPaths.clear(); bottomAdIndex = 0; _bottomAdVideoCtrlForAds?.dispose(); _bottomAdVideoCtrlForAds = null;
        prefs.setStringList('bottomAdPaths', []);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("అన్ని యాడ్స్ క్లియర్ అయ్యాయి.")));
  }

  // --- External Cams, Web Streaming, etc. (పాత ఫీచర్లు అలాగే ఉన్నాయి) ---
  Future<void> _startIpCamera(String url) async {
    if (url.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("IP కెమెరాకు కనెక్ట్ అవుతోంది..."), backgroundColor: Colors.orange));
    
    _ipCamController?.dispose();
    _ipCamController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          isExternalIpCamMode = true; isUsbCamMode = false; isCameraVisible = true;
          isNewsBulletinMode = false; isDualScreenMode = false;
        });
        _ipCamController?.play();
      }).catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("IP కెమెరా కనెక్ట్ కాలేదు. లింక్ లేదా నెట్‌వర్క్ చెక్ చేయండి."), backgroundColor: Colors.red));
      });
  }

  Future<void> _startUsbCamera() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("USB Capture Card కోసం వెతుకుతోంది..."), backgroundColor: Colors.orange));
    try {
      final int? textureId = await StreamServiceManager.startUsbCamera();
      if (textureId != null) {
        setState(() {
          _usbTextureId = textureId; isUsbCamMode = true; isExternalIpCamMode = false;
          isCameraVisible = true; isNewsBulletinMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("USB Capture Card / ఎక్స్‌టర్నల్ కెమెరా కనెక్ట్ అయ్యింది!"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("USB కెమెరా కనెక్ట్ కాలేదు. OTG సెట్టింగ్ ఆన్‌లో ఉందో లేదో చూడండి."), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("USB కెమెరా యాక్సెస్ చేయడానికి Android UVC కోడ్ ఇంకా రాయబడలేదు."), backgroundColor: Colors.redAccent));
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
                  const Text("1. IP Camera / Wi-Fi CCTV", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
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
                  
                  const Text("2. USB / Type-C Capture Card", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                    onPressed: () { 
                      Navigator.pop(context); 
                      _startUsbCamera(); 
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

  Future<void> _startNetworkBulletin(String url) async {
    if (url.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("యూట్యూబ్ లింక్ ప్రాసెస్ అవుతోంది..."), backgroundColor: Colors.orange));
    String finalPlayUrl = url;

    if (url.contains("youtube.com") || url.contains("youtu.be")) {
      try {
        var ytExplode = yt.YoutubeExplode();
        String? videoId;
        try { videoId = yt.VideoId.parseVideoId(url); } catch (_) {}
        if (videoId == null) {
          RegExp regExp = RegExp(r'(?:v=|/v/|embed/|youtu\.be/|/live/)([a-zA-Z0-9_-]{11})', caseSensitive: false);
          Match? match = regExp.firstMatch(url);
          if (match != null && match.groupCount >= 1) { videoId = match.group(1); }
        }
        if (videoId == null) {
          ytExplode.close();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("తప్పు యూట్యూబ్ లింక్."), backgroundColor: Colors.red));
          return; 
        }
        var video = await ytExplode.videos.get(yt.VideoId(videoId));
        if (video.isLive) {
          finalPlayUrl = await ytExplode.videos.streamsClient.getHttpLiveStreamUrl(video.id);
        } else {
          var manifest = await ytExplode.videos.streamsClient.getManifest(video.id);
          finalPlayUrl = manifest.muxed.withHighestBitrate().url.toString();
        }
        ytExplode.close();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఈ లింక్‌‌ను ప్లే చేయలేము."), backgroundColor: Colors.red));
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("వీడియో ప్లే అవుతోంది..."), backgroundColor: Colors.green));
    _bulletinVideoController?.removeListener(_videoListener);
    _bulletinVideoController?.dispose();
    
    _bulletinVideoController = VideoPlayerController.networkUrl(Uri.parse(finalPlayUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
        setState(() { 
          isNewsBulletinMode = true; 
          isDualScreenMode = false; 
          hideControls = true; 
        });
        _bulletinVideoController?.play();
        _bulletinVideoController?.addListener(_videoListener);
      }).catchError((e) { 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("వీడియో ప్లే అవ్వడం లేదు."), backgroundColor: Colors.red)); 
      });
  }

  Future<void> _playLocalGalleryVideo() async {
    try {
      final XFile? videoFile = await _picker.pickVideo(source: ImageSource.gallery);
      if (videoFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("గ్యాలరీ వీడియో లోడ్ అవుతోంది..."), backgroundColor: Colors.orange)
        );
        _bulletinVideoController?.removeListener(_videoListener);
        _bulletinVideoController?.dispose();
        
        _bulletinVideoController = VideoPlayerController.file(File(videoFile.path))
          ..initialize().then((_) {
            if (!mounted) return;
            _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
            setState(() { 
              isNewsBulletinMode = true; 
              isDualScreenMode = false; 
              hideControls = true; 
            });
            _bulletinVideoController?.play();
            _bulletinVideoController?.addListener(_videoListener);
          }).catchError((e) { 
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("వీడియో ప్లే అవ్వడం లేదు."), backgroundColor: Colors.red)); 
          });
      }
    } catch (e) { debugPrint("Gallery Video Error: $e"); }
  }

  void _videoListener() {
    final vController = _bulletinVideoController;
    if (vController == null || !vController.value.isInitialized) return;
    if (vController.value.position >= vController.value.duration && vController.value.duration != Duration.zero) {
      vController.removeListener(_videoListener);
      setState(() { isNewsBulletinMode = false; });
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
                  _buildLinkEditor("1. YouTube/Restream RTMP Key", youtubeUrlController, setDialogState),
                  const Divider(color: Colors.white24, height: 20),
                  _buildLinkEditor("2. YouTube Video Link", youtubeVideoUrlCtrl, setDialogState, onPlay: () { Navigator.pop(context); _startNetworkBulletin(youtubeVideoUrlCtrl.text.trim()); }),
                  const Divider(color: Colors.white24, height: 20),
                  _buildLinkEditor("3. Direct Network Video (MP4)", networkVideoUrlCtrl, setDialogState, onPlay: () { Navigator.pop(context); _startNetworkBulletin(networkVideoUrlCtrl.text.trim()); }),
                  const Divider(color: Colors.white24, height: 20),
                  const Text("4. గ్యాలరీ వీడియో (MP4, HD, 4K, 8K)", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 10)),
                      onPressed: () { Navigator.pop(context); _playLocalGalleryVideo(); },
                      icon: const Icon(Icons.video_library, color: Colors.white, size: 20),
                      label: const Text("గ్యాలరీ నుండి సెలెక్ట్ చేయండి", style: TextStyle(color: Colors.white, fontSize: 12))
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
                        bool success = await StreamServiceManager.startLiveStream(youtubeUrlController.text.trim());
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
                        final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
                        if (image != null) { 
                          setState(() { channelLogoPath = image.path; }); 
                          SharedPreferences prefs = await SharedPreferences.getInstance();
                          await prefs.setString('channelLogoPath', image.path);
                          setDialogState(() {}); 
                        }
                      } catch (e) {}
                    }, 
                    icon: const Icon(Icons.upload), 
                    label: const Text("ఛానల్ లోగో అప్లోడ్")
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  TextField(controller: mainHeadlineCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "మెయిన్ హెడ్‌‌లైన్ (Yellow Box)")),
                  TextField(controller: subHeadlineCtrl, style: const TextStyle(color: Colors.cyanAccent), decoration: const InputDecoration(labelText: "సబ్ హెడ్‌‌లైన్ (Blue Box)")),
                  const Divider(color: Colors.white24, height: 20),
                  TextField(controller: manualTickerCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "మాన్యువల్ బ్రేకింగ్ టిక్కర్ న్యూస్")),
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
    String fullRtmpUrl = youtubeUrlController.text.trim();
    if (fullRtmpUrl.isEmpty || !fullRtmpUrl.contains("rtmp")) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("దయచేసి సరైన YouTube RTMP లింక్ ఇవ్వండి."), backgroundColor: Colors.red)); 
      return; 
    }

    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) { micStatus = await Permission.microphone.request(); }

    try {
      bool success = await StreamServiceManager.startLiveStream(fullRtmpUrl);
      if (success) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
        setState(() { isLiveBroadcasting = true; isLivePaused = false; isLiveLocked = true; hideControls = true; isMenuOpen = false; isLandscape = true; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("YouTube Live ప్రారంభమైంది!"), backgroundColor: Colors.green));
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
        if (titles.isNotEmpty && mounted) { setState(() { breakingNewsText = titles.join("   ♦   "); }); }
      }
    } catch (e) { }
  }

  // --- స్మూత్ యానిమేటెడ్ U-Band (Left, Right, Bottom) డిస్‌ప్లే ఫంక్షన్ ---
  Widget _buildMainDisplay(bool isScreenLandscape, double screenWidth, double screenHeight, Widget phoneCameraWidget) {
    
    Widget actualCameraWidget;
    if (isLivePaused) {
      actualCameraWidget = Container(color: Colors.black, child: const Center(child: Text("LIVE PAUSED", style: TextStyle(color: Colors.redAccent, fontSize: 30, fontWeight: FontWeight.bold))));
    } else if (isExternalIpCamMode && _ipCamController != null && _ipCamController!.value.isInitialized) {
      actualCameraWidget = SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _ipCamController!.value.size.width, height: _ipCamController!.value.size.height, child: VideoPlayer(_ipCamController!))));
    } else if (isUsbCamMode && _usbTextureId != null) {
      actualCameraWidget = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: 1920, height: 1080, child: Texture(textureId: _usbTextureId!)),
        ),
      );
    } else {
      actualCameraWidget = phoneCameraWidget;
    }

    bool showAds = isNewsBulletinMode || isAdCurrentlyShowing;
    
    double topAreaH = screenHeight; 
    double leftAdWidth = screenWidth * 0.15; 
    double rightAdWidth = screenWidth * 0.15; 
    double videoWidth = screenWidth - leftAdWidth - rightAdWidth; 
    double videoHeight = videoWidth * (9 / 16); 
    double bottomAdHeight = topAreaH - videoHeight;

    if (bottomAdHeight < topAreaH * 0.15) {
      bottomAdHeight = topAreaH * 0.15;
      videoHeight = topAreaH - bottomAdHeight;
      videoWidth = videoHeight * (16 / 9);
      leftAdWidth = (screenWidth - videoWidth) / 2;
      rightAdWidth = leftAdWidth;
    }

    Widget mainPlayer = isNewsBulletinMode && (_bulletinVideoController != null && _bulletinVideoController!.value.isInitialized) 
        ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bulletinVideoController!.value.size.width, height: _bulletinVideoController!.value.size.height, child: VideoPlayer(_bulletinVideoController!))))
        : actualCameraWidget;

    return Container(
      color: Colors.black, 
      child: Stack(
        children: [
          // 1. మెయిన్ వీడియో 
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            left: showAds ? leftAdWidth : 0,
            top: 0,
            width: showAds ? videoWidth : screenWidth,
            height: showAds ? videoHeight : topAreaH,
            child: Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: mainPlayer,
                  ),
                ),
                if (isNewsBulletinMode && isCameraVisible)
                  Positioned(
                    top: pipTop, left: pipLeft,
                    child: GestureDetector(
                      onPanUpdate: (details) { setState(() { pipTop += details.delta.dy; pipLeft += details.delta.dx; }); },
                      child: Container(
                        width: isScreenLandscape ? screenWidth * 0.28 : screenWidth * 0.38, 
                        height: (isScreenLandscape ? screenWidth * 0.28 : screenWidth * 0.38) * (screenHeight / screenWidth),
                        decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2.0), boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 8)]),
                        child: actualCameraWidget, 
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // 2. Left Ad 
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            left: showAds ? 0 : -leftAdWidth,
            top: 0,
            width: leftAdWidth,
            height: topAreaH,
            child: GestureDetector(
              onTap: _pickLeftAds,
              onLongPress: leftAdPaths.isNotEmpty ? () => _showAdDeleteOptions('left') : null,
              child: Container(
                color: Colors.black, 
                child: leftAdPaths.isNotEmpty 
                    ? (_leftAdVideoCtrl != null && _leftAdVideoCtrl!.value.isInitialized 
                        ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _leftAdVideoCtrl!.value.size.width, height: _leftAdVideoCtrl!.value.size.height, child: VideoPlayer(_leftAdVideoCtrl!)))
                        : SizedBox.expand(child: Image.file(File(leftAdPaths[leftAdIndex]), fit: BoxFit.fill))) 
                    : Center(child: Text("LEFT ADS (${leftAdPaths.length})\nTap to Add", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
              )
            ),
          ),

          // 3. Right Ad 
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            right: showAds ? 0 : -rightAdWidth,
            top: 0,
            width: rightAdWidth,
            height: topAreaH,
            child: GestureDetector(
              onTap: _pickRightAds,
              onLongPress: rightAdPaths.isNotEmpty ? () => _showAdDeleteOptions('right') : null,
              child: Container(
                color: Colors.black, 
                child: rightAdPaths.isNotEmpty 
                    ? (_rightAdVideoCtrl != null && _rightAdVideoCtrl!.value.isInitialized 
                        ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _rightAdVideoCtrl!.value.size.width, height: _rightAdVideoCtrl!.value.size.height, child: VideoPlayer(_rightAdVideoCtrl!)))
                        : SizedBox.expand(child: Image.file(File(rightAdPaths[rightAdIndex]), fit: BoxFit.fill))) 
                    : Center(child: Text("RIGHT ADS (${rightAdPaths.length})\nTap to Add", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
              )
            ),
          ),

          // 4. Bottom Ad 
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            left: showAds ? leftAdWidth : 0,
            top: showAds ? videoHeight : topAreaH,
            width: showAds ? videoWidth : screenWidth,
            height: bottomAdHeight,
            child: GestureDetector(
              onTap: _pickBottomAds,
              onLongPress: bottomAdPaths.isNotEmpty ? () => _showAdDeleteOptions('bottom') : null,
              child: Container(
                color: Colors.black, 
                child: bottomAdPaths.isNotEmpty 
                    ? (_bottomAdVideoCtrlForAds != null && _bottomAdVideoCtrlForAds!.value.isInitialized 
                        ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _bottomAdVideoCtrlForAds!.value.size.width, height: _bottomAdVideoCtrlForAds!.value.size.height, child: VideoPlayer(_bottomAdVideoCtrlForAds!)))
                        : SizedBox.expand(child: Image.file(File(bottomAdPaths[bottomAdIndex]), fit: BoxFit.fill))) 
                    : Center(child: Text("BOTTOM ADS (${bottomAdPaths.length})\nTap to Add", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))
              )
            ),
          ),
        ],
      ),
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
          Container(color: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text(watermarkText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
        Container(color: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
        const SizedBox(height: 2),
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13.0))),
        Container(color: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
      ]
    );

    Widget visualScreenLogoWidget = GestureDetector(
      onTap: () { setState(() { logoPosition = (logoPosition + 1) % 4; }); },
      child: channelLogoPath.isNotEmpty
          ? SizedBox(width: logoWidth, height: logoHeight, child: Image.file(File(channelLogoPath), fit: BoxFit.contain, filterQuality: FilterQuality.high))
          : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: Colors.red[900]?.withOpacity(0.9), child: const Text("SS YATRA TV", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
    );

    String getAdButtonLabel() {
      if (adDisplayMode == 0) return "Ads OFF";
      if (adDisplayMode == 1) return "Ads ON";
      return "Auto Ads";
    }
    Color getAdButtonColor() {
      if (adDisplayMode == 0) return Colors.pinkAccent;
      if (adDisplayMode == 1) return Colors.blueAccent;
      return Colors.greenAccent;
    }

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

                  if (!isDualScreenMode && !isAdCurrentlyShowing && !isNewsBulletinMode)
                    Positioned(bottom: 65, left: 15, child: reporterBadgeWidget),

                  Positioned(
                    bottom: 0, left: 0, right: 0, height: tickerH,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.red.shade900, border: Border.all(color: Colors.amber.shade400, width: 1.5)),
                      child: Row(
                        children: [
                          Container(width: 95, color: Colors.red.shade900, alignment: Alignment.center, child: const Text("BREAKING\nNEWS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
                          Expanded(child: Container(color: const Color(0xFF0D47A1), padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 45.0)))
                        ]
                      ),
                    ),
                  ),

                  if (!hideControls && !isLiveLocked)
                    Positioned(
                      bottom: 75, right: 20, 
                      child: FloatingActionButton(backgroundColor: Colors.blueAccent, onPressed: () { setState(() { isMenuOpen = !isMenuOpen; }); }, child: Icon(isMenuOpen ? Icons.close : Icons.menu, color: Colors.white))
                    ),

                  if (!hideControls && isMenuOpen && !isLiveLocked)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black87,
                        child: Center(
                          child: Wrap(
                            alignment: WrapAlignment.center, spacing: 25, runSpacing: 25, 
                            children: [
                              _buildControlButton(Icons.flip_camera_android, "Phone Cam", _switchCamera, Colors.white),
                              _buildControlButton(isCameraVisible ? Icons.videocam_off : Icons.videocam, isCameraVisible ? "Cam OFF" : "Cam ON", _toggleCameraVisibility, isCameraVisible ? Colors.redAccent : Colors.greenAccent),
                              _buildControlButton(Icons.video_call, "Ext. Cams", _showExternalCamsDialog, Colors.tealAccent),
                              _buildControlButton(Icons.live_tv, "Multi-Live", _showMultiStreamDialog, Colors.redAccent),
                              if (isLiveBroadcasting) _buildControlButton(Icons.stop, "Stop Live", _stopLiveStream, Colors.red),
                              _buildControlButton(Icons.settings, "Settings", _showEditDialog, Colors.blue),
                              _buildControlButton(Icons.visibility, getAdButtonLabel(), _toggleAdMode, getAdButtonColor()),
                              _buildControlButton(Icons.screen_rotation, "Rotate", _toggleRotation, Colors.purple),
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
          CircleAvatar(radius: 26, backgroundColor: Colors.white30, child: Icon(icon, color: iconColor, size: 26)), 
          const SizedBox(height: 6), 
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12))
        ]
      )
    );
  }
}

class StreamServiceManager {
  static const platform = MethodChannel('com.ssyatratv.pocket_pcr/stream');
  
  static Future<bool> startLiveStream(String rtmpUrl) async {
    try {
      String safeUrl = rtmpUrl.replaceFirst('rtmps://', 'rtmp://');
      await platform.invokeMethod('startScreenStream', { 'rtmpUrl': safeUrl, 'recordAudio': true }); 
      return true; 
    } catch (e) { return false; }
  }
  
  static Future<bool> stopLiveStream() async {
    try { await platform.invokeMethod('stopScreenStream'); return true; } catch (e) { return false; }
  }

  static Future<int?> startUsbCamera() async {
    try {
      final int? textureId = await platform.invokeMethod('startUsbCamera');
      return textureId;
    } catch (e) {
      return null;
    }
  }

  static Future<void> stopUsbCamera() async {
    try { await platform.invokeMethod('stopUsbCamera'); } catch (e) {}
  }
}
