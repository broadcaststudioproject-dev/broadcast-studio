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

// మీ పాత ఫైల్స్ & కొత్త మేనేజర్ లింక్ చేస్తున్నాం
import 'pcr_board.dart';
import 'election_board.dart';
import 'stream_manager.dart';
import 'main.dart'; 

class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  
  CameraController? controller;
  VideoPlayerController? _bulletinVideoController;
  VideoPlayerController? _bottomAdVideoController;

  List<String> dualMediaList = [];
  int currentDualMediaIndex = 0;

  bool isLiveLocked = false;
  bool hideControls = true; 
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
  TextEditingController ipCamUrlCtrl = TextEditingController();
  TextEditingController droneCamUrlCtrl = TextEditingController();

  Timer? _newsTimer;
  bool _isCameraInitialized = false;

  List<String> leftAdPaths = [];
  List<String> rightAdPaths = [];
  List<String> bottomAdPaths = [];
  int leftAdIndex = 0, rightAdIndex = 0, bottomAdIndex = 0;

  VideoPlayerController? _leftAdVideoCtrl;
  VideoPlayerController? _rightAdVideoCtrl;
  VideoPlayerController? _bottomAdVideoCtrlForAds;

  bool isExternalIpCamMode = false;
  bool isUsbCamMode = false;
  bool isDroneCamMode = false;
  VideoPlayerController? _ipCamController;
  VideoPlayerController? _droneCamController;
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
    
    _motionController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _tickerColorTimer = Timer.periodic(const Duration(seconds: 2), (timer) { if (mounted) setState(() => _tickerBgColorIndex++); });

    _loadSavedData();
    _requestPermissions();
    _fetchBreakingNews();
    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) => _fetchBreakingNews());
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      watermarkText = prefs.getString('watermarkText') ?? watermarkText;
      locationText = prefs.getString('locationText') ?? locationText;
      reporterName = prefs.getString('reporterName') ?? reporterName;
      reporterRole = prefs.getString('reporterRole') ?? reporterRole;
      breakingNewsText = prefs.getString('breakingNewsText') ?? breakingNewsText;
      splitScreenMainHeadline = prefs.getString('splitScreenMainHeadline') ?? splitScreenMainHeadline;
      splitScreenSubHeadline = prefs.getString('splitScreenSubHeadline') ?? splitScreenSubHeadline;
      adShapeMode = prefs.getInt('adShapeMode') ?? 0;
      logoPosition = prefs.getInt('logoPosition') ?? 0;
      youtubeUrlController.text = prefs.getString('youtubeUrl') ?? "";
      youtubeVideoUrlCtrl.text = prefs.getString('youtubeVideoUrl') ?? "";
      networkVideoUrlCtrl.text = prefs.getString('networkVideoUrl') ?? "";
      ipCamUrlCtrl.text = prefs.getString('ipCamUrl') ?? "http://192.168.1.100:8080/video";
      droneCamUrlCtrl.text = prefs.getString('droneCamUrl') ?? "rtsp://192.168.1.1:554/live";

      watermarkCtrl.text = watermarkText; locCtrl.text = locationText;
      nameCtrl.text = reporterName; roleCtrl.text = reporterRole;
      mainHeadlineCtrl.text = splitScreenMainHeadline; subHeadlineCtrl.text = splitScreenSubHeadline;

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
    if (pos == 'left' && leftAdPaths.isNotEmpty) { if (leftAdIndex >= leftAdPaths.length) leftAdIndex = 0; path = leftAdPaths[leftAdIndex]; }
    if (pos == 'right' && rightAdPaths.isNotEmpty) { if (rightAdIndex >= rightAdPaths.length) rightAdIndex = 0; path = rightAdPaths[rightAdIndex]; }
    if (pos == 'bottom' && bottomAdPaths.isNotEmpty) { if (bottomAdIndex >= bottomAdPaths.length) bottomAdIndex = 0; path = bottomAdPaths[bottomAdIndex]; }
    if (path.isEmpty) return;

    bool isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov');
    if (pos == 'left') {
      _leftAdVideoCtrl?.dispose(); _leftAdVideoCtrl = null;
      if (isVideo) { _leftAdVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { if (mounted) { _leftAdVideoCtrl!.setLooping(true); _leftAdVideoCtrl!.setVolume(0.0); _leftAdVideoCtrl!.play(); setState(() {}); } }); }
    } else if (pos == 'right') {
      _rightAdVideoCtrl?.dispose(); _rightAdVideoCtrl = null;
      if (isVideo) { _rightAdVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { if (mounted) { _rightAdVideoCtrl!.setLooping(true); _rightAdVideoCtrl!.setVolume(0.0); _rightAdVideoCtrl!.play(); setState(() {}); } }); }
    } else if (pos == 'bottom') {
      _bottomAdVideoCtrlForAds?.dispose(); _bottomAdVideoCtrlForAds = null;
      if (isVideo) { _bottomAdVideoCtrlForAds = VideoPlayerController.file(File(path))..initialize().then((_) { if (mounted) { _bottomAdVideoCtrlForAds!.setLooping(true); _bottomAdVideoCtrlForAds!.setVolume(0.0); _bottomAdVideoCtrlForAds!.play(); setState(() {}); } }); }
    }
  }

  Future<void> _saveTextSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('watermarkText', watermarkText); await prefs.setString('locationText', locationText);
    await prefs.setString('reporterName', reporterName); await prefs.setString('reporterRole', reporterRole);
    await prefs.setString('splitScreenMainHeadline', splitScreenMainHeadline); await prefs.setString('splitScreenSubHeadline', splitScreenSubHeadline);
    await prefs.setString('breakingNewsText', breakingNewsText); await prefs.setInt('adShapeMode', adShapeMode); await prefs.setInt('logoPosition', logoPosition);
  }

  Future<void> _saveLinks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('youtubeUrl', youtubeUrlController.text); await prefs.setString('youtubeVideoUrl', youtubeVideoUrlCtrl.text);
    await prefs.setString('networkVideoUrl', networkVideoUrlCtrl.text); await prefs.setString('ipCamUrl', ipCamUrlCtrl.text); await prefs.setString('droneCamUrl', droneCamUrlCtrl.text);
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
      if (isCameraVisible && !isExternalIpCamMode && !isUsbCamMode && !isDroneCamMode && (controller == null || !controller!.value.isInitialized)) { _initCamera(); }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newsTimer?.cancel(); _adCycleTimer?.cancel(); _tickerColorTimer?.cancel(); _motionController.dispose();
    controller?.dispose(); _bulletinVideoController?.removeListener(_videoListener); _bulletinVideoController?.dispose(); _bottomAdVideoController?.dispose();
    _leftAdVideoCtrl?.dispose(); _rightAdVideoCtrl?.dispose(); _bottomAdVideoCtrlForAds?.dispose();
    _ipCamController?.dispose(); _droneCamController?.dispose();
    super.dispose();
  }

  void _videoListener() {
    final vController = _bulletinVideoController;
    if (vController == null || !vController.value.isInitialized) return;
    if (vController.value.position >= vController.value.duration && vController.value.duration != Duration.zero) {
      vController.removeListener(_videoListener); setState(() { isNewsBulletinMode = false; });
    }
  }

  Future<void> _fetchBreakingNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final items = XmlDocument.parse(response.body).findAllElements('item');
        List<String> titles = items.take(20).map((e) => e.findElements('title').first.innerText.replaceAll(RegExp(r'^[0-9]+[smh]\s*Trend:\s*', caseSensitive: false), '')).toList();
        if (titles.isNotEmpty && mounted) setState(() => breakingNewsText = titles.join("   ♦   "));
      }
    } catch (e) {}
  }

  Future<void> _requestPermissions() async { await [Permission.camera, Permission.microphone, Permission.storage, Permission.photos, Permission.videos].request(); }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;
    try {
      if (controller != null) await controller!.dispose();
      final camController = CameraController(cameras[currentCameraIndex], ResolutionPreset.high, enableAudio: false);
      controller = camController;
      await camController.initialize();
      if (!mounted) return;
      _minZoomLevel = await camController.getMinZoomLevel(); _maxZoomLevel = await camController.getMaxZoomLevel(); _currentZoomLevel = _minZoomLevel;
      setState(() => _isCameraInitialized = true);
    } catch (e) {}
  }

  void _switchCamera() async {
    if (isExternalIpCamMode || isUsbCamMode || isDroneCamMode) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("External కెమెరా మోడ్‌లో ఫోన్ కెమెరా స్విచ్ పనిచేయదు."))); return; }
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    if (isCameraVisible) await _initCamera();
    setState(() => isMenuOpen = false);
  }

  void _toggleCameraVisibility() async {
    setState(() => isMenuOpen = false);
    if (isExternalIpCamMode || isUsbCamMode || isDroneCamMode) {
      setState(() { isExternalIpCamMode = false; isUsbCamMode = false; isDroneCamMode = false; isCameraVisible = false; _usbTextureId = null; });
      _ipCamController?.dispose(); _ipCamController = null; _droneCamController?.dispose(); _droneCamController = null;
      try { await StreamServiceManager.stopUsbCamera(); } catch (_) {}
      return;
    }
    if (isCameraVisible) {
      setState(() => isCameraVisible = false); await controller?.dispose(); controller = null; setState(() => _isCameraInitialized = false);
    } else {
      setState(() => isCameraVisible = true); await _initCamera();
    }
  }

  void _toggleAdMode() {
    setState(() {
      adDisplayMode = (adDisplayMode + 1) % 3; isMenuOpen = false; _adCycleTimer?.cancel();
      if (adDisplayMode == 0) { isAdCurrentlyShowing = false; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ads OFF"))); } 
      else if (adDisplayMode == 1) { isAdCurrentlyShowing = true; _startPermanentCycle(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ads ON"))); } 
      else if (adDisplayMode == 2) { isAdCurrentlyShowing = true; _startAutoCycle(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Auto Timer Ads"))); }
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
      _adCycleTimer = Timer(const Duration(seconds: 20), () { if (mounted && adDisplayMode == 2) { setState(() => isAdCurrentlyShowing = false); _startAutoCycle(); } });
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

  void _toggleAdShapeMode() async { setState(() { adShapeMode = (adShapeMode + 1) % 3; isMenuOpen = false; }); await _saveTextSettings(); }
  void _toggleLBandDirection() { setState(() { isLBandRight = !isLBandRight; isMenuOpen = false; }); }
  void _changeLogoPosition() async { setState(() { logoPosition = (logoPosition + 1) % 4; isMenuOpen = false; }); await _saveTextSettings(); }

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
    if (pos == 'left') currentPaths = leftAdPaths; if (pos == 'right') currentPaths = rightAdPaths; if (pos == 'bottom') currentPaths = bottomAdPaths;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900], title: Text("Manage ${pos.toUpperCase()} Ads", style: const TextStyle(color: Colors.white, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: currentPaths.isEmpty ? const Text("No ads.", style: TextStyle(color: Colors.white54)) : ListView.builder(
                  shrinkWrap: true, itemCount: currentPaths.length,
                  itemBuilder: (ctx, idx) {
                    bool isVideo = currentPaths[idx].toLowerCase().endsWith('.mp4');
                    return ListTile(
                      leading: isVideo ? const Icon(Icons.video_file, color: Colors.blueAccent, size: 40) : Image.file(File(currentPaths[idx]), width: 50, height: 50, fit: BoxFit.cover),
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
              actions: [ TextButton(child: const Text("Close", style: TextStyle(color: Colors.white)), onPressed: () => Navigator.pop(ctx)) ],
            );
          },
        );
      },
    );
  }

  void _showExternalCamsDialog() {
    setState(() => isMenuOpen = false);
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.grey[900], title: const Text("External Cameras Setup", style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ipCamUrlCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "IP Cam URL")),
          ElevatedButton(onPressed: () async { await _saveLinks(); Navigator.pop(context); _startIpCamera(ipCamUrlCtrl.text.trim()); }, child: const Text("Connect IP Cam")),
          TextField(controller: droneCamUrlCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "Drone RTMP/RTSP URL")),
          ElevatedButton(onPressed: () async { await _saveLinks(); Navigator.pop(context); _startDroneCamera(droneCamUrlCtrl.text.trim()); }, child: const Text("Connect Drone")),
          ElevatedButton(onPressed: () { Navigator.pop(context); _startUsbCamera(); }, child: const Text("Start USB Camera")),
        ]),
      );
    });
  }

  void _showEditDialog() {
    setState(() => isMenuOpen = false);
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.grey[900], title: const Text("Settings", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(onPressed: () async {
            final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
            if (image != null) { setState(() => channelLogoPath = image.path); SharedPreferences.getInstance().then((prefs) => prefs.setString('channelLogoPath', image.path)); }
          }, child: const Text("Upload Logo")),
          TextField(controller: mainHeadlineCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "Main Headline")),
          TextField(controller: subHeadlineCtrl, style: const TextStyle(color: Colors.cyanAccent), decoration: const InputDecoration(labelText: "Sub Headline")),
          TextField(controller: manualTickerCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Manual Ticker")),
          ElevatedButton(onPressed: () async { if (manualTickerCtrl.text.trim().isNotEmpty) { setState(() => breakingNewsText = manualTickerCtrl.text.trim()); await _saveTextSettings(); } }, child: const Text("Update Ticker")),
          TextField(controller: watermarkCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "Watermark")),
          TextField(controller: locCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "Location")),
          TextField(controller: nameCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "Reporter Name")),
          TextField(controller: roleCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "Role")),
        ])),
        actions: [ ElevatedButton(onPressed: () async { setState(() { splitScreenMainHeadline = mainHeadlineCtrl.text; splitScreenSubHeadline = subHeadlineCtrl.text; watermarkText = watermarkCtrl.text; locationText = locCtrl.text; reporterName = nameCtrl.text; reporterRole = roleCtrl.text; }); await _saveTextSettings(); Navigator.pop(context); }, child: const Text("Save & Close")) ],
      );
    });
  }

  void _showMultiStreamDialog() {
    setState(() => isMenuOpen = false);
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.grey[900], title: const Text("YouTube/RTMP Link Setup", style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: youtubeUrlController, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "YouTube RTMP Link")),
          ElevatedButton(onPressed: () async { await _saveLinks(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"))); }, child: const Text("Save RTMP")),
          TextField(controller: youtubeVideoUrlCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "YouTube Video URL for Player")),
          ElevatedButton(onPressed: () { Navigator.pop(context); _startNetworkBulletin(youtubeVideoUrlCtrl.text.trim()); }, child: const Text("Play Video")),
        ]),
        actions: [ ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Close")) ],
      );
    });
  }

  Future<void> _startNetworkBulletin(String url) async {
    if (url.isEmpty) return;
    String finalPlayUrl = url;
    if (url.contains("youtube.com") || url.contains("youtu.be")) {
      try {
        var ytExplode = yt.YoutubeExplode(); String? videoId; 
        try { videoId = yt.VideoId.parseVideoId(url); } catch (_) {}
        if (videoId == null) { 
          RegExp regExp = RegExp(r'(?:v=|/v/|embed/|youtu\.be/|/live/)([a-zA-Z0-9_-]{11})', caseSensitive: false); 
          Match? match = regExp.firstMatch(url); 
          if (match != null && match.groupCount >= 1) videoId = match.group(1); 
        }
        if (videoId != null) {
          var video = await ytExplode.videos.get(yt.VideoId(videoId));
          if (video.isLive) { finalPlayUrl = await ytExplode.videos.streamsClient.getHttpLiveStreamUrl(video.id); } 
          else { var manifest = await ytExplode.videos.streamsClient.getManifest(video.id); finalPlayUrl = manifest.muxed.withHighestBitrate().url.toString(); }
        }
        ytExplode.close();
      } catch (e) { return; }
    }
    _bulletinVideoController?.removeListener(_videoListener); _bulletinVideoController?.dispose();
    _bulletinVideoController = VideoPlayerController.networkUrl(Uri.parse(finalPlayUrl))..initialize().then((_) { 
      if (!mounted) return; 
      setState(() { isNewsBulletinMode = true; isDualScreenMode = false; hideControls = true; }); 
      _bulletinVideoController?.play(); _bulletinVideoController?.addListener(_videoListener); 
    });
  }

  void _toggleRotation() {
    setState(() {
      isMenuOpen = false; isLandscape = !isLandscape;
      if (isLandscape) SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
      else SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    });
  }

  Future<void> _startLiveAndLock() async {
    String fullRtmpUrl = youtubeUrlController.text.trim();
    if (fullRtmpUrl.isEmpty || !fullRtmpUrl.contains("rtmp")) { _showMultiStreamDialog(); return; }
    var micStatus = await Permission.microphone.status; if (!micStatus.isGranted) await Permission.microphone.request();
    bool success = await StreamServiceManager.startLiveStream(fullRtmpUrl);
    if (success) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
      setState(() { isLiveBroadcasting = true; isLivePaused = false; isLiveLocked = true; hideControls = true; isMenuOpen = false; isLandscape = true; });
    }
  }

  Future<void> _stopLiveStream() async {
    bool success = await StreamServiceManager.stopLiveStream();
    if (success) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      setState(() { isLiveBroadcasting = false; isLiveLocked = false; isLivePaused = false; });
    }
  }

  Future<void> _toggleDualScreenAndPickMedia() async {
    setState(() => isMenuOpen = false);
    if (isDualScreenMode) { setState(() { isDualScreenMode = false; dualMediaList.clear(); _bottomAdVideoController?.dispose(); _bottomAdVideoController = null; }); return; }
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
      _bottomAdVideoController = VideoPlayerController.file(File(path))..initialize().then((_) { if (mounted) { _bottomAdVideoController!.setLooping(true); _bottomAdVideoController!.play(); setState(() {}); } });
    } else { _bottomAdVideoController?.dispose(); _bottomAdVideoController = null; setState(() {}); }
  }

  Widget _buildMainDisplay(bool isScreenLandscape, double screenWidth, double screenHeight, Widget phoneCameraWidget) {
    Widget actualCameraWidget;
    if (isLivePaused) actualCameraWidget = Container(color: Colors.black, child: const Center(child: Text("LIVE PAUSED", style: TextStyle(color: Colors.redAccent, fontSize: 30))));
    else if (isDroneCamMode && _droneCamController != null && _droneCamController!.value.isInitialized) actualCameraWidget = SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _droneCamController!.value.size.width, height: _droneCamController!.value.size.height, child: VideoPlayer(_droneCamController!))));
    else if (isExternalIpCamMode && _ipCamController != null && _ipCamController!.value.isInitialized) actualCameraWidget = SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _ipCamController!.value.size.width, height: _ipCamController!.value.size.height, child: VideoPlayer(_ipCamController!))));
    else if (isUsbCamMode && _usbTextureId != null) actualCameraWidget = SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: 1920, height: 1080, child: Texture(textureId: _usbTextureId!))));
    else actualCameraWidget = phoneCameraWidget;

    if (isDualScreenMode && dualMediaList.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.all(6.0), decoration: BoxDecoration(border: Border.all(color: Colors.amberAccent, width: 3.5)),
        child: isScreenLandscape ? Row(children: [ Expanded(child: actualCameraWidget), Container(width: 3, color: Colors.amberAccent), Expanded(child: Column(children: [ Expanded(child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bottomAdVideoController!.value.size.width, height: _bottomAdVideoController!.value.size.height, child: VideoPlayer(_bottomAdVideoController!))) : Image.file(File(dualMediaList[currentDualMediaIndex]), fit: BoxFit.cover, width: double.infinity, height: double.infinity)), Container(width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.amber, child: Text(splitScreenMainHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))), Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 4), color: Colors.blueAccent, child: Text(splitScreenSubHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))) ])) ]) : Column(children: [ Expanded(flex: 4, child: actualCameraWidget), Container(width: double.infinity, padding: const EdgeInsets.all(10), color: Colors.amber, child: Text(splitScreenMainHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))), Expanded(flex: 4, child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bottomAdVideoController!.value.size.width, height: _bottomAdVideoController!.value.size.height, child: VideoPlayer(_bottomAdVideoController!))) : Image.file(File(dualMediaList[currentDualMediaIndex]), fit: BoxFit.cover, width: double.infinity, height: double.infinity)) ])
      );
    }

    bool showAds = isNewsBulletinMode || isAdCurrentlyShowing;
    double vW = screenWidth, vH = screenHeight, vLeft = 0, lAdW = 0, rAdW = 0, bAdH = 0;
    if (showAds) {
      if (adShapeMode == 0) { double adW = screenWidth * 0.20; vW = screenWidth - adW; vH = vW * (9 / 16); bAdH = screenHeight - vH; if (isLBandRight) { rAdW = adW; } else { lAdW = adW; vLeft = adW; } }
      else if (adShapeMode == 1) { lAdW = screenWidth * 0.18; rAdW = screenWidth * 0.18; vW = screenWidth - lAdW - rAdW; vLeft = lAdW; }
      else { lAdW = screenWidth * 0.15; rAdW = screenWidth * 0.15; vW = screenWidth - lAdW - rAdW; vH = vW * (9 / 16); bAdH = screenHeight - vH; vLeft = lAdW; }
    }

    Widget mainPlayer = isNewsBulletinMode && _bulletinVideoController != null && _bulletinVideoController!.value.isInitialized ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bulletinVideoController!.value.size.width, height: _bulletinVideoController!.value.size.height, child: VideoPlayer(_bulletinVideoController!)))) : actualCameraWidget;

    return Stack(
      children: [
        AnimatedPositioned(duration: const Duration(milliseconds: 600), left: showAds ? vLeft : 0, top: 0, width: showAds ? vW : screenWidth, height: showAds ? vH : screenHeight, child: mainPlayer),
        if (showAds && lAdW > 0) Positioned(left: 0, top: 0, width: lAdW, height: screenHeight, child: leftAdPaths.isNotEmpty ? (_leftAdVideoCtrl != null && _leftAdVideoCtrl!.value.isInitialized ? VideoPlayer(_leftAdVideoCtrl!) : Image.file(File(leftAdPaths[leftAdIndex]), fit: BoxFit.fill)) : Container(color: Colors.black)),
        if (showAds && rAdW > 0) Positioned(right: 0, top: 0, width: rAdW, height: screenHeight, child: rightAdPaths.isNotEmpty ? (_rightAdVideoCtrl != null && _rightAdVideoCtrl!.value.isInitialized ? VideoPlayer(_rightAdVideoCtrl!) : Image.file(File(rightAdPaths[rightAdIndex]), fit: BoxFit.fill)) : Container(color: Colors.black)),
        if (showAds && bAdH > 0) Positioned(left: vLeft, top: vH, width: vW, height: bAdH, child: bottomAdPaths.isNotEmpty ? (_bottomAdVideoCtrlForAds != null && _bottomAdVideoCtrlForAds!.value.isInitialized ? VideoPlayer(_bottomAdVideoCtrlForAds!) : Image.file(File(bottomAdPaths[bottomAdIndex]), fit: BoxFit.fill)) : Container(color: Colors.black)),
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isScreenLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    Widget phoneCameraWidget = (!isCameraVisible) ? Container(color: Colors.transparent) : (_isCameraInitialized && controller != null && controller!.value.isInitialized) ? ClipRect(child: SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: controller!.value.previewSize!.height, height: controller!.value.previewSize!.width, child: CameraPreview(controller!))))) : const Center(child: CircularProgressIndicator(color: Colors.amber));
    final List<Color> bgColors = [const Color(0xFF0D47A1), Colors.red.shade900, Colors.purple.shade900, Colors.teal.shade900];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onDoubleTap: () { if (!isLiveLocked) setState(() => hideControls = false); },
          onTap: () { if (!isLiveLocked) setState(() { isMenuOpen = false; hideControls = true; }); },
          onLongPress: () { if (isLiveLocked) { setState(() { isLiveLocked = false; hideControls = false; }); } },
          child: LayoutBuilder(
            builder: (context, constraints) {
              double screenW = constraints.maxWidth, screenH = constraints.maxHeight, tickerH = 55.0, topAreaH = screenH - tickerH;
              return Stack(
                children: [
                  Positioned(top: 0, left: 0, right: 0, height: topAreaH, child: _buildMainDisplay(isScreenLandscape, screenW, topAreaH, phoneCameraWidget)),
                  if (channelLogoPath.isNotEmpty) Positioned(top: (logoPosition == 0 || logoPosition == 1) ? 15.0 : null, bottom: (logoPosition == 2 || logoPosition == 3) ? 65.0 : null, left: (logoPosition == 0 || logoPosition == 2) ? 15.0 : null, right: (logoPosition == 1 || logoPosition == 3) ? 15.0 : null, child: SizedBox(width: 70, height: 70, child: Image.file(File(channelLogoPath), fit: BoxFit.contain))),
                  if (!isDualScreenMode && !isAdCurrentlyShowing && !isNewsBulletinMode) Positioned(bottom: 65, left: 15.0, child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1.04).animate(CurvedAnimation(parent: _motionController, curve: Curves.easeInOut)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Container(color: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text(watermarkText, style: const TextStyle(color: Colors.white, fontSize: 11.0))), Container(color: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(locationText, style: const TextStyle(color: Colors.white, fontSize: 11.0))), const SizedBox(height: 2), Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13.0))), Container(color: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontSize: 11.0))) ]))),
                  Positioned(bottom: 0, left: 0, right: 0, height: tickerH, child: AnimatedContainer(duration: const Duration(seconds: 2), decoration: BoxDecoration(color: bgColors[_tickerBgColorIndex % bgColors.length], border: Border.all(color: Colors.amber.shade400, width: 1.5)), child: Row(children: [ Container(width: 95, color: Colors.red.shade900, alignment: Alignment.center, child: const Text("BREAKING\nNEWS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))), Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 45.0))) ]))),
                  
                  if (!hideControls && !isLiveLocked) Positioned(top: 15, right: 15, child: Row(children: [ GestureDetector(onTap: () { if (youtubeUrlController.text.isEmpty) _showMultiStreamDialog(); else _startLiveAndLock(); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: isLiveBroadcasting ? Colors.red : Colors.green, borderRadius: BorderRadius.circular(8)), child: Row(children: [ Icon(isLiveBroadcasting ? Icons.sensors : Icons.podcasts, color: Colors.white, size: 16), const SizedBox(width: 6), Text(isLiveBroadcasting ? "ON AIR" : "Go Live", style: const TextStyle(color: Colors.white)) ]))), const SizedBox(width: 8), if (isLiveBroadcasting) ...[ GestureDetector(onTap: () async { if (isLivePaused) { await StreamServiceManager.startLiveStream(youtubeUrlController.text); setState(() => isLivePaused = false); } else { await StreamServiceManager.pauseLiveStream(); setState(() => isLivePaused = true); } }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)), child: Text(isLivePaused ? "Resume" : "Pause", style: const TextStyle(color: Colors.white)))), const SizedBox(width: 8), GestureDetector(onTap: _stopLiveStream, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: const Text("Close", style: TextStyle(color: Colors.white)))), const SizedBox(width: 8) ], GestureDetector(onTap: () => setState(() => isMenuOpen = !isMenuOpen), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(8)), child: const Text("Menu", style: TextStyle(color: Colors.white)))) ])),
                  
                  if (!hideControls && isMenuOpen && !isLiveLocked) Positioned.fill(child: Container(color: Colors.black87, child: Center(child: Wrap(alignment: WrapAlignment.center, spacing: 25, runSpacing: 25, children: [
                    _buildControlButton(Icons.flip_camera_android, "Phone Cam", _switchCamera, Colors.white),
                    _buildControlButton(isCameraVisible ? Icons.videocam_off : Icons.videocam, isCameraVisible ? "Cam OFF" : "Cam ON", _toggleCameraVisibility, isCameraVisible ? Colors.redAccent : Colors.greenAccent),
                    _buildControlButton(Icons.video_call, "Ext. Cams", _showExternalCamsDialog, Colors.tealAccent),
                    _buildControlButton(Icons.dashboard_customize, "PCR Board", () { setState(() => isMenuOpen = false); Navigator.push(context, MaterialPageRoute(builder: (context) => const MasterPCRBoard())); }, Colors.amberAccent),
                    _buildControlButton(Icons.link, "Set Links", _showMultiStreamDialog, Colors.redAccent),
                    _buildControlButton(Icons.grid_on, "Dual Screen", _toggleDualScreenAndPickMedia, Colors.orangeAccent),
                    _buildControlButton(Icons.settings, "Settings", _showEditDialog, Colors.blue),
                    _buildControlButton(Icons.visibility, adDisplayMode == 0 ? "Ads OFF" : "Ads ON", _toggleAdMode, adDisplayMode == 0 ? Colors.redAccent : Colors.blueAccent),
                    _buildControlButton(Icons.dashboard, adShapeMode == 0 ? "L-Band" : "U-Band", _toggleAdShapeMode, Colors.orange),
                    _buildControlButton(Icons.picture_in_picture_alt, "Logo Pos", _changeLogoPosition, Colors.lightGreenAccent),
                    if (adShapeMode == 0) _buildControlButton(Icons.swap_horiz, "L-Band L/R", _toggleLBandDirection, Colors.orange),
                    _buildControlButton(Icons.screen_rotation, "Rotate", _toggleRotation, Colors.purple),
                    _buildControlButton(Icons.bar_chart, "Election Results", () { setState(() => isMenuOpen = false); Navigator.push(context, MaterialPageRoute(builder: (context) => const ElectionBoardScreen())); }, Colors.indigoAccent),
                  ]))))
                ]
              );
            }
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, VoidCallback onTap, Color iconColor) {
    return GestureDetector(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [ CircleAvatar(radius: 26, backgroundColor: Colors.white30, child: Icon(icon, color: iconColor, size: 26)), const SizedBox(height: 6), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)) ]));
  }
}
