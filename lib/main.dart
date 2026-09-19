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
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';

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
  VlcPlayerController? _vlcViewController;
  VlcPlayerController? _videoAdVlcController; 
  VideoPlayerController? _bulletinVideoController; 
  
  bool hideControls = false;
  int currentCameraIndex = 0;
  bool isLandscape = false;
  bool isIpCameraActive = false;
  bool isLiveBroadcasting = false;
  bool isAnimatedAdsMode = false; 
  bool isVideoAdPlaying = false; 
  
  bool isNewsBulletinMode = false;
  int currentNewsIndex = 0;

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

  String ipCameraUrl = ""; 
  TextEditingController ipController = TextEditingController();
  TextEditingController qrDataController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Color adLayerColor = const Color(0xFF111111);
  
  String verticalAnimatedAdPath = "";
  String horizontalAnimatedAdPath = "";
  String breakingNewsLogoPath = ""; 
  
  double _vertScale = 1.0;
  double _vertRotation = 0.0;
  Offset _vertOffset = Offset.zero;

  double _horizScale = 1.0;
  double _horizRotation = 0.0;
  Offset _horizOffset = Offset.zero;

  final List<String> videoAdsList = List.generate(10, (index) => "");

  String channelLogoPath = ""; 
  double logoWidth = 70.0;
  double logoHeight = 70.0;

  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA"; 
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String breakingNewsText = "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి... దయచేసి వేచి ఉండండి...";
  
  final ValueNotifier<String> topHeadlineNotifier = ValueNotifier<String>("రైతు పొలంలో కలకలం.. గట్లపై భారీ పులి అడుగుల గుర్తులు!");

  TextEditingController youtubeUrlController = TextEditingController();
  TextEditingController restreamKeyController = TextEditingController();
  TextEditingController watermarkCtrl = TextEditingController();
  TextEditingController locCtrl = TextEditingController();
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController roleCtrl = TextEditingController();
  TextEditingController headlineCtrl = TextEditingController();

  Timer? _newsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    watermarkCtrl.text = watermarkText;
    locCtrl.text = locationText;
    nameCtrl.text = reporterName;
    roleCtrl.text = reporterRole;
    headlineCtrl.text = "";
    qrDataController.text = "https://ssyatratv.com/live-stream";
    youtubeUrlController.text = "rtmp://bangalore.restream.io/live";
    restreamKeyController.text = "";

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
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (!isIpCameraActive) {
        _initCamera();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newsTimer?.cancel();
    _headlineRotationTimer?.cancel();
    controller?.dispose();
    _vlcViewController?.dispose();
    _videoAdVlcController?.dispose();
    _bulletinVideoController?.removeListener(_videoListener);
    _bulletinVideoController?.dispose();
    topHeadlineNotifier.dispose();
    ipController.dispose();
    qrDataController.dispose();
    youtubeUrlController.dispose();
    restreamKeyController.dispose();
    watermarkCtrl.dispose();
    locCtrl.dispose();
    nameCtrl.dispose();
    roleCtrl.dispose();
    headlineCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera, 
      Permission.microphone, 
      Permission.storage,
      Permission.photos, 
      Permission.videos,
    ].request();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty || isIpCameraActive) return;
    try {
      if (controller != null) {
        await controller!.dispose();
        controller = null;
      }
      final camController = CameraController(
        cameras[currentCameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      controller = camController;
      await camController.initialize();
      if (!mounted) return;
      _minZoomLevel = await camController.getMinZoomLevel();
      _maxZoomLevel = await camController.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
      setState(() {});
    } catch (e) {
      debugPrint("Camera Init Error: $e");
    }
  }

  void _switchCamera() async {
    if (isIpCameraActive || isVideoAdPlaying) return; 
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    await _initCamera();
  }

  void _toggleIpCamera() {
    if (isIpCameraActive) {
      _vlcViewController?.stopRendererScanning();
      _vlcViewController?.dispose();
      setState(() { isIpCameraActive = false; });
      _initCamera();
    } else {
      if (ipCameraUrl.isEmpty) {
        _showIpInputDialog();
        return;
      }
      controller?.dispose();
      _vlcViewController = VlcPlayerController.network(
        ipCameraUrl,
        hwAcc: HwAcc.full,
        autoPlay: true,
      );
      setState(() { isIpCameraActive = true; });
    }
  }

  void _startBulletinMedia(String path, bool isVideo) {
    if (path.isEmpty) return;
    if (isVideo) {
      _bulletinVideoController?.removeListener(_videoListener);
      _bulletinVideoController?.dispose();
      _bulletinVideoController = VideoPlayerController.file(File(path))
        ..initialize().then((_) {
          if (!mounted) return;
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
      _nextNewsItem();
    }
  }

  void _nextNewsItem() {
    if (newsBulletinList.length <= 1) return;
    setState(() {
      currentNewsIndex = (currentNewsIndex + 1) % newsBulletinList.length;
      if (newsBulletinList[currentNewsIndex].mediaPath.isNotEmpty) {
        _startBulletinMedia(newsBulletinList[currentNewsIndex].mediaPath, newsBulletinList[currentNewsIndex].isVideo);
      }
    });
  }

  void _prevNewsItem() {
    if (newsBulletinList.length <= 1) return;
    setState(() {
      currentNewsIndex = (currentNewsIndex - 1 + newsBulletinList.length) % newsBulletinList.length;
      if (newsBulletinList[currentNewsIndex].mediaPath.isNotEmpty) {
        _startBulletinMedia(newsBulletinList[currentNewsIndex].mediaPath, newsBulletinList[currentNewsIndex].isVideo);
      }
    });
  }

  // === UPDATED: Safe Gallery Picker with Error Handling ===
  Future<void> _pickMultipleBulletinMedia() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultipleMedia();
      if (pickedFiles.isNotEmpty && mounted) {
        setState(() {
          if (newsBulletinList.length == 1 && newsBulletinList[0].mediaPath.isEmpty) {
            newsBulletinList.clear();
          }
          int startPlayingIndex = newsBulletinList.length;

          for (int i = 0; i < pickedFiles.length; i++) {
            var file = pickedFiles[i];
            bool isVid = file.path.toLowerCase().endsWith('.mp4') || file.path.toLowerCase().endsWith('.mov') || file.path.toLowerCase().endsWith('.mkv');
            newsBulletinList.add(NewsBulletinItem(
              title: "వార్తా అప్‌డేట్ ${newsBulletinList.length + 1}", 
              mediaPath: file.path, 
              isVideo: isVid
            ));
          }

          if (_bulletinVideoController == null || !_bulletinVideoController!.value.isPlaying) {
            if (startPlayingIndex < newsBulletinList.length) {
              currentNewsIndex = startPlayingIndex;
              _startBulletinMedia(newsBulletinList[currentNewsIndex].mediaPath, newsBulletinList[currentNewsIndex].isVideo);
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Gallery Picker Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("గ్యాలరీ ఫైల్స్ ఎంచుకోవడంలో చిన్న సమస్య వచ్చింది. దయచేసి మళ్లీ ప్రయత్నించండి."), 
          backgroundColor: Colors.red
        ),
      );
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
    setState(() { isVideoAdPlaying = true; });
  }

  void _stopVideoAd() {
    _videoAdVlcController?.stopRendererScanning();
    setState(() {
      isVideoAdPlaying = false;
      _videoAdVlcController = null;
    });
  }

  void _toggleNewsBulletinMode() {
    setState(() {
      isNewsBulletinMode = !isNewsBulletinMode;
      hideControls = true; 
      if (isNewsBulletinMode) {
        if (newsBulletinList[currentNewsIndex].mediaPath.isNotEmpty) {
          _startBulletinMedia(newsBulletinList[currentNewsIndex].mediaPath, newsBulletinList[currentNewsIndex].isVideo);
        }
      } else {
        _bulletinVideoController?.removeListener(_videoListener);
        _bulletinVideoController?.dispose();
        _bulletinVideoController = null;
      }
    });
  }

  Future<void> _toggleHiddenLiveStream() async {
    String rtmpUrl = youtubeUrlController.text.trim();
    String streamKey = restreamKeyController.text.trim();

    String fullRtmpUrl = "";
    if (rtmpUrl.isNotEmpty && streamKey.isNotEmpty) {
      fullRtmpUrl = rtmpUrl.endsWith('/') ? "$rtmpUrl$streamKey" : "$rtmpUrl/$streamKey";
    }

    if (!isLiveBroadcasting) {
      bool success = await StreamServiceManager.startLiveStream(fullRtmpUrl);
      if (success) {
        setState(() { isLiveBroadcasting = true; });
      }
    } else {
      bool success = await StreamServiceManager.stopLiveStream();
      if (success) {
        setState(() { isLiveBroadcasting = false; });
      }
    }
  }

  Future<void> _pickBreakingNewsLogo() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (image != null && mounted) {
        setState(() {
          breakingNewsLogoPath = image.path; 
        });
      }
    } catch (e) {
      debugPrint("Image Picker Error: $e");
    }
  }

  void _showBulletinManagerDialog() {
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
                      TextField(
                        controller: newTitleCtrl,
                        style: const TextStyle(color: Colors.yellow),
                        decoration: const InputDecoration(
                          labelText: "సెలక్ట్ చేసిన వీడియోల టైటిల్",
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            final List<XFile> medias = await _picker.pickMultipleMedia();
                            if (medias.isNotEmpty) {
                              setState(() {
                                if (newsBulletinList.length == 1 && newsBulletinList[0].mediaPath.isEmpty) {
                                  newsBulletinList.clear();
                                }
                                for (var media in medias) {
                                  bool isVid = media.path.toLowerCase().endsWith('.mp4') || media.path.toLowerCase().endsWith('.mov');
                                  String fTitle = newTitleCtrl.text.isNotEmpty ? newTitleCtrl.text : "వార్తా అప్‌డేట్ ${newsBulletinList.length + 1}";
                                  newsBulletinList.add(NewsBulletinItem(title: fTitle, mediaPath: media.path, isVideo: isVid));
                                }
                                if (_bulletinVideoController == null || !_bulletinVideoController!.value.isPlaying) {
                                  currentNewsIndex = newsBulletinList.length - medias.length;
                                  _startBulletinMedia(newsBulletinList[currentNewsIndex].mediaPath, newsBulletinList[currentNewsIndex].isVideo);
                                }
                              });
                            }
                          } catch(e) {
                             debugPrint("Multi Picker Error from Dialog: $e");
                          }
                        },
                        icon: const Icon(Icons.video_library, color: Colors.black),
                        label: const Text("గ్యాలరీ నుండి వీడియోలు జోడించు", style: TextStyle(color: Colors.black, fontSize: 12)),
                      ),
                      const SizedBox(height: 15),
                      const Text("క్యూ లో ఉన్న వీడియోలు:", style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: newsBulletinList.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              selected: currentNewsIndex == index,
                              selectedTileColor: Colors.red.shade900.withOpacity(0.5),
                              title: Text(newsBulletinList[index].title, style: const TextStyle(color: Colors.white, fontSize: 11), maxLines: 1),
                              onTap: () {
                                setState(() {
                                  currentNewsIndex = index;
                                  if (newsBulletinList[index].mediaPath.isNotEmpty) {
                                    _startBulletinMedia(newsBulletinList[index].mediaPath, newsBulletinList[index].isVideo);
                                  }
                                });
                                Navigator.pop(context);
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                onPressed: () {
                                  setState(() {
                                    newsBulletinList.removeAt(index);
                                    if (newsBulletinList.isEmpty) {
                                      newsBulletinList.add(NewsBulletinItem(title: "వీడియో లేదు", mediaPath: "", isVideo: true));
                                      currentNewsIndex = 0;
                                    } else if (currentNewsIndex >= newsBulletinList.length) {
                                      currentNewsIndex = 0;
                                    }
                                  });
                                  setDialogState(() {}); 
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white))),
              ],
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
        if (titles.isNotEmpty && mounted) {
          setState(() { breakingNewsText = titles.join("   ♦   "); });
        }
      }
    } catch (e) {
      debugPrint("News Error: $e");
    }
  }

  void _toggleAutoTimerAds() {
    setState(() { isAnimatedAdsMode = !isAnimatedAdsMode; });
  }

  Future<void> _pickVerticalAd() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (image != null && mounted) {
        setState(() { verticalAnimatedAdPath = image.path; _vertScale = 1.0; _vertRotation = 0.0; _vertOffset = Offset.zero; });
      }
    } catch (e) {}
  }

  Future<void> _pickHorizontalAd() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
      if (image != null && mounted) {
        setState(() { horizontalAnimatedAdPath = image.path; _horizScale = 1.0; _horizRotation = 0.0; _horizOffset = Offset.zero; });
      }
    } catch (e) {}
  }

  void _showAdsManagerDialog() {
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
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(40, 30)),
                            onPressed: () { Navigator.pop(context); _playVideoAd(videoAdsList[index]); },
                            child: const Text("Play", style: TextStyle(fontSize: 11)),
                          ),
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

  void _showQrGeneratorDialog() {
    showDialog(context: context, builder: (context) { return AlertDialog(backgroundColor: Colors.grey[900], title: const Text("PCR QR కోడ్ జనరేటర్", style: TextStyle(color: Colors.white)), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: qrDataController, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "లైవ్ లింక్", labelStyle: TextStyle(color: Colors.white54))), const SizedBox(height: 20), Container(padding: const EdgeInsets.all(10), color: Colors.white, child: QrImageView(data: qrDataController.text, version: QrVersions.auto, size: 150.0))],), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white)))]);});
  }

  void _showIpInputDialog() {
    showDialog(context: context, builder: (context) { return AlertDialog(backgroundColor: Colors.grey[900], title: const Text("IP / Stream Link సెట్టింగ్స్", style: TextStyle(color: Colors.white)), content: TextField(controller: ipController, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "RTSP / HTTP లింక్", labelStyle: TextStyle(color: Colors.white54))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { setState(() { ipCameraUrl = ipController.text; }); Navigator.pop(context); }, child: const Text("Save", style: TextStyle(color: Colors.white)))]);});
  }

  void _showMultiStreamDialog() {
    showDialog(context: context, builder: (context) { return AlertDialog(backgroundColor: Colors.grey[900], title: const Text("Restream & YouTube Multi-Live సెటప్", style: TextStyle(color: Colors.white, fontSize: 14)), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: youtubeUrlController, style: const TextStyle(color: Colors.yellow, fontSize: 12), decoration: const InputDecoration(labelText: "RTMP URL (ఉదా: rtmp://bangalore.restream.io/live)", labelStyle: TextStyle(color: Colors.white54))), const SizedBox(height: 10), TextField(controller: restreamKeyController, style: const TextStyle(color: Colors.yellow, fontSize: 12), decoration: const InputDecoration(labelText: "Stream Key", labelStyle: TextStyle(color: Colors.white54)))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ సెట్టింగ్స్ సేవ్ అయ్యాయి!"), backgroundColor: Colors.blue)); }, child: const Text("Save Live Settings", style: TextStyle(color: Colors.white)))]);});
  }

  void _showEditDialog() {
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
                      decoration: const InputDecoration(labelText: "కొత్త హెడ్‌లైన్ టైప్ చేయండి"),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          setState(() {
                            customHeadlines.add(val.trim());
                          });
                          setDialogState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 5),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      onPressed: () {
                        if (headlineCtrl.text.trim().isNotEmpty) {
                          setState(() {
                            customHeadlines.add(headlineCtrl.text.trim());
                          });
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
      isLandscape = !isLandscape;
      if (isLandscape) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    });
  }

  Widget _buildBulletinMode(bool isScreenLandscape, Widget cameraWidget, Widget bottomVideoWidget, Widget reporterBadgeWidget, Widget visualScreenLogoWidget) {
    if (isScreenLandscape) {
      return Column(
        children: [
          Container(
            width: double.infinity, margin: EdgeInsets.zero, padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top > 0 ? MediaQuery.of(context).padding.top : 8, bottom: 12, left: 15, right: 15), color: Colors.red.shade900,
            child: ValueListenableBuilder<String>(
              valueListenable: topHeadlineNotifier,
              builder: (context, headlineText, child) { return Text(headlineText, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1); },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0), 
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.redAccent, width: 4.0), borderRadius: BorderRadius.circular(14)),
                      child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Stack(children: [Positioned.fill(child: cameraWidget), Positioned(bottom: 10, left: 10, child: reporterBadgeWidget)])),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity, color: Colors.blueAccent.shade700, padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Text(newsBulletinList[currentNewsIndex].title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.cyanAccent, width: 4.0), borderRadius: BorderRadius.circular(14)),
                            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Stack(children: [Positioned.fill(child: bottomVideoWidget), Positioned(top: 15, right: 15, child: visualScreenLogoWidget)])),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 50, decoration: BoxDecoration(color: Colors.red.shade900, border: const Border(top: BorderSide(color: Colors.amber, width: 1.5))),
            child: Row(children: [Container(width: 50, color: Colors.black, child: breakingNewsLogoPath.isNotEmpty ? Image.file(File(breakingNewsLogoPath), fit: BoxFit.cover) : (channelLogoPath.isNotEmpty ? Image.file(File(channelLogoPath), fit: BoxFit.cover) : const Icon(Icons.newspaper, color: Colors.amber))), Expanded(child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 40.0))]),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top > 0 ? MediaQuery.of(context).padding.top : 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: Colors.redAccent, width: 4.0), borderRadius: BorderRadius.circular(14)),
              child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Stack(children: [Positioned.fill(child: cameraWidget), Positioned(top: 15, left: 15, child: visualScreenLogoWidget)])),
            ),
          ),
          Container(
            width: double.infinity, color: Colors.yellowAccent.shade700, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            child: ValueListenableBuilder<String>(
              valueListenable: topHeadlineNotifier,
              builder: (context, headlineText, child) {
                return Text(headlineText, style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900, height: 1.3), textAlign: TextAlign.center, maxLines: 2);
              },
            ),
          ),
          Container(
            width: double.infinity, color: Colors.blueAccent.shade700, padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Text(
              newsBulletinList[currentNewsIndex].title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(border: Border.all(color: Colors.cyanAccent, width: 4.0), borderRadius: BorderRadius.circular(14)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(aspectRatio: 16 / 9, child: bottomVideoWidget),
            ),
          ),
          Container(
            height: 55, decoration: BoxDecoration(color: Colors.red.shade900, border: const Border(top: BorderSide(color: Colors.amber, width: 1.5))),
            child: Row(children: [Container(width: 55, color: Colors.black, child: breakingNewsLogoPath.isNotEmpty ? Image.file(File(breakingNewsLogoPath), fit: BoxFit.cover) : (channelLogoPath.isNotEmpty ? Image.file(File(channelLogoPath), fit: BoxFit.cover) : const Icon(Icons.newspaper, color: Colors.amber))), Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 40.0)))]),
          ),
        ],
      );
    }
  }

  Widget _buildNormalMode(bool isScreenLandscape, double screenWidth, Widget cameraWidget, Widget visualScreenLogoWidget) {
    if (isVideoAdPlaying && _videoAdVlcController != null) {
      return Container(color: Colors.black, child: VlcPlayer(controller: _videoAdVlcController!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.amber))));
    }
    if (!isAnimatedAdsMode) {
      return Stack(children: [Positioned.fill(child: cameraWidget), Positioned(top: 15, right: 15, child: visualScreenLogoWidget)]);
    }
    return Container(
      color: adLayerColor,
      child: Stack(
        children: [
          Positioned.fill(child: cameraWidget), Positioned(top: 15, right: 15, child: visualScreenLogoWidget),
          Positioned(
            left: 10 + _vertOffset.dx, top: 10 + _vertOffset.dy,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: _pickVerticalAd, onPanUpdate: (details) { setState(() { _vertOffset += details.delta; }); },
              child: Transform(transform: Matrix4.identity()..scale(_vertScale)..rotateZ(_vertRotation), alignment: Alignment.center, child: GestureDetector(onScaleUpdate: (details) { setState(() { _vertScale = (_vertScale * details.scale).clamp(0.3, 4.0); _vertRotation += details.rotation; }); }, child: Container(width: 140, height: 420, decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 1.5)), child: verticalAnimatedAdPath.isNotEmpty ? Image.file(File(verticalAnimatedAdPath), fit: BoxFit.fill, width: double.infinity, height: double.infinity) : const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, color: Colors.amber, size: 28), SizedBox(height: 5), Text("TAP TO UPLOAD JPEG/GIF AD", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))]))))),
            ),
          ),
          Positioned(
            left: 150 + _horizOffset.dx, bottom: 60 + _horizOffset.dy, 
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: _pickHorizontalAd, onPanUpdate: (details) { setState(() { _horizOffset += details.delta; }); },
              child: Transform(transform: Matrix4.identity()..scale(_horizScale)..rotateZ(_horizRotation), alignment: Alignment.center, child: GestureDetector(onScaleUpdate: (details) { setState(() { _horizScale = (_horizScale * details.scale).clamp(0.3, 4.0); _horizRotation += details.rotation; }); }, child: Container(width: screenWidth - 155, height: 90, decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 1.5)), child: horizontalAnimatedAdPath.isNotEmpty ? Image.file(File(horizontalAnimatedAdPath), fit: BoxFit.fill, width: double.infinity, height: double.infinity) : const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, color: Colors.amber, size: 20), SizedBox(width: 6), Text("TAP TO UPLOAD JPEG/GIF AD", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))]))))),
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
    
    double camW = 1080;
    double camH = 1920;
    if (controller != null && controller!.value.isInitialized) {
      final previewSize = controller!.value.previewSize;
      if (previewSize != null) {
        camW = previewSize.width;
        camH = previewSize.height;
        if (camW < camH) { double temp = camW; camW = camH; camH = temp; }
      }
    }
    double finalCamW = isScreenLandscape ? camW : camH;
    double finalCamH = isScreenLandscape ? camH : camW;

    Widget cameraWidget = isIpCameraActive && _vlcViewController != null
        ? VlcPlayer(controller: _vlcViewController!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.red)))
        : (controller != null && controller!.value.isInitialized 
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
            : const Center(child: CircularProgressIndicator(color: Colors.white)));

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
      ],
    );

    Widget visualScreenLogoWidget = GestureDetector(
      onLongPress: _toggleHiddenLiveStream,
      child: channelLogoPath.isNotEmpty
          ? SizedBox(width: logoWidth, height: logoHeight, child: Image.file(File(channelLogoPath), fit: BoxFit.contain, filterQuality: FilterQuality.high))
          : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), color: Colors.red[900]?.withOpacity(0.9), child: const Text("SS YATRA TV", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
    );

    Widget bottomVideoWidget = newsBulletinList[currentNewsIndex].mediaPath.isNotEmpty
        ? (!newsBulletinList[currentNewsIndex].isVideo
            ? Image.file(File(newsBulletinList[currentNewsIndex].mediaPath), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
            : (_bulletinVideoController != null && _bulletinVideoController!.value.isInitialized
                ? ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover, 
                      child: SizedBox(width: _bulletinVideoController!.value.size.width, height: _bulletinVideoController!.value.size.height, child: VideoPlayer(_bulletinVideoController!)),
                    ),
                  )
                : Container(color: Colors.black, child: const Center(child: CircularProgressIndicator(color: Colors.amber)))))
        : Container(color: Colors.black, child: Center(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), onPressed: _pickMultipleBulletinMedia, icon: const Icon(Icons.perm_media), label: const Text("బహుళ (Multiple) వీడియోలు ఎంచుకోండి"))));

    return WillPopScope(
      onWillPop: () async {
        if (isNewsBulletinMode) { setState(() { isNewsBulletinMode = false; hideControls = false; }); return false; } 
        else if (!hideControls) { setState(() { hideControls = true; }); return false; }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: false, 
          bottom: true,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () { setState(() { hideControls = !hideControls; }); },
                  onDoubleTap: _toggleHiddenLiveStream,
                  child: isNewsBulletinMode
                      ? _buildBulletinMode(isScreenLandscape, cameraWidget, bottomVideoWidget, reporterBadgeWidget, visualScreenLogoWidget)
                      : _buildNormalMode(isScreenLandscape, screenWidth, cameraWidget, visualScreenLogoWidget),
                ),
              ),

              if (isVideoAdPlaying)
                Positioned(top: 40, right: 40, child: FloatingActionButton.extended(backgroundColor: Colors.red, onPressed: _stopVideoAd, label: const Text("Close Ad & Resume", style: TextStyle(color: Colors.white)), icon: const Icon(Icons.close, color: Colors.white))),

              if (!isNewsBulletinMode)
                Positioned(bottom: isAnimatedAdsMode ? 160 : 65, left: isAnimatedAdsMode ? 152 : 15, child: reporterBadgeWidget),
              
              if (!isNewsBulletinMode)
                Positioned(
                  bottom: 0, left: 0, right: 0, 
                  child: Container(
                    height: 55, decoration: BoxDecoration(color: Colors.red.shade900, border: Border.all(color: Colors.amber.shade400, width: 1.5)),
                    child: Row(children: [GestureDetector(onTap: _pickBreakingNewsLogo, child: Container(width: 55, height: double.infinity, color: Colors.black, child: breakingNewsLogoPath.isNotEmpty ? Image.file(File(breakingNewsLogoPath), fit: BoxFit.cover, width: double.infinity, height: double.infinity) : const Center(child: Icon(Icons.newspaper, color: Colors.amber, size: 28)))), Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 40.0)))]),
                  ),
                ),

              if (!hideControls)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Wrap(
                        alignment: WrapAlignment.center, spacing: 15, runSpacing: 15,
                        children: [
                          _buildControlButton(Icons.flip_camera_android, "Phone Cam", _switchCamera, Colors.white),
                          _buildControlButton(Icons.wifi_tethering, "IP Cam", _toggleIpCamera, isIpCameraActive ? Colors.green : Colors.orange),
                          _buildControlButton(Icons.video_library, "Media Ads", _showAdsManagerDialog, Colors.amberAccent),
                          _buildControlButton(Icons.qr_code_2, "QR Gen", _showQrGeneratorDialog, Colors.tealAccent),
                          _buildControlButton(Icons.edit, "Logo & Edit", _showEditDialog, Colors.blue),
                          _buildControlButton(Icons.settings_ethernet, "Set IP", _showIpInputDialog, Colors.cyan),
                          _buildControlButton(isLiveBroadcasting ? Icons.stop : Icons.live_tv, "Multi-Live", _showMultiStreamDialog, isLiveBroadcasting ? Colors.green : Colors.redAccent),
                          _buildControlButton(isNewsBulletinMode ? Icons.newspaper : Icons.featured_play_list, isNewsBulletinMode ? "Exit Bulletin" : "News Bulletin", _toggleNewsBulletinMode, isNewsBulletinMode ? Colors.cyanAccent : Colors.pinkAccent),
                          _buildControlButton(Icons.playlist_add, "Bulletin Mgr", _showBulletinManagerDialog, Colors.amber),
                          _buildControlButton(isAnimatedAdsMode ? Icons.fullscreen : Icons.timer, isAnimatedAdsMode ? "Ads Active" : "Auto Timer Ads", _toggleAutoTimerAds, isAnimatedAdsMode ? Colors.greenAccent : Colors.amber),
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
    );
  }

  Widget _buildControlButton(IconData icon, String label, VoidCallback onTap, Color iconColor) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 24, backgroundColor: Colors.white30, child: Icon(icon, color: iconColor, size: 24)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }
}

class StreamServiceManager {
  static const platform = MethodChannel('com.ssyatratv.pocket_pcr/stream');
  static Future<bool> startLiveStream(String rtmpUrl) async {
    try { await platform.invokeMethod('startScreenStream', {'rtmpUrl': rtmpUrl}); return true; } catch (e) { return false; }
  }
  static Future<bool> stopLiveStream() async {
    try { await platform.invokeMethod('stopScreenStream'); return true; } catch (e) { return false; }
  }
}
