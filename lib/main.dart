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
import 'package:shared_preferences/shared_preferences.dart'; // కొత్తగా యాడ్ చేసిన ఆటో-సేవ్ ప్యాకేజీ

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
  bool isAnimatedAdsMode = false; 
  bool isLBandRight = true; 
  int logoPosition = 1; 

  bool isNewsBulletinMode = false;
  bool isBulletinMuted = false;
  bool isCameraVisible = false; // డిఫాల్ట్ గా కెమెరా ఆఫ్ 
  
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

  // --- సింపుల్ L-Band Ad Control Variables ---
  String leftAdPath = "";
  String bottomAdPath = "";

  VideoPlayerController? _leftAdVideoCtrl;
  VideoPlayerController? _bottomAdVideoCtrlForAds; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // డీఫాల్ట్ టెక్స్ట్‌లు అసైన్ చేయడం
    watermarkCtrl.text = watermarkText;
    locCtrl.text = locationText;
    nameCtrl.text = reporterName;
    roleCtrl.text = reporterRole;
    mainHeadlineCtrl.text = splitScreenMainHeadline;
    subHeadlineCtrl.text = splitScreenSubHeadline;
    youtubeUrlController.text = "rtmp://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY_HERE";

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, 
      DeviceOrientation.landscapeLeft, 
      DeviceOrientation.landscapeRight
    ]);

    _loadSavedData(); // యాప్ ఓపెన్ అవ్వగానే పాత డేటా అంతా లోడ్ అవుతుంది
    _requestPermissions();
    _fetchBreakingNews();

    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) { 
      _fetchBreakingNews(); 
    });
  }

  // --- యాప్ లో సేవ్ అయిన పాత డేటా లోడ్ చేసే ఫంక్షన్ ---
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

      String savedLeftAd = prefs.getString('leftAdPath') ?? "";
      if (savedLeftAd.isNotEmpty && File(savedLeftAd).existsSync()) {
        leftAdPath = savedLeftAd;
        _initSavedAdVideo('left', leftAdPath);
      }

      String savedBottomAd = prefs.getString('bottomAdPath') ?? "";
      if (savedBottomAd.isNotEmpty && File(savedBottomAd).existsSync()) {
        bottomAdPath = savedBottomAd;
        _initSavedAdVideo('bottom', bottomAdPath);
      }
    });
  }

  void _initSavedAdVideo(String pos, String path) {
    bool isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov');
    if (isVideo) {
      VideoPlayerController ctrl = VideoPlayerController.file(File(path));
      ctrl.initialize().then((_) {
        if(mounted) {
          ctrl.setLooping(true);
          ctrl.setVolume(0.0);
          ctrl.play();
          setState(() {
            if (pos == 'left') _leftAdVideoCtrl = ctrl;
            if (pos == 'bottom') _bottomAdVideoCtrlForAds = ctrl;
          });
        }
      });
    }
  }

  // --- టెక్స్ట్ డేటా సేవ్ చేసే ఫంక్షన్స్ ---
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (isCameraVisible && (controller == null || !controller!.value.isInitialized)) { 
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
    
    _leftAdVideoCtrl?.dispose();
    _bottomAdVideoCtrlForAds?.dispose();

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

  Future<void> _startNetworkBulletin(String url) async {
    if (url.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("యూట్యూబ్ లింక్ ప్రాసెస్ అవుతోంది..."), backgroundColor: Colors.orange)
    );

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఈ లింక్‌ను ప్లే చేయలేము."), backgroundColor: Colors.red));
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

  void _videoListener() {
    final vController = _bulletinVideoController;
    if (vController == null || !vController.value.isInitialized) return;
    if (vController.value.position >= vController.value.duration && vController.value.duration != Duration.zero) {
      vController.removeListener(_videoListener);
      setState(() { isNewsBulletinMode = false; });
    }
  }

  void _toggleMute() {
    HapticFeedback.mediumImpact();
    setState(() {
      isBulletinMuted = !isBulletinMuted;
      if (isNewsBulletinMode && _bulletinVideoController != null) {
        _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
      }
    });
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
                mainAxisSize: MainAxisSize.min, 
                children: [
                  _buildLinkEditor("1. YouTube/Restream RTMP Key", youtubeUrlController, setDialogState),
                  const Divider(color: Colors.white24, height: 20),
                  _buildLinkEditor("2. YouTube Video Link (ఇక్కడ లింక్ ఇవ్వండి)", youtubeVideoUrlCtrl, setDialogState, onPlay: () { Navigator.pop(context); _startNetworkBulletin(youtubeVideoUrlCtrl.text.trim()); }),
                  const Divider(color: Colors.white24, height: 20),
                  _buildLinkEditor("3. Direct Network Video (MP4)", networkVideoUrlCtrl, setDialogState, onPlay: () { Navigator.pop(context); _startNetworkBulletin(networkVideoUrlCtrl.text.trim()); }),
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
              await _saveLinks(); // లింక్ టైప్ చేశాక సేవ్ అవుతుంది
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"))); 
            }),
            if (onPlay != null) IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 28), onPressed: onPlay)
          ]
        )
      ]
    );
  }

  // --- Ads అప్‌లోడ్ & ఆటో-సేవ్ లాజిక్ ---
  Future<void> _pickLeftAd() async { 
    try { 
      final XFile? media = await _picker.pickMedia(); 
      if (media != null && mounted) {
        setState(() { leftAdPath = media.path; }); 
        
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('leftAdPath', media.path);

        bool isVideo = media.path.toLowerCase().endsWith('.mp4') || media.path.toLowerCase().endsWith('.mov');
        if (isVideo) {
          _leftAdVideoCtrl?.dispose();
          _leftAdVideoCtrl = VideoPlayerController.file(File(media.path))
            ..initialize().then((_) { 
              if(mounted) { _leftAdVideoCtrl!.setLooping(true); _leftAdVideoCtrl!.setVolume(0.0); _leftAdVideoCtrl!.play(); setState((){}); }
            });
        } else {
          _leftAdVideoCtrl?.dispose(); _leftAdVideoCtrl = null;
        }
      } 
    } catch (e) {} 
  }

  Future<void> _pickBottomAd() async { 
    try { 
      final XFile? media = await _picker.pickMedia(); 
      if (media != null && mounted) {
        setState(() { bottomAdPath = media.path; }); 

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('bottomAdPath', media.path);

        bool isVideo = media.path.toLowerCase().endsWith('.mp4') || media.path.toLowerCase().endsWith('.mov');
        if (isVideo) {
          _bottomAdVideoCtrlForAds?.dispose();
          _bottomAdVideoCtrlForAds = VideoPlayerController.file(File(media.path))
            ..initialize().then((_) { 
              if(mounted) { _bottomAdVideoCtrlForAds!.setLooping(true); _bottomAdVideoCtrlForAds!.setVolume(0.0); _bottomAdVideoCtrlForAds!.play(); setState((){}); }
            });
        } else {
          _bottomAdVideoCtrlForAds?.dispose(); _bottomAdVideoCtrlForAds = null;
        }
      } 
    } catch (e) {} 
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
                  TextField(controller: mainHeadlineCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "మెయిన్ హెడ్‌లైన్ (Yellow Box)")),
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
                  await _saveTextSettings(); // టెక్స్ట్ అంతా సేవ్ అవుతుంది
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
        setState(() { isDualScreenMode = true; isNewsBulletinMode = false; });
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

  void _toggleAutoTimerAds() { 
    setState(() { isAnimatedAdsMode = !isAnimatedAdsMode; isMenuOpen = false; }); 
  }

  void _toggleLBandDirection() { 
    setState(() { isLBandRight = !isLBandRight; isMenuOpen = false; }); 
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

  Widget _buildMainDisplay(bool isScreenLandscape, double screenWidth, double screenHeight, Widget cameraWidget) {
    Widget actualCameraWidget = isLivePaused 
        ? Container(color: Colors.black, child: const Center(child: Text("LIVE PAUSED", style: TextStyle(color: Colors.redAccent, fontSize: 30, fontWeight: FontWeight.bold)))) 
        : cameraWidget;

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
    
    // లెఫ్ట్ యాడ్ వెడల్పు 20%
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

    if (isNewsBulletinMode || isAnimatedAdsMode) {
      
      double pipWidth = isScreenLandscape ? screenWidth * 0.28 : screenWidth * 0.38;
      double pipHeight = pipWidth * (screenHeight / screenWidth); 
      if (!isPipPositionInitialized) { pipLeft = 15.0; pipTop = 60.0; isPipPositionInitialized = true; }

      Widget mainPlayer = isNewsBulletinMode && (_bulletinVideoController != null && _bulletinVideoController!.value.isInitialized) 
          ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bulletinVideoController!.value.size.width, height: _bulletinVideoController!.value.size.height, child: VideoPlayer(_bulletinVideoController!))))
          : actualCameraWidget;

      return Container(
        color: Colors.black, 
        child: Stack(
          children: [
            // 1. మెయిన్ వీడియో (16:9)
            Positioned(
              left: isLBandRight ? 0 : leftAdWidth,
              top: 0,
              width: videoWidth,
              height: videoHeight,
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
                          width: pipWidth, height: pipHeight,
                          decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2.0), boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 8)]),
                          child: actualCameraWidget, 
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // 2. Left Ad 
            Positioned(
              left: isLBandRight ? videoWidth : 0,
              top: 0,
              width: leftAdWidth,
              height: availableHeight,
              child: GestureDetector(
                onTap: leftAdPath.isEmpty ? _pickLeftAd : null,
                onDoubleTap: leftAdPath.isNotEmpty ? _pickLeftAd : null,
                child: Container(
                  color: Colors.black, 
                  child: leftAdPath.isNotEmpty 
                      ? (_leftAdVideoCtrl != null && _leftAdVideoCtrl!.value.isInitialized 
                          ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _leftAdVideoCtrl!.value.size.width, height: _leftAdVideoCtrl!.value.size.height, child: VideoPlayer(_leftAdVideoCtrl!)))
                          : SizedBox.expand(child: Image.file(File(leftAdPath), fit: BoxFit.fill)))
                      : const Center(
                          child: Text("LEFT AD\n(Tap to Upload)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
                        )
                )
              ),
            ),

            // 3. Bottom Ad 
            Positioned(
              left: isLBandRight ? 0 : leftAdWidth,
              top: videoHeight,
              width: videoWidth, 
              height: bottomAdHeight,
              child: GestureDetector(
                onTap: bottomAdPath.isEmpty ? _pickBottomAd : null,
                onDoubleTap: bottomAdPath.isNotEmpty ? _pickBottomAd : null,
                child: Container(
                  color: Colors.black, 
                  child: bottomAdPath.isNotEmpty 
                      ? (_bottomAdVideoCtrlForAds != null && _bottomAdVideoCtrlForAds!.value.isInitialized 
                          ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _bottomAdVideoCtrlForAds!.value.size.width, height: _bottomAdVideoCtrlForAds!.value.size.height, child: VideoPlayer(_bottomAdVideoCtrlForAds!)))
                          : SizedBox.expand(child: Image.file(File(bottomAdPath), fit: BoxFit.fill)))
                      : const Center(
                          child: Text("BOTTOM AD\n(Tap to Upload)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
                        )
                )
              ),
            ),
          ],
        ),
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

    Widget cameraWidget = (!isCameraVisible) 
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
              double tickerH = 55.0; // స్క్రోలింగ్ వార్తల ఎత్తు
              double topAreaH = screenH - tickerH; 

              return Stack(
                children: [
                  Positioned(
                    top: 0, left: 0, right: 0, height: topAreaH,
                    child: _buildMainDisplay(isScreenLandscape, screenW, topAreaH, cameraWidget)
                  ),
                  
                  Positioned(
                    top: (logoPosition == 0 || logoPosition == 1) ? 15.0 : null,
                    bottom: (logoPosition == 2 || logoPosition == 3) ? 70.0 : null,
                    left: (logoPosition == 0 || logoPosition == 3) ? 15.0 : null,
                    right: (logoPosition == 1 || logoPosition == 2) ? 15.0 : null,
                    child: visualScreenLogoWidget
                  ),

                  if (!isDualScreenMode && !isAnimatedAdsMode && !isNewsBulletinMode)
                    Positioned(bottom: 65, left: 15, child: reporterBadgeWidget),

                  // ఇది కింది స్క్రోలింగ్ న్యూస్ బాక్స్ (దీని వెనుకకి ఇకపై ఏదీ వెళ్లదు)
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
                              _buildControlButton(Icons.grid_on, "Dual Screen", _toggleDualScreenAndPickMedia, Colors.orangeAccent),
                              _buildControlButton(Icons.live_tv, "Multi-Live", _showMultiStreamDialog, Colors.redAccent),
                              if (isLiveBroadcasting) _buildControlButton(Icons.stop, "Stop Live", _stopLiveStream, Colors.red),
                              _buildControlButton(Icons.settings, "Settings", _showEditDialog, Colors.blue),
                              _buildControlButton(Icons.visibility, "Toggle Ads", _toggleAutoTimerAds, Colors.pinkAccent),
                              _buildControlButton(Icons.swap_horiz, "L-Band L/R", _toggleLBandDirection, Colors.orange),
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
}
