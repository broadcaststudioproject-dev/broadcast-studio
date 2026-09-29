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
import 'package:youtube_player_flutter/youtube_player_flutter.dart'; // యూట్యూబ్ ప్లేయర్ ప్లగిన్

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
  YoutubePlayerController? _ytController; // యూట్యూబ్ కంట్రోలర్
  
  bool isLiveLocked = false;
  int _activePointers = 0;
  int _maxPointers = 0;
  DateTime? _gestureStartTime;
  
  bool hideControls = false;
  bool isMenuOpen = false;
  
  int currentCameraIndex = 0;
  bool isLandscape = false;
  bool isLiveBroadcasting = false;
  bool isLivePaused = false; 
  bool isAnimatedAdsMode = false; 
  bool isVideoAdPlaying = false; 
  
  bool isNewsBulletinMode = false;
  bool isYoutubeVideo = false; // యూట్యూబ్ వీడియో ప్లే అవుతుందా లేదా అని చెక్ చేయడానికి
  int currentNewsIndex = 0;
  bool isBulletinMuted = true; 

  final List<NewsBulletinItem> newsBulletinList = [
    NewsBulletinItem(title: "దయచేసి వీడియో ఎంచుకోండి", mediaPath: "", isVideo: true),
  ];

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

  TextEditingController youtubeUrlController = TextEditingController();
  TextEditingController networkVideoUrlCtrl = TextEditingController(); 
  TextEditingController youtubeVideoUrlCtrl = TextEditingController(); 
  
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
    
    youtubeUrlController.text = "rtmp://a.rtmp.youtube.com/live2/YOUR_STREAM_KEY_HERE";

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    
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
    _videoAdVlcController?.dispose();
    _bulletinVideoController?.removeListener(_videoListener);
    _bulletinVideoController?.dispose();
    _ytController?.dispose();
    youtubeUrlController.dispose();
    networkVideoUrlCtrl.dispose();
    youtubeVideoUrlCtrl.dispose();
    watermarkCtrl.dispose();
    locCtrl.dispose();
    nameCtrl.dispose();
    roleCtrl.dispose();
    headlineCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone, Permission.storage].request();
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
    if (_activePointers == 1) _gestureStartTime = DateTime.now();
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers--;
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
      if (details.primaryVelocity! > 300) { _changeNewsVideo(1); } 
      else if (details.primaryVelocity! < -300) { _changeNewsVideo(-1); }
    } else {
      if (details.primaryVelocity! > 300) {
        HapticFeedback.lightImpact();
        setState(() { 
          isNewsBulletinMode = false; 
          _bulletinVideoController?.pause(); 
          _ytController?.pause();
        });
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
      isYoutubeVideo = false; // గ్యాలరీ వీడియోకి మారుతున్నాం కాబట్టి 
      if (newsBulletinList[currentNewsIndex].mediaPath.isNotEmpty) {
        _startBulletinMedia(newsBulletinList[currentNewsIndex].mediaPath, newsBulletinList[currentNewsIndex].isVideo);
      }
    });
  }

  void _toggleMute() {
    HapticFeedback.mediumImpact();
    setState(() {
      isBulletinMuted = !isBulletinMuted;
      if (isYoutubeVideo && _ytController != null) {
        isBulletinMuted ? _ytController!.mute() : _ytController!.unMute();
      } else {
        _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
      }
    });
  }

  void _startBulletinMedia(String path, bool isVideo) {
    if (path.isEmpty) return;
    isYoutubeVideo = false;
    _ytController?.dispose();
    _ytController = null;
    
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
  
  // ఆన్‌లైన్ లింక్స్ & యూట్యూబ్ వీడియోల కోసం పవర్ఫుల్ ప్లేయర్
  void _startNetworkBulletin(String url) {
    if (url.isEmpty) return;
    
    _bulletinVideoController?.removeListener(_videoListener);
    _bulletinVideoController?.dispose();
    _bulletinVideoController = null;
    _ytController?.dispose();
    _ytController = null;

    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      // యూట్యూబ్ లింక్ ప్లేబ్యాక్
      String? videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId != null) {
        _ytController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: YoutubePlayerFlags(
            autoPlay: true,
            mute: isBulletinMuted,
            hideControls: true, 
            loop: false,
            forceHD: true,
          ),
        )..addListener(() {
            if (_ytController?.value.playerState == PlayerState.ended) {
              _changeNewsVideo(1);
            }
        });
        setState(() {
          isYoutubeVideo = true;
          isNewsBulletinMode = true;
          hideControls = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("దయచేసి సరైన యూట్యూబ్ లింక్ ఇవ్వండి.")));
      }
    } else {
      // నార్మల్ MP4 డైరెక్ట్ లింక్ ప్లేబ్యాక్
      isYoutubeVideo = false;
      _bulletinVideoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (!mounted) return;
          _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
          setState(() {
            isNewsBulletinMode = true;
            hideControls = true;
          });
          _bulletinVideoController?.play();
          _bulletinVideoController?.setLooping(false);
          _bulletinVideoController?.addListener(_videoListener);
        }).catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఆ వీడియో లింక్ పనిచేయడం లేదు.")));
        });
    }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("దయచేసి సరైన RTMP లింక్ ఇవ్వండి."), backgroundColor: Colors.blueAccent));
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
        setState(() { isLiveBroadcasting = false; isLiveLocked = false; isLivePaused = false; }); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ విజయవంతంగా ఆపబడింది."), backgroundColor: Colors.green));
      }
    } catch (e) {}
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
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("ప్లేలిస్ట్ మేనేజర్ (బహుళ వీడియోలు)", style: TextStyle(color: Colors.white, fontSize: 14)),
          content: SingleChildScrollView(
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
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("వీడియోలు యాడ్ అయ్యాయి."), backgroundColor: Colors.green));
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
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white)))],
        );
      },
    );
  }

  // --- మల్టీ-లైవ్ మరియు ఆన్‌లైన్ వీడియో లింక్స్ మేనేజర్ విండో ---
  void _showMultiStreamDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(
      context: context, 
      builder: (context) { 
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900], 
              title: const Text("Live Control Room & Online Videos", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), 
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    // 1. RTMP లింక్ బాక్స్ (Destination)
                    _buildLinkEditor("1. YouTube/Restream RTMP Key (Live వెళ్ళడానికి)", youtubeUrlController, setDialogState),
                    const Divider(color: Colors.white24, height: 20),
                    // 2. డైరెక్ట్ వీడియో లింక్ బాక్స్ (Source)
                    _buildLinkEditor("2. Direct Video Link (ప్లే చేయడానికి)", networkVideoUrlCtrl, setDialogState, onPlay: () {
                       Navigator.pop(context);
                       _startNetworkBulletin(networkVideoUrlCtrl.text.trim());
                    }),
                    const Divider(color: Colors.white24, height: 20),
                    // 3. యూట్యూబ్ లింక్ బాక్స్ (Source)
                    _buildLinkEditor("3. YouTube Video Link (ప్లే చేయడానికి)", youtubeVideoUrlCtrl, setDialogState, onPlay: () {
                       Navigator.pop(context);
                       _startNetworkBulletin(youtubeVideoUrlCtrl.text.trim());
                    }),
                  ]
                )
              ), 
              actions: [
                // లైవ్ కంట్రోల్ బటన్స్
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green), 
                      onPressed: () { Navigator.pop(context); _startLiveAndLock(); }, 
                      child: const Text("Go Live", style: TextStyle(color: Colors.white, fontSize: 11))
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), 
                      onPressed: () async { 
                         Navigator.pop(context);
                         if (isLivePaused) {
                           bool success = await StreamServiceManager.startLiveStream(youtubeUrlController.text.trim());
                           if (success) {
                             setState(() { isLivePaused = false; });
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ రికార్డింగ్ మళ్లీ మొదలైంది!")));
                           }
                         } else {
                           bool success = await StreamServiceManager.stopLiveStream();
                           if (success) {
                             setState(() { isLivePaused = true; });
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ రికార్డింగ్ పాజ్ చేయబడింది.")));
                           }
                         }
                      }, 
                      child: Text(isLivePaused ? "Resume Live" : "Live Pause", style: const TextStyle(color: Colors.white, fontSize: 11))
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
                      onPressed: () { Navigator.pop(context); _stopLiveStream(); }, 
                      child: const Text("Live Close", style: TextStyle(color: Colors.white, fontSize: 11))
                    ),
                  ],
                )
              ]
            );
          }
        );
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
                 controller: controller,
                 style: const TextStyle(color: Colors.yellow, fontSize: 12),
                 decoration: const InputDecoration(
                   hintText: "Paste link here...",
                   hintStyle: TextStyle(color: Colors.white30),
                   enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                 ),
               ),
             ),
             IconButton(
               icon: const Icon(Icons.save, color: Colors.blueAccent, size: 22),
               onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Successfully!"), duration: Duration(seconds: 1))); },
             ),
             if (onPlay != null)
               IconButton(
                 icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 28),
                 onPressed: onPlay,
               )
           ],
         )
       ]
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

  void _showEditDialog() {
    setState(() { isMenuOpen = false; });
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("ఛానల్ లోగో & సెట్టింగ్స్", style: TextStyle(color: Colors.white, fontSize: 13)),
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
                      decoration: const InputDecoration(labelText: "మాన్యువల్ బ్రేకింగ్ న్యూస్ సెట్ చేయండి"),
                    ),
                    const SizedBox(height: 5),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      onPressed: () {
                        if (headlineCtrl.text.trim().isNotEmpty) {
                          setState(() { breakingNewsText = headlineCtrl.text.trim(); });
                          headlineCtrl.clear();
                          setDialogState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("న్యూస్ అప్‌డేట్ అయ్యింది!")));
                        }
                      },
                      child: const Text("హెడ్‌లైన్ అప్‌డేట్ చేయి", style: TextStyle(color: Colors.black)),
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

  void _toggleAutoTimerAds() { setState(() { isAnimatedAdsMode = !isAnimatedAdsMode; isMenuOpen = false; }); }
  Future<void> _pickVerticalAd() async { try { final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100); if (image != null && mounted) setState(() { verticalAnimatedAdPath = image.path; }); } catch (e) {} }
  Future<void> _pickHorizontalAd() async { try { final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100); if (image != null && mounted) setState(() { horizontalAnimatedAdPath = image.path; }); } catch (e) {} }

  Widget _buildMainDisplay(bool isScreenLandscape, double screenWidth, double screenHeight, Widget cameraWidget, Widget visualScreenLogoWidget) {
    if (isVideoAdPlaying && _videoAdVlcController != null) {
      return IgnorePointer(ignoring: true, child: Container(color: Colors.black, child: VlcPlayer(controller: _videoAdVlcController!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.amber)))));
    }
    
    // Live Pause లాజిక్: కెమెరా ఆన్ లోనే ఉంటుంది, కానీ బ్రాడ్‌కాస్టింగ్ కట్ అవుతుంది.
    Widget actualCameraWidget = isLivePaused 
        ? Stack(
            children: [
              cameraWidget,
              Container(color: Colors.black54, child: const Center(child: Text("🔴 LIVE PAUSED", style: TextStyle(color: Colors.redAccent, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 2))))
            ],
          )
        : cameraWidget;
    
    // PiP మోడ్: యూట్యూబ్ లేదా నార్మల్ వీడియోని హ్యాండిల్ చేయడం
    if (isNewsBulletinMode && (_ytController != null || (_bulletinVideoController != null && _bulletinVideoController!.value.isInitialized))) {
      double pipWidth = isScreenLandscape ? screenWidth * 0.28 : screenWidth * 0.38;
      double pipHeight = pipWidth * (screenHeight / screenWidth); 

      // వీడియో విడ్జెట్ ఏది ప్లే చేయాలి?
      Widget videoBackground;
      if (isYoutubeVideo && _ytController != null) {
        videoBackground = YoutubePlayer(controller: _ytController!);
      } else {
        videoBackground = AspectRatio(
          aspectRatio: _bulletinVideoController!.value.aspectRatio,
          child: VideoPlayer(_bulletinVideoController!),
        );
      }

      return Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Center(
                child: videoBackground,
              ),
            ),
          ),
          Positioned(
            top: 20, right: 15,
            child: Container(
              width: pipWidth, height: pipHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber, width: 2.0),
                boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 8)],
              ),
              child: actualCameraWidget,
            ),
          ),
          if (!hideControls)
            Positioned(
              top: 20 + pipHeight + 5, right: 15,
              child: GestureDetector(
                onTap: () {
                  _toggleMute();
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
      return Stack(children: [Positioned.fill(child: actualCameraWidget), Positioned(top: 15, left: 15, child: visualScreenLogoWidget)]);
    }

    double vertAdWidth = screenWidth * 0.24;  
    double horizAdHeight = screenHeight * 0.15; 

    return Container(
      color: adLayerColor,
      child: Stack(
        children: [
          Positioned.fill(child: actualCameraWidget), 
          Positioned(top: 15, left: 15, child: visualScreenLogoWidget),
          Positioned(left: 0, top: 0, bottom: 55, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _pickVerticalAd, child: Container(width: vertAdWidth, decoration: const BoxDecoration(border: Border(right: BorderSide(color: Colors.amber, width: 2.0)), color: Colors.black54), child: verticalAnimatedAdPath.isNotEmpty ? Image.file(File(verticalAnimatedAdPath), fit: BoxFit.fill, width: double.infinity, height: double.infinity) : const Center(child: Icon(Icons.add_photo_alternate, color: Colors.amber, size: 26))))),
          Positioned(left: vertAdWidth, right: 0, bottom: 55, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _pickHorizontalAd, child: Container(height: horizAdHeight, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.amber, width: 2.0)), color: Colors.black54), child: horizontalAnimatedAdPath.isNotEmpty ? Image.file(File(horizontalAnimatedAdPath), fit: BoxFit.fill, width: double.infinity, height: double.infinity) : const Center(child: Icon(Icons.add_photo_alternate, color: Colors.amber, size: 26))))),
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
              if (isLiveLocked && isNewsBulletinMode) {
                if (isYoutubeVideo && _ytController != null) {
                  _ytController!.value.isPlaying ? _ytController!.pause() : _ytController!.play();
                } else if (_bulletinVideoController != null) {
                  _bulletinVideoController!.value.isPlaying ? _bulletinVideoController!.pause() : _bulletinVideoController!.play();
                }
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
                    child: Row(children: [
                      GestureDetector(onTap: _pickBreakingNewsLogo, child: Container(width: 55, height: double.infinity, color: Colors.black, child: breakingNewsLogoPath.isNotEmpty ? Image.file(File(breakingNewsLogoPath), fit: BoxFit.cover, width: double.infinity, height: double.infinity) : const Center(child: Icon(Icons.newspaper, color: Colors.amber, size: 28)))), 
                      Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 45.0)))
                    ]),
                  ),
                ),

                if (!hideControls && !isLiveLocked)
                  Positioned(
                    bottom: 75, right: 20,
                    child: FloatingActionButton(backgroundColor: Colors.blueAccent.withOpacity(0.9), onPressed: () { setState(() { isMenuOpen = !isMenuOpen; }); }, child: Icon(isMenuOpen ? Icons.close : Icons.menu, color: Colors.white, size: 28)),
                  ),

                if (isLiveLocked)
                  Positioned(
                    bottom: 75, right: 20,
                    child: GestureDetector(
                      onLongPress: () {
                        HapticFeedback.heavyImpact();
                        setState(() { isLiveLocked = false; hideControls = false; });
                      },
                      child: FloatingActionButton(
                        backgroundColor: Colors.red.withOpacity(0.4),
                        elevation: 0,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లాక్ తీయడానికి దీన్ని గట్టిగా నొక్కి పట్టుకోండి (Long Press)")));
                        },
                        child: const Icon(Icons.lock, color: Colors.white70),
                      ),
                    ),
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
                            _buildControlButton(Icons.live_tv, "3. Multi-Live Cntrl", _showMultiStreamDialog, Colors.redAccent),
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
