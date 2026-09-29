import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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

class NewsBulletinItem {
  String title;
  String mediaPath; 
  bool isVideo; 

  NewsBulletinItem({required this.title, required this.mediaPath, this.isVideo = true});
}

class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> with WidgetsBindingObserver {
  
  CameraController? controller;
  VlcPlayerController? _videoAdVlcController; 
  VideoPlayerController? _bulletinVideoController; 
  
  bool isLiveLocked = false;
  int _activePointers = 0;
  int _maxPointers = 0;
  DateTime? _gestureStartTime;
  Timer? _unlockTimer;
  
  bool hideControls = false;
  bool isMenuOpen = false;
  
  int currentCameraIndex = 0;
  bool isLandscape = false;
  bool isLiveBroadcasting = false;
  bool isAnimatedAdsMode = false; 
  bool isVideoAdPlaying = false; 
  
  bool isNewsBulletinMode = false;
  int currentNewsIndex = 0;
  bool isBulletinMuted = true; 

  final List<NewsBulletinItem> newsBulletinList = [
    NewsBulletinItem(title: "ప్రస్తుతం ప్లే అవుతున్న వార్త: దయచేసి వీడియో ఎంచుకోండి", mediaPath: "", isVideo: true),
  ];

  List<String> customHeadlines = [
    "రైతు పొలంలో కలకలం.. గట్లపై భారీ పులి అడుగుల గుర్తులు!",
    "తెలంగాణలో పెరుగుతున్న పొలిటికల్ హీట్.. అసెంబ్లీలో రగడ!",
    "సమగ్ర విచారణకు సీఎం రేవంత్ ఆదేశం.. ఐపీఎస్ నియామకం!"
  ];
  int _headlineIndex = 0;
  Timer? _headlineRotationTimer;

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  double _baseScale = 1.0;

  final ImagePicker _picker = ImagePicker();
  Color adLayerColor = const Color(0xFF111111);
  
  String verticalAnimatedAdPath = "";
  String horizontalAnimatedAdPath = ""; 
  String breakingNewsLogoPath = ""; 
  
  final List<String> videoAdsList = List.generate(10, (index) => "");

  String channelLogoPath = ""; 
  double logoWidth = 70.0;
  double logoHeight = 70.0;

  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA"; 
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String breakingNewsText = "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";
  
  final ValueNotifier<String> topHeadlineNotifier = ValueNotifier<String>("రైతు పొలంలో కలకలం.. గట్లపై భారీ పులి అడుగుల గుర్తులు!");

  TextEditingController youtubeUrlController = TextEditingController();
  TextEditingController watermarkCtrl = TextEditingController();
  TextEditingController locCtrl = TextEditingController();
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController roleCtrl = TextEditingController();
  TextEditingController headlineCtrl = TextEditingController();

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
    headlineCtrl.text = "";
    
    youtubeUrlController.text = "rtmp://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY_HERE";

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    
    _initCamera();
    _requestPermissions();
    _fetchBreakingNews(); 

