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

class _StudioScreenState extends State<StudioScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  
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
  bool isLBandRight = true; 
  int logoPosition = 1; 

  String verticalAnimatedAdPath = "";
  String horizontalAnimatedAdPath = ""; 

  bool isNewsBulletinMode = false;
  bool isBulletinMuted = false;
  
  // యాప్ ఓపెన్ చేయగానే కెమెరా డిఫాల్ట్ గా ఆఫ్ (OFF) లో ఉంటుంది
  bool isCameraVisible = false; 
  
  double pipTop = 60.0;
  double pipLeft = 0.0;
  bool isPipPositionInitialized = false;

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  double _baseScale = 1.0;

  final ImagePicker _picker = ImagePicker();

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
  String splitScreenSubHeadline = "వార్తా అప్‌‌డేట్";

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

  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _bgAnimationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

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

    _requestPermissions();
    _fetchBreakingNews();

    // గమనిక: ఇక్కడ ఉన్న _initCamera() ని తీసేశాను, కాబట్టి యాప్ ఓపెన్ చేయగానే కెమెరా స్టార్ట్ అవ్వదు.

    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) { 
      _fetchBreakingNews(); 
    });
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
    _bgAnimationController.dispose();
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
    await [Permission.camera, Permission.microphone, Permission.storage, Permission.photos, Permission.videos].request();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;
    try {
      if (controller != null) { await controller!.dispose(); }
      final camController = CameraController(cameras[currentCameraIndex], ResolutionPreset.high, enableAudio: false);
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
    if (isCameraVisible) {
      await _initCamera();
    }
    setState(() { isMenuOpen = false; });
  }

  // కెమెరా ఆన్/ఆఫ్ పక్కాగా పనిచేసే లాజిక్ (బ్యాక్ గ్రౌండ్ లో కూడా క్లోజ్ అవుతుంది)
  void _toggleCameraVisibility() async {
    setState(() { isMenuOpen = false; }); // మెనూ క్లోజ్ అవ్వడానికి
    if (isCameraVisible) {
      // కెమెరా ఆపినప్పుడు హార్డ్‌వేర్ పూర్తిగా క్లోజ్ అవుతుంది
      setState(() { isCameraVisible = false; });
      await controller?.dispose();
      controller = null;
      setState(() { _isCameraInitialized = false; });
    } else {
      // కెమెరా ఆన్ చేసినప్పుడు మాత్రమే స్టార్ట్ అవుతుంది
      setState(() { isCameraVisible = true; });
      await _initCamera();
    }
  }

  Future<void> _startNetworkBulletin(String url) async {
    if (url.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("యూట్యూబ్ లింక్ ప్రాసెస్ అవుతోంది..."), backgroundColor: Colors.orange),
    );

    String finalPlayUrl = url;

    if (url.contains("youtube.com") || url.contains("youtu.be")) {
      try {
        var ytExplode = yt.YoutubeExplode();
        String? videoId;

        try {
          videoId = yt.VideoId.parseVideoId(url);
        } catch (_) {}

        if (videoId == null) {
          RegExp regExp = RegExp(
            r'(?:v=|/v/|embed/|youtu\.be/|/live/)([a-zA-Z0-9_-]{11})',
            caseSensitive: false,
          );
          Match? match = regExp.firstMatch(url);
          if (match != null && match.groupCount >= 1) {
            videoId = match.group(1);
          }
        }

        if (videoId == null) {
          ytExplode.close();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("తప్పు యూట్యూబ్ లింక్ లేదా ప్లే చేయడం సాధ్యం కాలేదు."), backgroundColor: Colors.red),
          );
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
        debugPrint("YouTube Extraction Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ఈ లింక్‌ను ప్లే చేయలేము. వేరొకటి ప్రయత్నించండి."), backgroundColor: Colors.red),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("వీడియో ప్లే అవుతోంది..."), backgroundColor: Colors.green),
    );

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("వీడియో ప్లే అవ్వడం లేదు."), backgroundColor: Colors.red),
        );
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
    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("Live Control Room", style: TextStyle(color: Colors.white, fontSize: 15)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildLinkEditor("1. YouTube/Restream RTMP Key", youtubeUrlController, setDialogState),
            const Divider(color: Colors.white24, height: 20),
            _buildLinkEditor("2. YouTube Video Link (ఇక్కడ లింక్ ఇవ్వండి)", youtubeVideoUrlCtrl, setDialogState, onPlay: () { 
              Navigator.pop(context); _startNetworkBulletin(youtubeVideoUrlCtrl.text.trim()); 
            }),
            const Divider(color: Colors.white24, height: 20),
            _buildLinkEditor("3. Direct Network Video (MP4)", networkVideoUrlCtrl, setDialogState, onPlay: () { 
              Navigator.pop(context); _startNetworkBulletin(networkVideoUrlCtrl.text.trim()); 
            }),
          ])),
          actions: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
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
        Expanded(child: TextField(controller: controller, style: const TextStyle(color: Colors.yellow, fontSize: 12), decoration: const InputDecoration(hintText: "Paste link here...", hintStyle: TextStyle(color: Colors.white30), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))))),
        IconButton(icon: const Icon(Icons.save, color: Colors.blueAccent, size: 22), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"))); }),
        if (onPlay != null) IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 28), onPressed: onPlay)
      ])
    ]);
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
                  if (image != null) { setState(() { channelLogoPath = image.path; }); setDialogState(() {}); }
                } catch (e) {}
              }, 
              icon: const Icon(Icons.upload), label: const Text("ఛానల్ లోగో అప్లోడ్")
            ),
            const Divider(color: Colors.white24, height: 20),
            TextField(controller: mainHeadlineCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "మెయిన్ హెడ్‌లైన్ (Yellow Box)")),
            TextField(controller: subHeadlineCtrl, style: const TextStyle(color: Colors.cyanAccent), decoration: const InputDecoration(labelText: "సబ్ హెడ్‌‌‌‌లైన్ (Blue Box)")),
            const Divider(color: Colors.white24, height: 20),
            TextField(controller: manualTickerCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "మాన్యువల్ బ్రేకింగ్ టిక్కర్ న్యూస్")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), 
              onPressed: () {
                if (manualTickerCtrl.text.trim().isNotEmpty) { 
                  setState(() { breakingNewsText = manualTickerCtrl.text.trim(); }); manualTickerCtrl.clear(); setDialogState(() {}); 
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
                  splitScreenMainHeadline = mainHeadlineCtrl.text; splitScreenSubHeadline = subHeadlineCtrl.text; watermarkText = watermarkCtrl.text; locationText = locCtrl.text; reporterName = nameCtrl.text; reporterRole = roleCtrl.text; 
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
      isMenuOpen = false; isLandscape = !isLandscape;
      if (isLandscape) { SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]); } 
      else { SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); }
    });
  }

  Future<void> _startLiveAndLock() async {
    String fullRtmpUrl = youtubeUrlController.text.trim();
    if (fullRtmpUrl.isEmpty || !fullRtmpUrl.contains("rtmp")) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("దయచేసి సరైన YouTube RTMP/Stream Key లింక్ ఇవ్వండి."), backgroundColor: Colors.red)); 
      return; 
    }

    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఆడియో కోసం Microphone పర్మిషన్ తప్పనిసరి!"), backgroundColor: Colors.red));
      return;
    }

    try {
      bool success = await StreamServiceManager.startLiveStream(fullRtmpUrl);
      if (success) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
        setState(() { isLiveBroadcasting = true; isLivePaused = false; isLiveLocked = true; hideControls = true; isMenuOpen = false; isLandscape = true; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("YouTube Live ప్రారంభమైంది!"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ కనెక్ట్ అవ్వలేదు."), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ఎర్రర్: $e"), backgroundColor: Colors.red));
    }
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
      _bottomAdVideoController = VideoPlayerController.file(File(path))..initialize().then((_) { 
        if (mounted) { 
          _bottomAdVideoController!.setLooping(true); 
          _bottomAdVideoController!.setVolume(1.0); 
          _bottomAdVideoController!.play(); 
          setState(() {}); 
        } 
      });
    } else {
      _bottomAdVideoController?.dispose(); _bottomAdVideoController = null; setState(() {});
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

  void _toggleAutoTimerAds() { setState(() { isAnimatedAdsMode = !isAnimatedAdsMode; isMenuOpen = false; }); }
  void _toggleLBandDirection() { setState(() { isLBandRight = !isLBandRight; isMenuOpen = false; }); }

  Future<void> _pickVerticalAd() async { 
    try { 
      final XFile? media = await _picker.pickMedia(); 
      if (media != null && mounted) {
        setState(() { verticalAnimatedAdPath = media.path; }); 
        if (media.path.toLowerCase().endsWith('.mp4') || media.path.toLowerCase().endsWith('.mov')) {
          _verticalAdController?.dispose();
          _verticalAdController = VideoPlayerController.file(File(media.path))..initialize().then((_) { if(mounted){ _verticalAdController!.setLooping(true); _verticalAdController!.setVolume(0.0); _verticalAdController!.play(); setState((){}); }});
        } else { _verticalAdController?.dispose(); _verticalAdController = null; }
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
          _horizontalAdController = VideoPlayerController.file(File(media.path))..initialize().then((_) { if(mounted){ _horizontalAdController!.setLooping(true); _horizontalAdController!.setVolume(0.0); _horizontalAdController!.play(); setState((){}); }});
        } else { _horizontalAdController?.dispose(); _horizontalAdController = null; }
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

  Widget _buildMainDisplay(bool isScreenLandscape, double screenWidth, double screenHeight, Widget cameraWidget) {
    // వాస్తవ కెమెరా విడ్జెట్ ఇక్కడ సెట్ చేయబడింది 
    Widget actualCameraWidget = isLivePaused 
        ? Container(color: Colors.black, child: const Center(child: Text("LIVE PAUSED", style: TextStyle(color: Colors.redAccent, fontSize: 30, fontWeight: FontWeight.bold)))) 
        : cameraWidget;

    // యానిమేటెడ్ బ్యాక్‌గ్రౌండ్ (వీడియో వెనుక వస్తుంది)
    Widget animatedBackground = AnimatedBuilder(
      animation: _bgAnimationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(Colors.indigo.shade900, Colors.purple.shade900, _bgAnimationController.value)!,
                Color.lerp(Colors.blue.shade800, Colors.deepOrange.shade900, _bgAnimationController.value)!,
                Color.lerp(Colors.black, Colors.indigo.shade900, _bgAnimationController.value)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        );
      },
    );

    if (isDualScreenMode && dualMediaList.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.all(6.0), 
        decoration: BoxDecoration(
          color: Colors.black, 
          border: Border.all(color: Colors.amberAccent, width: 3.5),
          boxShadow: const [BoxShadow(color: Colors.redAccent, blurRadius: 10)],
        ),
        child: isScreenLandscape 
          ? Row(children: [ 
              Expanded(child: actualCameraWidget), 
              Container(width: 3, color: Colors.amberAccent), 
              Expanded(child: Column(children: [
                Expanded(child: LayoutBuilder(builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      double dx = details.localPosition.dx;
                      if (dx < constraints.maxWidth / 3) _prevDualMedia(); else if (dx > constraints.maxWidth * 2 / 3) _nextDualMedia(); else _toggleDualMediaPause();
                    },
                    child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bottomAdVideoController!.value.size.width, height: _bottomAdVideoController!.value.size.height, child: VideoPlayer(_bottomAdVideoController!))) : Image.file(File(dualMediaList[currentDualMediaIndex]), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  );
                })),
                Container(width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.amber, child: Text(splitScreenMainHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold))),
                Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 4), color: Colors.blueAccent, child: Text(splitScreenSubHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
              ])) 
            ])
          : Column(children: [ 
              Expanded(flex: 4, child: actualCameraWidget), 
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15), color: Colors.amber, child: Text(splitScreenMainHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold))),
              Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 5), color: Colors.blueAccent, child: Text(splitScreenSubHeadline, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
              Expanded(flex: 4, child: LayoutBuilder(builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    double dx = details.localPosition.dx;
                    if (dx < constraints.maxWidth / 3) _prevDualMedia(); else if (dx > constraints.maxWidth * 2 / 3) _nextDualMedia(); else _toggleDualMediaPause();
                  },
                  child: _bottomAdVideoController != null && _bottomAdVideoController!.value.isInitialized ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _bottomAdVideoController!.value.size.width, height: _bottomAdVideoController!.value.size.height, child: VideoPlayer(_bottomAdVideoController!))) : Image.file(File(dualMediaList[currentDualMediaIndex]), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                );
              })) 
            ])
      );
    }

    if (isNewsBulletinMode) {
      double pipWidth = isScreenLandscape ? screenWidth * 0.28 : screenWidth * 0.38;
      double pipHeight = pipWidth * (screenHeight / screenWidth); 
      if (!isPipPositionInitialized) { pipLeft = 15.0; pipTop = 60.0; isPipPositionInitialized = true; }

      Widget mainPlayer = (_bulletinVideoController != null && _bulletinVideoController!.value.isInitialized) 
          ? VideoPlayer(_bulletinVideoController!) 
          : const Center(child: CircularProgressIndicator(color: Colors.amber));

      Widget baseWidget = Stack(
        children: [
          Positioned.fill(child: animatedBackground), // నలుపు రంగుకు బదులుగా యానిమేటెడ్ కలర్స్
          Positioned.fill(child: Center(child: AspectRatio(aspectRatio: _bulletinVideoController?.value.aspectRatio ?? 16/9, child: mainPlayer))),
          if (isCameraVisible)
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
      );

      if (!isAnimatedAdsMode) return baseWidget;

      double vertAdWidth = screenWidth * 0.28; 
      double horizAdHeight = screenHeight * 0.20; 
      return Stack(children: [
        Positioned.fill(child: animatedBackground),
        Positioned(
          left: isLBandRight ? 0 : vertAdWidth, 
          top: 0, 
          right: isLBandRight ? vertAdWidth : 0, 
          bottom: horizAdHeight + 55, 
          child: baseWidget
        ), 
        // వర్టికల్ యాడ్ - ఫిట్ గా ఉంటుంది
        Positioned(
          left: isLBandRight ? null : 0, right: isLBandRight ? 0 : null, top: 0, bottom: 55, width: vertAdWidth, 
          child: GestureDetector(onTap: _pickVerticalAd, child: Container(color: const Color(0xFF0D47A1), child: verticalAnimatedAdPath.isNotEmpty ? (_verticalAdController != null && _verticalAdController!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _verticalAdController!.value.size.width, height: _verticalAdController!.value.size.height, child: VideoPlayer(_verticalAdController!))) : SizedBox.expand(child: Image.file(File(verticalAnimatedAdPath), fit: BoxFit.fill))) : const Center(child: Text("VERTICAL\nBANNER", style: TextStyle(color: Colors.white)))))
        ),
        // హారిజాంటల్ యాడ్ - ఫిట్ గా ఉంటుంది
        Positioned(
          left: isLBandRight ? 0 : vertAdWidth, right: isLBandRight ? vertAdWidth : 0, bottom: 55, height: horizAdHeight, 
          child: GestureDetector(onTap: _pickHorizontalAd, child: Container(color: const Color(0xFF0D47A1), child: horizontalAnimatedAdPath.isNotEmpty ? (_horizontalAdController != null && _horizontalAdController!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _horizontalAdController!.value.size.width, height: _horizontalAdController!.value.size.height, child: VideoPlayer(_horizontalAdController!))) : SizedBox.expand(child: Image.file(File(horizontalAnimatedAdPath), fit: BoxFit.fill))) : const Center(child: Text("HORIZONTAL BANNER", style: TextStyle(color: Colors.white)))))
        ),
      ]);
    }

    if (isAnimatedAdsMode) {
      double vertAdWidth = screenWidth * 0.28; 
      double horizAdHeight = screenHeight * 0.20; 
      return Stack(children: [
        Positioned.fill(child: animatedBackground),
        Positioned(
          left: isLBandRight ? 0 : vertAdWidth, top: 0, right: isLBandRight ? vertAdWidth : 0, bottom: horizAdHeight + 55, 
          child: actualCameraWidget
        ), 
        // వర్టికల్ యాడ్ - ఫిట్ గా ఉంటుంది
        Positioned(
          left: isLBandRight ? null : 0, right: isLBandRight ? 0 : null, top: 0, bottom: 55, width: vertAdWidth, 
          child: GestureDetector(onTap: _pickVerticalAd, child: Container(color: const Color(0xFF0D47A1), child: verticalAnimatedAdPath.isNotEmpty ? (_verticalAdController != null && _verticalAdController!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _verticalAdController!.value.size.width, height: _verticalAdController!.value.size.height, child: VideoPlayer(_verticalAdController!))) : SizedBox.expand(child: Image.file(File(verticalAnimatedAdPath), fit: BoxFit.fill))) : const Center(child: Text("VERTICAL\nBANNER", style: TextStyle(color: Colors.white)))))
        ),
        // హారిజాంటల్ యాడ్ - ఫిట్ గా ఉంటుంది
        Positioned(
          left: isLBandRight ? 0 : vertAdWidth, right: isLBandRight ? vertAdWidth : 0, bottom: 55, height: horizAdHeight, 
          child: GestureDetector(onTap: _pickHorizontalAd, child: Container(color: const Color(0xFF0D47A1), child: horizontalAnimatedAdPath.isNotEmpty ? (_horizontalAdController != null && _horizontalAdController!.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: _horizontalAdController!.value.size.width, height: _horizontalAdController!.value.size.height, child: VideoPlayer(_horizontalAdController!))) : SizedBox.expand(child: Image.file(File(horizontalAnimatedAdPath), fit: BoxFit.fill))) : const Center(child: Text("HORIZONTAL BANNER", style: TextStyle(color: Colors.white)))))
        ),
      ]);
    }

    return Positioned.fill(child: actualCameraWidget);
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
        camW = previewSize.width; camH = previewSize.height; 
        if (camW < camH) { double temp = camW; camW = camH; camH = temp; } 
      }
    }
    double finalCamW = isScreenLandscape ? camW : camH; double finalCamH = isScreenLandscape ? camH : camW;

    // కెమెరా విడ్జెట్ కండిషన్ 
    Widget cameraWidget;
    if (!isCameraVisible) {
      cameraWidget = Container(color: Colors.transparent);
    } else if (_isCameraInitialized && controller != null && controller!.value.isInitialized) {
      cameraWidget = GestureDetector(
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
      );
    } else {
      cameraWidget = const Center(child: CircularProgressIndicator(color: Colors.amber));
    }

    Widget reporterBadgeWidget = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (watermarkText.isNotEmpty) Container(color: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text(watermarkText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
      Container(color: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
      const SizedBox(height: 2),
      Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13.0))),
      Container(color: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
    ]);

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
          onTap: () { if (!isLiveLocked) setState(() { isMenuOpen ? isMenuOpen = false : hideControls = !hideControls; }); },
          onLongPress: () { if (isLiveLocked) { setState(() { isLiveLocked = false; hideControls = false; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("స్క్రీన్ అన్‌లాక్ చేయబడింది."))); } },
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _bgAnimationController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.lerp(Colors.indigo.shade900, Colors.purple.shade900, _bgAnimationController.value)!,
                            Color.lerp(Colors.blue.shade800, Colors.deepOrange.shade900, _bgAnimationController.value)!,
                            Color.lerp(Colors.black, Colors.indigo.shade900, _bgAnimationController.value)!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    );
                  },
                ),
              ),

              Positioned.fill(child: _buildMainDisplay(isScreenLandscape, screenWidth, screenHeight, cameraWidget)),
              
              Positioned(
                top: (logoPosition == 0 || logoPosition == 1) ? 15.0 : null,
                bottom: (logoPosition == 2 || logoPosition == 3) ? 70.0 : null,
                left: (logoPosition == 0 || logoPosition == 3) ? 15.0 : null,
                right: (logoPosition == 1 || logoPosition == 2) ? 15.0 : null,
                child: visualScreenLogoWidget
              ),

              if (!isDualScreenMode && !isAnimatedAdsMode && !isNewsBulletinMode)
                Positioned(bottom: 65, left: 15, child: reporterBadgeWidget),

              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 55, 
                  decoration: BoxDecoration(color: Colors.red.shade900, border: Border.all(color: Colors.amber.shade400, width: 1.5)),
                  child: Row(children: [
                    Container(width: 95, color: Colors.red.shade900, alignment: Alignment.center, child: const Text("BREAKING\nNEWS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
                    Expanded(child: Container(color: const Color(0xFF0D47A1), padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 45.0)))
                  ]),
                ),
              ),

              if (!hideControls && !isLiveLocked)
                Positioned(bottom: 75, right: 20, child: FloatingActionButton(backgroundColor: Colors.blueAccent, onPressed: () { setState(() { isMenuOpen = !isMenuOpen; }); }, child: Icon(isMenuOpen ? Icons.close : Icons.menu, color: Colors.white))),

              if (!hideControls && isMenuOpen && !isLiveLocked)
                Positioned.fill(
                  child: Container(
                    color: Colors.black87,
                    child: Center(
                      child: Wrap(alignment: WrapAlignment.center, spacing: 25, runSpacing: 25, children: [
                          _buildControlButton(Icons.flip_camera_android, "Phone Cam", _switchCamera, Colors.white),
                          _buildControlButton(isCameraVisible ? Icons.videocam_off : Icons.videocam, isCameraVisible ? "Cam OFF" : "Cam ON", _toggleCameraVisibility, isCameraVisible ? Colors.redAccent : Colors.greenAccent),
                          _buildControlButton(Icons.grid_on, "1. Dual Screen", _toggleDualScreenAndPickMedia, Colors.orangeAccent),
                          _buildControlButton(Icons.live_tv, "2. Multi-Live Cntrl", _showMultiStreamDialog, Colors.redAccent),
                          if (isLiveBroadcasting) _buildControlButton(Icons.stop, "Stop Live", _stopLiveStream, Colors.red),
                          _buildControlButton(Icons.settings, "Settings & Text", _showEditDialog, Colors.blue),
                          _buildControlButton(Icons.timer, "L-Band Timer", _toggleAutoTimerAds, Colors.amber),
                          _buildControlButton(Icons.swap_horiz, "L-Band L/R", _toggleLBandDirection, Colors.pinkAccent),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 26, backgroundColor: Colors.white30, child: Icon(icon, color: iconColor, size: 26)), const SizedBox(height: 6), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12))])
    );
  }
}

class StreamServiceManager {
  static const platform = MethodChannel('com.ssyatratv.pocket_pcr/stream');
  
  static Future<bool> startLiveStream(String rtmpUrl) async {
    try {
      String safeUrl = rtmpUrl.replaceFirst('rtmps://', 'rtmp://');
      await platform.invokeMethod('startScreenStream', {
        'rtmpUrl': safeUrl,
        'recordAudio': true 
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
