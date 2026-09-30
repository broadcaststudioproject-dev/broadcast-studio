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
  
  VideoPlayerController? _verticalAdController;
  VideoPlayerController? _horizontalAdController;

  bool isLiveLocked = false;
  bool hideControls = false;
  bool isMenuOpen = false;

  int currentCameraIndex = 0;
  bool isLandscape = false;
  bool isLiveBroadcasting = false;
  bool isLivePaused = false;
  
  bool isDualScreenMode = false;
  bool isAnimatedAdsMode = false; 
  String verticalAnimatedAdPath = "";
  String horizontalAnimatedAdPath = ""; 

  bool isNewsBulletinMode = false;
  bool isBulletinMuted = true;
  bool isCameraVisible = false;
  double pipTop = 60.0;
  double pipLeft = 0.0;
  bool isPipPositionInitialized = false;

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  double _baseScale = 1.0;

  final ImagePicker _picker = ImagePicker();

  Color adLayerColor = const Color(0xFF111111);
  String breakingNewsLogoPath = ""; 
  String channelLogoPath = "";
  double logoWidth = 70.0;
  double logoHeight = 70.0;

  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA";
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String breakingNewsText = "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";

  String splitScreenMainHeadline = "రైతు పొలంలో కలకలం.. గట్లపై భారీ పులి అడుగుల గుర్తులు!";
  String splitScreenSubHeadline = "వార్తా అప్‌డేట్";

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

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, 
      DeviceOrientation.landscapeLeft, 
      DeviceOrientation.landscapeRight
    ]);

    _initCamera();
    _requestPermissions();
    _fetchBreakingNews();

    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) { 
      _fetchBreakingNews(); 
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (controller == null || !controller!.value.isInitialized) { 
        _initCamera(); 
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newsTimer?.cancel();
    controller?.dispose();
    _bulletinVideoController?.removeListener(_videoListener);
    _bulletinVideoController?.dispose();
    _bottomAdVideoController?.dispose();
    _verticalAdController?.dispose();
    _horizontalAdController?.dispose();
    youtubeUrlController.dispose();
    networkVideoUrlCtrl.dispose();
    youtubeVideoUrlCtrl.dispose();
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
        controller = null; 
      }
      final camController = CameraController(
        cameras[currentCameraIndex], 
        ResolutionPreset.high, 
        enableAudio: false, 
        imageFormatGroup: ImageFormatGroup.jpeg
      );
      controller = camController;
      await camController.initialize();
      if (!mounted) return;
      _minZoomLevel = await camController.getMinZoomLevel();
      _maxZoomLevel = await camController.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      setState(() { _isCameraInitialized = true; });
    } catch (e) { }
  }

  void _switchCamera() async {
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    await _initCamera();
    setState(() { isMenuOpen = false; });
  }

  void _toggleMute() {
    HapticFeedback.mediumImpact();
    setState(() {
      isBulletinMuted = !isBulletinMuted;
      _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0); 
    });
  }

  // --- యూట్యూబ్ వీడియో ప్లే చేసే ఫంక్షన్ ---
  Future<void> _startNetworkBulletin(String url) async {
    if (url.isEmpty) return;

    String finalPlayUrl = url;
    
    if (url.contains("youtube.com") || url.contains("youtu.be")) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("యూట్యూబ్ వీడియో లోడ్ అవుతోంది... దయచేసి వేచి ఉండండి."), backgroundColor: Colors.orange));
        var ytExplode = yt.YoutubeExplode();
        
        String? extractedId = yt.VideoId.parseVideoId(url);
        if (extractedId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లింక్ ఫార్మాట్ తప్పుగా ఉంది. సరియైన యూట్యూబ్ లింక్ ఇవ్వండి."), backgroundColor: Colors.red));
          return;
        }

        var video = await ytExplode.videos.get(yt.VideoId(extractedId));
        
        if (video.isLive) {
          finalPlayUrl = await ytExplode.videos.streamsClient.getHttpLiveStreamUrl(video.id);
        } else {
          var manifest = await ytExplode.videos.streamsClient.getManifest(video.id);
          if (manifest.muxed.isNotEmpty) {
            finalPlayUrl = manifest.muxed.withHighestBitrate().url.toString();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఈ యూట్యూబ్ వీడియో ఇక్కడ ప్లే చేయడానికి అనుమతి లేదు."), backgroundColor: Colors.red));
            ytExplode.close();
            return;
          }
        }
        ytExplode.close();
      } catch (e) {
        debugPrint("YouTube Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఈ లింక్ కాపీరైట్ లేదా ప్రైవసీ వల్ల బ్లాక్ చేయబడింది. వేరొక పబ్లిక్ లింక్ ఇవ్వండి."), backgroundColor: Colors.red));
        return;
      }
    }

    _bulletinVideoController?.removeListener(_videoListener);
    _bulletinVideoController?.dispose();
    
    // MP4/Stream లింక్‌ను ప్లేయర్‌కి పంపడం
    _bulletinVideoController = VideoPlayerController.networkUrl(Uri.parse(finalPlayUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
        setState(() {
          isNewsBulletinMode = true; // వీడియో మోడ్ ఆన్ చేయబడుతుంది
          isDualScreenMode = false; 
          hideControls = true;
          isCameraVisible = false;
        });
        _bulletinVideoController?.play();
        _bulletinVideoController?.setLooping(false);
        _bulletinVideoController?.addListener(_videoListener);
      }).catchError((e) {
        debugPrint("Video Player Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("వీడియో ప్లే అవ్వడం లేదు. వేరొక లింక్ ప్రయత్నించండి."), backgroundColor: Colors.red));
      });
  }

  void _videoListener() {
    final vController = _bulletinVideoController;
    if (vController == null || !vController.value.isInitialized) return;
    if (vController.value.position >= vController.value.duration && vController.value.duration != Duration.zero) {
      vController.removeListener(_videoListener);
      setState(() { isNewsBulletinMode = false; });
    }
  }

  // --- లైవ్ బ్రాడ్ కాస్టింగ్ కంట్రోల్స్ ---
  Future<void> _startLiveAndLock() async {
    String fullRtmpUrl = youtubeUrlController.text.trim();
    if (fullRtmpUrl.isEmpty) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("సరైన RTMP లింక్ ఇవ్వండి."), backgroundColor: Colors.blueAccent)); 
      return; 
    }
    try {
      bool success = await StreamServiceManager.startLiveStream(fullRtmpUrl);
      if (success) {
        HapticFeedback.heavyImpact();
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
        setState(() { 
          isLiveBroadcasting = true; 
          isLivePaused = false; 
          isLiveLocked = true; 
          hideControls = true; 
          isMenuOpen = false; 
          isLandscape = true; 
        });
      }
    } catch (e) {}
  }

  Future<void> _stopLiveStream() async {
    try {
      bool success = await StreamServiceManager.stopLiveStream();
      if (success) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
        setState(() { 
          isLiveBroadcasting = false; 
          isLiveLocked = false; 
          isLivePaused = false; 
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ ఆపబడింది."), backgroundColor: Colors.green));
      }
    } catch (e) {}
  }

  Future<void> _pickBreakingNewsLogo() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (image != null && mounted) { 
        setState(() { breakingNewsLogoPath = image.path; }); 
      }
    } catch (e) { }
  }

  // --- స్ప్లిట్ స్క్రీన్ (Tap Left/Right టు చేంజ్) ---
  Future<void> _toggleDualScreenAndPickMedia() async {
    setState(() { isMenuOpen = false; });
    
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
            _bottomAdVideoController!.setVolume(0.0);
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
    HapticFeedback.lightImpact();
    currentDualMediaIndex = (currentDualMediaIndex - 1) < 0 ? dualMediaList.length - 1 : currentDualMediaIndex - 1;
    _playDualMedia(dualMediaList[currentDualMediaIndex]);
  }

  void _nextDualMedia() {
    if (dualMediaList.isEmpty) return;
    HapticFeedback.lightImpact();
    currentDualMediaIndex = (currentDualMediaIndex + 1) % dualMediaList.length;
    _playDualMedia(dualMediaList[currentDualMediaIndex]);
  }

  void _toggleDualMediaPause() {
    HapticFeedback.mediumImpact();
    if (_bottomAdVideoController != null) {
      _bottomAdVideoController!.value.isPlaying ? _bottomAdVideoController!.pause() : _bottomAdVideoController!.play();
      setState(() {});
    }
  }

  // --- L-Band Ads (Auto Timer) లాజిక్ ---
  void _toggleAutoTimerAds() { 
    setState(() { 
      isAnimatedAdsMode = !isAnimatedAdsMode; 
      isMenuOpen = false; 
    }); 
  }
  
  Future<void> _pickVerticalAd() async { 
    try { 
      final XFile? media = await _picker.pickMedia(); 
      if (media != null && mounted) {
        setState(() { verticalAnimatedAdPath = media.path; }); 
        if (media.path.toLowerCase().endsWith('.mp4') || media.path.toLowerCase().endsWith('.mov')) {
          _verticalAdController?.dispose();
          _verticalAdController = VideoPlayerController.file(File(media.path))
            ..initialize().then((_) { 
              if(mounted){ 
                _verticalAdController!.setLooping(true);
                _verticalAdController!.setVolume(0.0);
                _verticalAdController!.play();
                setState((){}); 
              }
            });
        } else {
          _verticalAdController?.dispose(); 
          _verticalAdController = null;
        }
      } 
    } catch (e) {} 
  }

  Future<void> _pickHorizontalAd() async { 
    try { 
      final XFile? media = await _picker.pickMedia(); 
      if (media != null && mounted) { 
        setState(() { horizontalAnimatedAdPath = media.path; }); 
        if (media.path.toLowerCase().endsWith('.mp4') || media.path.toLowerCase().endsWith('.mov')) {
          _horizontalAdController?.dispose();
          _horizontalAdController = VideoPlayerController.file(File(media.path))
            ..initialize().then((_) { 
              if(mounted){ 
                _horizontalAdController!.setLooping(true);
                _horizontalAdController!.setVolume(0.0);
                _horizontalAdController!.play();
                setState((){}); 
              }
            });
        } else {
          _horizontalAdController?.dispose(); 
          _horizontalAdController = null;
        }
      } 
    } catch (e) {} 
  }

  // --- మల్టీ-లైవ్ విండో (యూట్యూబ్ లింక్ ఇన్పుట్) ---
  void _showMultiStreamDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("Live Control Room & Online Videos", style: TextStyle(color: Colors.white, fontSize: 15)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildLinkEditor("1. YouTube/Restream RTMP Key", youtubeUrlController, setDialogState),
            const Divider(color: Colors.white24, height: 20),
            
            // ఇక్కడ యూట్యూబ్ లింక్ ఇచ్చి ప్లే బటన్ నొక్కొచ్చు
            _buildLinkEditor("2. YouTube Video Link (ఇక్కడ లింక్ ఇవ్వండి)", youtubeVideoUrlCtrl, setDialogState, onPlay: () { 
              Navigator.pop(context); 
              _startNetworkBulletin(youtubeVideoUrlCtrl.text.trim()); // ఫంక్షన్ కాల్ అవుతుంది
            }),
          ])),
          actions: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green), 
                onPressed: () { Navigator.pop(context); _startLiveAndLock(); }, 
                child: const Text("Go Live", style: TextStyle(color: Colors.white, fontSize: 11))
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
                onPressed: () { Navigator.pop(context); _stopLiveStream(); }, 
                child: const Text("Live Close", style: TextStyle(color: Colors.white, fontSize: 11))
              ),
            ])
          ]
        );
      });
    });
  }

  Widget _buildLinkEditor(String label, TextEditingController controller, StateSetter setDialogState, {VoidCallback? onPlay}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
      Row(children: [
        Expanded(
          child: TextField(
            controller: controller, 
            style: const TextStyle(color: Colors.yellow, fontSize: 12), 
            decoration: const InputDecoration(
              hintText: "Paste link here...", 
              hintStyle: TextStyle(color: Colors.white30), 
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))
            )
          )
        ),
        IconButton(
          icon: const Icon(Icons.save, color: Colors.blueAccent, size: 22), 
          onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"))); }
        ),
        if (onPlay != null) 
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 28), 
            onPressed: onPlay // ప్లే బటన్ యాక్షన్
          )
      ])
    ]);
  }

  Future<void> _fetchBreakingNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = [];
        for (var item in items.take(20)) {
          String rawTitle = item.findElements('title').first.innerText.replaceAll(RegExp(r'^[0-9]+[smh]\s*Trend:\s*', caseSensitive: false), '');
          titles.add(rawTitle);
        }
        if (titles.isNotEmpty && mounted) { 
          setState(() { breakingNewsText = titles.join("   ♦   "); }); 
        }
      }
    } catch (e) { }
  }

  void _showEditDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: Colors.grey[900], 
          title: const Text("స్టూడియో సెట్టింగ్స్", style: TextStyle(color: Colors.white, fontSize: 13)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
                  if (image != null) { 
                    setState(() { channelLogoPath = image.path; }); 
                    setDialogState(() {}); 
                  }
                } catch (e) {}
              }, 
              icon: const Icon(Icons.upload), 
              label: const Text("ఛానల్ లోగో అప్లోడ్")
            ),
            const Divider(color: Colors.white24, height: 20),
            TextField(controller: mainHeadlineCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "మెయిన్ హెడ్‌లైన్ (Yellow Box)")),
            TextField(controller: subHeadlineCtrl, style: const TextStyle(color: Colors.cyanAccent), decoration: const InputDecoration(labelText: "సబ్ హెడ్‌లైన్ (Blue Box)")),
            const Divider(color: Colors.white24, height: 20),
            TextField(controller: manualTickerCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "మాన్యువల్ బ్రేకింగ్ టిక్కర్ న్యూస్")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), 
              onPressed: () {
                if (manualTickerCtrl.text.trim().isNotEmpty) { 
                  setState(() { breakingNewsText = manualTickerCtrl.text.trim(); }); 
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
          ])),
          actions: [
            ElevatedButton(
              onPressed: () {
                setState(() { 
                  splitScreenMainHeadline = mainHeadlineCtrl.text; 
                  splitScreenSubHeadline = subHeadlineCtrl.text; 
                  watermarkText = watermarkCtrl.text; 
                  locationText = locCtrl.text; 
                  reporterName = nameCtrl.text; 
                  reporterRole = roleCtrl.text; 
                });
                Navigator.pop(context);
              }, 
              child: const Text("Save & Close")
            )
          ]
        );
      });
    });
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

  Widget _buildMainDisplay(bool isScreenLandscape, double screenWidth, double screenHeight, Widget cameraWidget) {
    Widget actualCameraWidget = isLivePaused 
      ? Container(color: Colors.black, child: const Center(child: Text("LIVE PAUSED", style: TextStyle(color: Colors.redAccent, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 3)))) 
      : cameraWidget;

    // స్ప్లిట్ స్క్రీన్
    if (isDualScreenMode && dualMediaList.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.all(2.0), 
        decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.redAccent, width: 2.5)),
        child: isScreenLandscape 
          ? Row(children: [
              Expanded(child: actualCameraWidget),
              Container(width: 2, color: Colors.white), 
              Expanded(child: Column(children: [
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        double dx = details.localPosition.dx;
                        if (dx < constraints.maxWidth / 3) _prevDualMedia(); 
                        else if (dx > constraints.maxWidth * 2 / 3) _nextDualMedia(); 
                        else _toggleDualMediaPause(); 
                      },
                      child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized
                          ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bottomAdVideoController!.value.size.width, height: _bottomAdVideoController!.value.size.height, child: VideoPlayer(_bottomAdVideoController!)))
                          : Image.file(File(dualMediaList[currentDualMediaIndex]), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                    );
                  })
                ),
                Container(width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.amber, child: Text(splitScreenMainHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold))),
                Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 4), color: Colors.blueAccent, child: Text(splitScreenSubHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              ]))
            ])
          : Column(children: [
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
                      if (dx < constraints.maxWidth / 3) _prevDualMedia();
                      else if (dx > constraints.maxWidth * 2 / 3) _nextDualMedia();
                      else _toggleDualMediaPause();
                    },
                    child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized
                        ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bottomAdVideoController!.value.size.width, height: _bottomAdVideoController!.value.size.height, child: VideoPlayer(_bottomAdVideoController!)))
                        : Image.file(File(dualMediaList[currentDualMediaIndex]), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  );
                })
              )
            ])
      );
    }

    // YouTube / Online Video Player with Draggable Camera
    if (isNewsBulletinMode && _bulletinVideoController != null && _bulletinVideoController!.value.isInitialized) {
      double pipWidth = isScreenLandscape ? screenWidth * 0.28 : screenWidth * 0.38;
      double pipHeight = pipWidth * (screenHeight / screenWidth);
      if (!isPipPositionInitialized) { 
        pipLeft = 15.0; 
        pipTop = 60.0; 
        isPipPositionInitialized = true; 
      }

      return Stack(children: [
        Positioned.fill(
          child: Container(color: Colors.black, child: Center(child: AspectRatio(aspectRatio: _bulletinVideoController!.value.aspectRatio, child: VideoPlayer(_bulletinVideoController!)))),
        ),
          
        if (isCameraVisible) 
          Positioned(
            top: pipTop, left: pipLeft, 
            child: GestureDetector(
              onPanUpdate: (details) { 
                setState(() { pipTop += details.delta.dy; pipLeft += details.delta.dx; }); 
              }, 
              child: Container(
                width: pipWidth, height: pipHeight, 
                decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2.0), boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 8)]), 
                child: actualCameraWidget
              )
            )
          ),
          
        if (!hideControls) 
          Positioned(
            top: 20, left: 15, 
            child: Row(children: [
              GestureDetector(
                onTap: () { setState(() { isCameraVisible = !isCameraVisible; }); }, 
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(isCameraVisible ? Icons.videocam : Icons.videocam_off, color: isCameraVisible ? Colors.greenAccent : Colors.red, size: 16), const SizedBox(width: 4), Text(isCameraVisible ? "Cam On" : "Cam Off", style: const TextStyle(color: Colors.white, fontSize: 10))]))
              ),
              GestureDetector(
                onTap: _toggleMute, 
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(isBulletinMuted ? Icons.volume_off : Icons.volume_up, color: isBulletinMuted ? Colors.red : Colors.greenAccent, size: 16), const SizedBox(width: 4), Text(isBulletinMuted ? "Muted" : "Audio On", style: const TextStyle(color: Colors.white, fontSize: 10))]))
              ),
            ])
          ),
      ]);
    }

    if (isAnimatedAdsMode) {
      double vertAdWidth = screenWidth * 0.28; 
      double horizAdHeight = screenHeight * 0.20; 
      
      return Container(
        color: const Color(0xFFB71C1C), 
        child: Stack(children: [
          Positioned(
            left: 0, top: 0, right: vertAdWidth, bottom: horizAdHeight + 55,
            child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2)), child: actualCameraWidget)
          ), 
          Positioned(
            right: 0, top: 0, bottom: 55, width: vertAdWidth, 
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: _pickVerticalAd, 
              child: Container(
                decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.white, width: 2.0)), color: Color(0xFF0D47A1)), 
                child: verticalAnimatedAdPath.isNotEmpty 
                    ? (_verticalAdController != null && _verticalAdController!.value.isInitialized 
                        ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _verticalAdController!.value.size.width, height: _verticalAdController!.value.size.height, child: VideoPlayer(_verticalAdController!))) 
                        : Image.file(File(verticalAnimatedAdPath), fit: BoxFit.fill, width: double.infinity, height: double.infinity)) 
                    : const Center(child: Text("VERTICAL\nBANNER", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
              )
            )
          ),
          Positioned(
            left: 0, right: vertAdWidth, bottom: 55, height: horizAdHeight, 
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: _pickHorizontalAd, 
              child: Container(
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 2.0)), color: Color(0xFF0D47A1)), 
                child: horizontalAnimatedAdPath.isNotEmpty 
                    ? (_horizontalAdController != null && _horizontalAdController!.value.isInitialized 
                        ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _horizontalAdController!.value.size.width, height: _horizontalAdController!.value.size.height, child: VideoPlayer(_horizontalAdController!))) 
                        : Image.file(File(horizontalAnimatedAdPath), fit: BoxFit.fill, width: double.infinity, height: double.infinity)) 
                    : const Center(child: Text("HORIZONTAL BANNER / AD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
              )
            )
          ),
        ])
      );
    }

    return Stack(children: [Positioned.fill(child: actualCameraWidget)]);
  }

  @override
  Widget build(BuildContext context) {
    bool isScreenLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    double camW = 1080; double camH = 1920;
    if (_isCameraInitialized && controller != null && controller!.value.isInitialized) {
      final previewSize = controller!.value.previewSize;
      if (previewSize != null) { 
        camW = previewSize.width; 
        camH = previewSize.height; 
        if (camW < camH) { double temp = camW; camW = camH; camH = temp; } 
      }
    }
    double finalCamW = isScreenLandscape ? camW : camH; 
    double finalCamH = isScreenLandscape ? camH : camW;

    Widget cameraWidget = (_isCameraInitialized && controller != null && controller!.value.isInitialized)
        ? GestureDetector(
            onScaleStart: (details) { _baseScale = _currentZoomLevel; },
            onScaleUpdate: (details) async {
              if (controller == null || !controller!.value.isInitialized) return;
              double zoom = _baseScale * details.scale;
              if (zoom < _minZoomLevel) zoom = _minZoomLevel; 
              if (zoom > _maxZoomLevel) zoom = _maxZoomLevel;
              setState(() { _currentZoomLevel = zoom; }); 
              await controller?.setZoomLevel(zoom);
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

    Widget reporterBadgeWidget = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (watermarkText.isNotEmpty) Container(color: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text(watermarkText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
      Container(color: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
      const SizedBox(height: 2),
      Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13.0))),
      Container(color: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
    ]);

    Widget visualScreenLogoWidget = channelLogoPath.isNotEmpty
        ? SizedBox(width: logoWidth, height: logoHeight, child: Image.file(File(channelLogoPath), fit: BoxFit.contain, filterQuality: FilterQuality.high))
        : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: Colors.red[900]?.withOpacity(0.9), child: const Text("SS YATRA TV", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false, bottom: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!isLiveLocked) {
              setState(() { 
                if (isMenuOpen) {
                  isMenuOpen = false;
                } else {
                  hideControls = !hideControls; 
                }
              });
            }
          },
          onLongPress: () {
            if (isLiveLocked) { 
              HapticFeedback.heavyImpact(); 
              setState(() { isLiveLocked = false; hideControls = false; }); 
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("స్క్రీన్ అన్‌‌లాక్ చేయబడింది.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green)); 
            }
          },
          child: Stack(
            children: [
              Positioned.fill(child: _buildMainDisplay(isScreenLandscape, screenWidth, screenHeight, cameraWidget)),

              Positioned(top: 15, right: 15, child: visualScreenLogoWidget),

              if (!isDualScreenMode && !isAnimatedAdsMode && !isNewsBulletinMode)
                Positioned(bottom: 65, left: 15, child: reporterBadgeWidget),

              // ప్రొఫెషనల్ న్యూస్ టిక్కర్ 
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 55, 
                  decoration: BoxDecoration(color: Colors.red.shade900, border: Border.all(color: Colors.amber.shade400, width: 1.5)),
                  child: Row(children: [
                    Container(
                      width: 95, 
                      height: double.infinity, 
                      color: Colors.red.shade900, 
                      alignment: Alignment.center,
                      child: const Text("BREAKING\nNEWS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, height: 1.1))
                    ),
                    Expanded(
                      child: Container(
                        color: const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(horizontal: 10.0), 
                        child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 45.0)
                      )
                    )
                  ]),
                ),
              ),

              if (!hideControls && !isLiveLocked)
                Positioned(
                  bottom: 75, right: 20, 
                  child: FloatingActionButton(
                    backgroundColor: Colors.blueAccent.withOpacity(0.9), 
                    onPressed: () { setState(() { isMenuOpen = !isMenuOpen; }); }, 
                    child: Icon(isMenuOpen ? Icons.close : Icons.menu, color: Colors.white, size: 28)
                  )
                ),

              if (!hideControls && isMenuOpen && !isLiveLocked)
                Positioned.fill(
                  child: Container(
                    color: Colors.black87,
                    child: Center(
                      child: Wrap(alignment: WrapAlignment.center, spacing: 25, runSpacing: 25, children: [
                          _buildControlButton(Icons.flip_camera_android, "Phone Cam", _switchCamera, Colors.white),
                          _buildControlButton(isDualScreenMode ? Icons.grid_off : Icons.grid_on, isDualScreenMode ? "1. Dual Off" : "1. Dual Screen", _toggleDualScreenAndPickMedia, isDualScreenMode ? Colors.redAccent : Colors.orangeAccent),
                          _buildControlButton(Icons.live_tv, "2. Multi-Live Cntrl", _showMultiStreamDialog, Colors.redAccent),
                          if (isLiveBroadcasting) _buildControlButton(Icons.stop, "Stop Live", _stopLiveStream, Colors.red),
                          _buildControlButton(Icons.settings, "Settings & Text", _showEditDialog, Colors.blue),
                          _buildControlButton(isAnimatedAdsMode ? Icons.fullscreen : Icons.timer, isAnimatedAdsMode ? "Ads Active" : "Auto Timer L-Band", _toggleAutoTimerAds, isAnimatedAdsMode ? Colors.greenAccent : Colors.amber),
                          _buildControlButton(Icons.screen_rotation, "Rotate", _toggleRotation, Colors.purple),
                      ]),
                    ),
                  ),
                ),
            ],
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
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
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
      await platform.invokeMethod('startScreenStream', {'rtmpUrl': safeUrl}); 
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