    _headlineRotationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (customHeadlines.isNotEmpty) {
        _headlineIndex = (_headlineIndex + 1) % customHeadlines.length;
        topHeadlineNotifier.value = customHeadlines[_headlineIndex];
      }
    });

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
    _headlineRotationTimer?.cancel();
    _unlockTimer?.cancel();
    controller?.dispose();
    _videoAdVlcController?.dispose();
    _bulletinVideoController?.removeListener(_videoListener);
    _bulletinVideoController?.dispose();
    topHeadlineNotifier.dispose();
    youtubeUrlController.dispose();
    watermarkCtrl.dispose();
    locCtrl.dispose();
    nameCtrl.dispose();
    roleCtrl.dispose();
    headlineCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone, Permission.storage, Permission.photos, Permission.videos].request();
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
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      controller = camController;
      await camController.initialize();
      if (!mounted) return;
      _minZoomLevel = await camController.getMinZoomLevel();
      _maxZoomLevel = await camController.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      setState(() { _isCameraInitialized = true; }); 
    } catch (e) {
      debugPrint("Camera Init Error: $e");
    }
  }

  void _switchCamera() async {
    if (isVideoAdPlaying) return; 
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    await _initCamera();
    setState(() { isMenuOpen = false; }); 
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers++;
    if (_activePointers > _maxPointers) _maxPointers = _activePointers;
    
    if (_activePointers == 1) {
      _gestureStartTime = DateTime.now();
    }
    
    if (_activePointers == 3 && isLiveLocked) {
      HapticFeedback.selectionClick();
      _unlockTimer?.cancel();
      _unlockTimer = Timer(const Duration(seconds: 2), () {
        if (_activePointers >= 3) {
          setState(() { isLiveLocked = false; }); 
          HapticFeedback.heavyImpact(); 
        }
      });
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers--;
    if (_activePointers < 3) {
      _unlockTimer?.cancel(); 
    }
    
    if (_activePointers == 0) {
      if (_gestureStartTime != null && isLiveLocked) {
        final duration = DateTime.now().difference(_gestureStartTime!);
        if (duration.inMilliseconds < 400 && _maxPointers == 2) {
          _toggleMute();
        }
      }
      _maxPointers = 0;
      _gestureStartTime = null;
    }
    
    if (_activePointers < 0) _activePointers = 0;
  }

  void _handleSwipe(DragEndDetails details, bool isHorizontal) {
    if (!isLiveLocked) return; 
    
    if (isHorizontal) {
      if (details.primaryVelocity! > 300) {
        _changeNewsVideo(1); 
      } else if (details.primaryVelocity! < -300) {
        _changeNewsVideo(-1); 
      }
    } else {
      if (details.primaryVelocity! > 300) {
        HapticFeedback.lightImpact();
        setState(() { isNewsBulletinMode = false; _bulletinVideoController?.pause(); });
      }
    }
  }

  void _changeNewsVideo(int direction) {
    if (newsBulletinList.length <= 1) return;
    HapticFeedback.lightImpact(); 
    setState(() {
      currentNewsIndex = (currentNewsIndex + direction) % newsBulletinList.length;
      if (currentNewsIndex < 0) currentNewsIndex = newsBulletinList.length - 1;
      isNewsBulletinMode = true;
      if (newsBulletinList[currentNewsIndex].mediaPath.isNotEmpty) {
        _startBulletinMedia(newsBulletinList[currentNewsIndex].mediaPath, newsBulletinList[currentNewsIndex].isVideo);
      }
    });
  }

  void _toggleMute() {
    HapticFeedback.mediumImpact();
    setState(() {
      isBulletinMuted = !isBulletinMuted;
      _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
    });
  }

  void _startBulletinMedia(String path, bool isVideo) {
    if (path.isEmpty) return;
    if (isVideo) {
      _bulletinVideoController?.removeListener(_videoListener);
      _bulletinVideoController?.dispose();
      _bulletinVideoController = VideoPlayerController.file(File(path))
        ..initialize().then((_) {
          if (!mounted) return;
          _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
          setState(() {});
          _bulletinVideoController?.play();
          _bulletinVideoController?.setLooping(false);
          _bulletinVideoController?.addListener(_videoListener);
        });
    } else {
      _bulletinVideoController?.removeListener(_videoListener);
      _bulletinVideoController?.dispose();
      _bulletinVideoController = null;
    }
    setState(() {});
  }

  void _videoListener() {
    final vController = _bulletinVideoController;
    if (vController == null || !vController.value.isInitialized) return;
    final position = vController.value.position;
    final duration = vController.value.duration;
    if (position >= duration && duration != Duration.zero) {
      vController.removeListener(_videoListener);
      _changeNewsVideo(1);
    }
  }

  void _playVideoAd(String videoPath) {
    if (videoPath.isEmpty) return;
    _videoAdVlcController?.stopRendererScanning();
    _videoAdVlcController?.dispose();
    _videoAdVlcController = VlcPlayerController.file(
      File(videoPath),
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(advanced: VlcAdvancedOptions([VlcAdvancedOptions.networkCaching(1000)])),
    );
    setState(() { isVideoAdPlaying = true; isMenuOpen = false; });
  }

  void _stopVideoAd() {
    _videoAdVlcController?.stopRendererScanning();
    setState(() { isVideoAdPlaying = false; _videoAdVlcController = null; });
  }

  Future<void> _startLiveAndLock() async {
    String fullRtmpUrl = youtubeUrlController.text.trim();
    if (fullRtmpUrl.isEmpty || !fullRtmpUrl.startsWith("rtmp")) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("దయచేసి సరైన RTMP లింక్ ఇవ్వండి (rtmp:// দিয়ে ప్రారంభించండి)."), backgroundColor: Colors.blueAccent));
      return;
    }

    try {
      bool success = await StreamServiceManager.startLiveStream(fullRtmpUrl);
      if (success) { 
        HapticFeedback.heavyImpact();
        setState(() { 
          isLiveBroadcasting = true; 
          isLiveLocked = true; 
          hideControls = true;
          isMenuOpen = false;
        }); 
      }
    } catch (e) {
      debugPrint("Stream Error: $e");
    }
  }

  Future<void> _stopLiveStream() async {
    try {
      bool success = await StreamServiceManager.stopLiveStream();
      if (success) { setState(() { isLiveBroadcasting = false; isLiveLocked = false; }); }
    } catch (e) {
      debugPrint("Stop Stream Error: $e");
    }
  }

  Future<void> _pickBreakingNewsLogo() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (image != null && mounted) { setState(() { breakingNewsLogoPath = image.path; }); }
    } catch (e) { }
  }

  void _showBulletinManagerDialog() {
    setState(() { isMenuOpen = false; });
    TextEditingController newTitleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("ప్లేలిస్ట్ మేనేజర్ (బహుళ వీడియోలు)", style: TextStyle(color: Colors.white, fontSize: 14)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: newTitleCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "సెలక్ట్ చేసిన వీడియోల టైటిల్", labelStyle: TextStyle(color: Colors.white54))),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            final List<XFile> medias = await _picker.pickMultipleMedia();
                            if (medias.isNotEmpty) {
                              setState(() {
                                if (newsBulletinList.length == 1 && newsBulletinList[0].mediaPath.isEmpty) newsBulletinList.clear();
                                for (var media in medias) {
                                  bool isVid = media.path.toLowerCase().endsWith('.mp4') || media.path.toLowerCase().endsWith('.mov');
                                  String fTitle = newTitleCtrl.text.isNotEmpty ? newTitleCtrl.text : "వార్తా అప్‌డేట్ ${newsBulletinList.length + 1}";
                                  newsBulletinList.add(NewsBulletinItem(title: fTitle, mediaPath: media.path, isVideo: isVid));
                                }
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("వీడియోలు ప్లేలిస్ట్ లోకి వచ్చాయి. ఇప్పుడు 'START LIVE & LOCK' నొక్కండి."), backgroundColor: Colors.green));
                              });
                            }
                          } catch(e) {}
                        },
                        icon: const Icon(Icons.video_library, color: Colors.black),
                        label: const Text("గ్యాలరీ నుండి వీడియోలు జోడించు", style: TextStyle(color: Colors.black, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white)))],
            );
          },
        );
      },
    );
  }

  Future<void> _fetchBreakingNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = [];
        for (var item in items.take(20)) {
          String rawTitle = item.findElements('title').first.innerText;
          rawTitle = rawTitle.replaceAll(RegExp(r'^[0-9]+[smh]\s*Trend:\s*', caseSensitive: false), '');
          titles.add(rawTitle);
        }
        if (titles.isNotEmpty && mounted) { setState(() { breakingNewsText = titles.join("   ♦   "); }); }
      }
    } catch (e) { }
  }

  void _toggleAutoTimerAds() { setState(() { isAnimatedAdsMode = !isAnimatedAdsMode; isMenuOpen = false; }); }

  Future<void> _pickVerticalAd() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (image != null && mounted) setState(() { verticalAnimatedAdPath = image.path; });
    } catch (e) {}
  }

  Future<void> _pickHorizontalAd() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (image != null && mounted) setState(() { horizontalAnimatedAdPath = image.path; });
    } catch (e) {}
  }

  void _showAdsManagerDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("గ్యాలరీ మీడియా & వీడియో యాడ్స్ మేనేజర్", style: TextStyle(color: Colors.white, fontSize: 15)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Text("Ad ${index + 1}:", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 5),
                          Expanded(child: Text(videoAdsList[index].isEmpty ? "మీడియా లేదు" : "ఫైల్ అటాచ్ అయింది", style: const TextStyle(color: Colors.yellow, fontSize: 11), overflow: TextOverflow.ellipsis)),
                          IconButton(
                            icon: const Icon(Icons.video_library, color: Colors.cyan, size: 22),
                            onPressed: () async {
                              try {
                                final XFile? media = await _picker.pickVideo(source: ImageSource.gallery);
                                if (media != null) { setDialogState(() { videoAdsList[index] = media.path; }); setState(() { videoAdsList[index] = media.path; }); }
                              } catch(e) {}
                            },
                          ),
                          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(40, 30)), onPressed: () { Navigator.pop(context); _playVideoAd(videoAdsList[index]); }, child: const Text("Play", style: TextStyle(fontSize: 11))),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white)))],
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
        return AlertDialog(
          backgroundColor: Colors.grey[900], 
          title: const Text("Live Settings (YouTube/Restream)", style: TextStyle(color: Colors.white, fontSize: 14)), 
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                const Text("కింది బాక్సులో మీ URL మరియు Stream Key ని కలిపి ఒకే లింక్ లాగా ఇవ్వండి.\nఉదా: rtmp://a.rtmp.youtube.com/live2/xxxx-xxxx", style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                const SizedBox(height: 15),
                TextField(controller: youtubeUrlController, style: const TextStyle(color: Colors.yellow, fontSize: 12), decoration: const InputDecoration(labelText: "Full Stream URL + Key", labelStyle: TextStyle(color: Colors.white54))), 
              ]
            )
          ), 
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))), 
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ సేవ్ అయ్యింది! ఇప్పుడు 'START LIVE & LOCK' నొక్కండి."), backgroundColor: Colors.blue)); }, child: const Text("Save", style: TextStyle(color: Colors.white)))
          ]
        );
      }
    );
  }

  void _showEditDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("ఛానల్ లోగో & హెడ్‌లైన్ సెట్టింగ్స్", style: TextStyle(color: Colors.white, fontSize: 13)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
                          if (image != null) setDialogState(() { channelLogoPath = image.path; });
                        } catch(e) {}
                      },
                      icon: const Icon(Icons.upload),
                      label: const Text("ఛానల్ లోగో (JPEG/GIF) అప్లోడ్ చేయి"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: headlineCtrl,
                      style: const TextStyle(color: Colors.yellow),
                      decoration: const InputDecoration(labelText: "కొత్త బ్రేకింగ్ హెడ్‌లైన్ టైప్ చేయండి"),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          setState(() { customHeadlines.add(val.trim()); });
                          setDialogState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 5),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      onPressed: () {
                        if (headlineCtrl.text.trim().isNotEmpty) {
                          setState(() { customHeadlines.add(headlineCtrl.text.trim()); });
                          headlineCtrl.clear();
                          setDialogState(() {});
                        }
                      },
                      child: const Text("హెడ్‌లైన్ జాబితాకు జోడించు", style: TextStyle(color: Colors.black)),
                    ),
                    TextField(controller: watermarkCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "వాటర్ మార్క్")),
                    TextField(controller: locCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "లొకేషన్")),
                    TextField(controller: nameCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "రిపోర్టర్ పేరు")),
                    TextField(controller: roleCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "హోదా")),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      watermarkText = watermarkCtrl.text;
                      locationText = locCtrl.text;
                      reporterName = nameCtrl.text;
                      reporterRole = roleCtrl.text;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
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

  Widget _buildMainDisplay(bool isScreenLandscape, double screenWidth, double screenHeight, Widget cameraWidget, Widget visualScreenLogoWidget) {
    if (isVideoAdPlaying && _videoAdVlcController != null) {
      return IgnorePointer(ignoring: true, child: Container(color: Colors.black, child: VlcPlayer(controller: _videoAdVlcController!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.amber)))));
    }
    
    // PiP మోడ్ (News Video ప్లే అవుతున్నప్పుడు - ABN స్టైల్: లోగో ఎడమవైపు, PiP కుడివైపు)
    if (isNewsBulletinMode && _bulletinVideoController != null && _bulletinVideoController!.value.isInitialized) {
      double pipWidth = isScreenLandscape ? screenWidth * 0.28 : screenWidth * 0.38;
      double pipHeight = pipWidth * (screenHeight / screenWidth); 

      return Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _bulletinVideoController!.value.aspectRatio,
                  child: VideoPlayer(_bulletinVideoController!),
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 15,
            child: Container(
              width: pipWidth,
              height: pipHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber, width: 2.0),
                boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 8)],
              ),
              child: cameraWidget,
            ),
          ),
          if (!hideControls)
            Positioned(
              top: 20 + pipHeight + 5,
              right: 15,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isBulletinMuted = !isBulletinMuted;
                    _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isBulletinMuted ? Icons.volume_off : Icons.volume_up, color: isBulletinMuted ? Colors.red : Colors.greenAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(isBulletinMuted ? "Muted" : "Audio On", style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(top: 15, left: 15, child: visualScreenLogoWidget)
        ],
      );
    } 
    
    if (!isAnimatedAdsMode) {
      return Stack(children: [Positioned.fill(child: cameraWidget), Positioned(top: 15, left: 15, child: visualScreenLogoWidget)]);
    }

    double vertAdWidth = screenWidth * 0.24;  
    double horizAdHeight = screenHeight * 0.15; 

    return Container(
      color: adLayerColor,
      child: Stack(
        children: [
          Positioned.fill(child: cameraWidget), 
          Positioned(top: 15, left: 15, child: visualScreenLogoWidget),
          Positioned(
            left: 0, top: 0, bottom: 55, 
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: _pickVerticalAd, 
              child: Container(
                width: vertAdWidth, decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.amber, width: 2.0)), color: Colors.black54), 
                child: verticalAnimatedAdPath.isNotEmpty ? Image.file(File(verticalAnimatedAdPath), fit: BoxFit.fill, width: double.infinity, height: double.infinity) : const Center(child: Icon(Icons.add_photo_alternate, color: Colors.amber, size: 26)),
              ),
            ),
          ),
          Positioned(
            left: vertAdWidth, right: 0, bottom: 55, 
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: _pickHorizontalAd, 
              child: Container(
                height: horizAdHeight, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.amber, width: 2.0)), color: Colors.black54), 
                child: horizontalAnimatedAdPath.isNotEmpty ? Image.file(File(horizontalAnimatedAdPath), fit: BoxFit.fill, width: double.infinity, height: double.infinity) : const Center(child: Icon(Icons.add_photo_alternate, color: Colors.amber, size: 26)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isScreenLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    
    double camW = 1080;
    double camH = 1920;
    
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
                  child: SizedBox(width: finalCamW, height: finalCamH, child: CameraPreview(controller!)),
                ),
              ),
            ),
          )
        : const Center(child: CircularProgressIndicator(color: Colors.amber));

    Widget reporterBadgeWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (watermarkText.isNotEmpty) Container(color: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text(watermarkText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
        Container(color: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
        const SizedBox(height: 2), 
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13.0))),
        Container(color: Colors.red.shade700, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0))),
      ],
    );

    Widget visualScreenLogoWidget = channelLogoPath.isNotEmpty
          ? SizedBox(width: logoWidth, height: logoHeight, child: Image.file(File(channelLogoPath), fit: BoxFit.contain, filterQuality: FilterQuality.high))
          : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: Colors.red[900]?.withOpacity(0.9), child: const Text("SS YATRA TV", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false, bottom: true,
        child: Listener(
          onPointerDown: _handlePointerDown,
          onPointerUp: _handlePointerUp,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) => _handleSwipe(details, true),
            onVerticalDragEnd: (details) => _handleSwipe(details, false),
            onDoubleTap: () {
              if (isLiveLocked && isNewsBulletinMode && _bulletinVideoController != null) {
                _bulletinVideoController!.value.isPlaying ? _bulletinVideoController!.pause() : _bulletinVideoController!.play();
                HapticFeedback.lightImpact();
              }
            },
            onTap: () {
              if (isLiveLocked) return; 
              setState(() { isMenuOpen ? isMenuOpen = false : hideControls = !hideControls; });
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: _buildMainDisplay(isScreenLandscape, screenWidth, screenHeight, cameraWidget, visualScreenLogoWidget),
                ),

                if (isVideoAdPlaying)
                  Positioned(top: 40, right: 40, child: FloatingActionButton.extended(backgroundColor: Colors.red, onPressed: _stopVideoAd, label: const Text("Close Ad", style: TextStyle(color: Colors.white)), icon: const Icon(Icons.close, color: Colors.white))),

                Positioned(bottom: isAnimatedAdsMode ? (55 + (screenHeight * 0.15) + 10) : 65, left: isAnimatedAdsMode ? (screenWidth * 0.24 + 10) : 15, child: reporterBadgeWidget),
                
                Positioned(
                  bottom: 0, left: 0, right: 0, 
                  child: Container(
                    height: 55, decoration: BoxDecoration(color: Colors.red.shade900, border: Border.all(color: Colors.amber.shade400, width: 1.5)),
                    child: Row(children: [GestureDetector(onTap: _pickBreakingNewsLogo, child: Container(width: 55, height: double.infinity, color: Colors.black, child: breakingNewsLogoPath.isNotEmpty ? Image.file(File(breakingNewsLogoPath), fit: BoxFit.cover, width: double.infinity, height: double.infinity) : const Center(child: Icon(Icons.newspaper, color: Colors.amber, size: 28)))), Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 40.0)))]),
                  ),
                ),

                if (!hideControls && !isLiveLocked)
                  Positioned(
                    bottom: 75, right: 20,
                    child: FloatingActionButton(backgroundColor: Colors.blueAccent.withOpacity(0.9), onPressed: () { setState(() { isMenuOpen = !isMenuOpen; }); }, child: Icon(isMenuOpen ? Icons.close : Icons.menu, color: Colors.white, size: 28)),
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
                            _buildControlButton(Icons.playlist_play, "1. Playlist", _showBulletinManagerDialog, Colors.orange),
                            _buildControlButton(Icons.video_library, "2. Media Ads", _showAdsManagerDialog, Colors.amberAccent),
                            _buildControlButton(Icons.lock_outline, "3. START LIVE & LOCK", _startLiveAndLock, Colors.redAccent),
                            if (isLiveBroadcasting) _buildControlButton(Icons.stop, "Stop Live", _stopLiveStream, Colors.red),
                            _buildControlButton(Icons.live_tv, "Multi-Live URL", _showMultiStreamDialog, Colors.lightBlueAccent), // <-- మల్టీ లైవ్ బటన్ ఇక్కడ చేర్చబడింది
                            _buildControlButton(Icons.edit, "Logo & Edit", _showEditDialog, Colors.blue),
                            _buildControlButton(isAnimatedAdsMode ? Icons.fullscreen : Icons.timer, isAnimatedAdsMode ? "Ads Active" : "Auto Timer", _toggleAutoTimerAds, isAnimatedAdsMode ? Colors.greenAccent : Colors.amber),
                            _buildControlButton(Icons.screen_rotation, "Rotate", _toggleRotation, Colors.purple),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
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
      debugPrint("Error starting stream: $e");
      return false; 
    }
  }
  
  static Future<bool> stopLiveStream() async {
    try { 
      await platform.invokeMethod('stopScreenStream'); 
      return true; 
    } catch (e) { 
      debugPrint("Error stopping stream: $e");
      return false; 
    }
  }
}
