import 'package:flutter/material.dart';
import 'package:rtmp_broadcaster/camera.dart';
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
  final String title;
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
  bool showVideoControls = true; 
  int currentCameraIndex = 0;
  bool isLandscape = false;
  bool isIpCameraActive = false;
  bool isLiveBroadcasting = false;
  bool isAnimatedAdsMode = false; 
  bool isVideoAdPlaying = false; 
  
  bool isNewsBulletinMode = false;
  int currentNewsIndex = 0;

  final List<NewsBulletinItem> newsBulletinList = [
    NewsBulletinItem(title: "తెలంగాణలో పెరుగుతున్న పొలిటికల్ హీట్.. అసెంబ్లీలో శుద్ధి రగడ!", mediaPath: "", isVideo: true),
    NewsBulletinItem(title: "సమగ్ర విచారణకు సీఎం రేవంత్ ఆదేశం.. ఐపీఎస్ విజయ్‌కుమార్ నియామకం!", mediaPath: "", isVideo: true),
    NewsBulletinItem(title: "ఎర్రవలి ఫార్మ్‌హౌస్ ఘటనపై బీఆర్ఎస్ నేతల తీవ్ర ఆగ్రహం!", mediaPath: "", isVideo: true),
  ];

  List<String> customHeadlines = [
    "తెలంగాణలో పెరుగుతున్న పొలిటికల్ హీట్.. అసెంబ్లీలో శుద్ధి రగడ!",
    "సమగ్ర విచారణకు సీఎం రేవంత్ ఆదేశం.. ఐపీఎస్ విజయ్‌కుమార్ నియామకం!",
    "ఎర్రవలి ఫార్మ్‌హౌస్ ఘటనపై బీఆర్ఎస్ నేతల తీవ్ర ఆగ్రహం!"
  ];
  int _headlineIndex = 0;
  Timer? _headlineRotationTimer;

  String ipCameraUrl = ""; 
  TextEditingController ipController = TextEditingController();
  TextEditingController qrDataController = TextEditingController();
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
  String breakingNewsText = "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి... దయచేసి వేచి ఉండండి...";
  String topHeadlineText = "తెలంగాణలో పెరుగుతున్న పొలిటికల్ హీట్.. అసెంబ్లీలో శుద్ధి రగడ!";

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
    headlineCtrl.text = topHeadlineText;
    qrDataController.text = "https://ssyatratv.com/live-stream";
    youtubeUrlController.text = "rtmp://bangalore.restream.io/live";
    restreamKeyController.text = "";

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    
    _initializeEverything();
    _fetchBreakingNews(); 

    _headlineRotationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (customHeadlines.isNotEmpty) {
        setState(() {
          _headlineIndex = (_headlineIndex + 1) % customHeadlines.length;
          topHeadlineText = customHeadlines[_headlineIndex];
        });
      }
    });

    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _fetchBreakingNews();
    });
  }

  Future<void> _initializeEverything() async {
    await [Permission.camera, Permission.microphone, Permission.storage].request();
    await _initCamera();
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
    _bulletinVideoController?.dispose();
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

  Future<void> _initCamera() async {
    if (isIpCameraActive) return;
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) return;

      if (controller != null) {
        await controller!.dispose();
        controller = null;
      }
      final camController = CameraController(
        cameras[currentCameraIndex],
        ResolutionPreset.medium,
        enableAudio: true,
      );
      controller = camController;
      await camController.initialize();
      if (!mounted) return;
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
      _bulletinVideoController?.dispose();
      _bulletinVideoController = VideoPlayerController.file(File(path))
        ..initialize().then((_) {
          setState(() {});
          _bulletinVideoController?.play();
          _bulletinVideoController?.setLooping(true);
        });
    }
    setState(() {});
  }

  void _playVideoAd(String videoPath) {
    if (videoPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("దయచేసి ముందుగా గ్యాలరీ నుండి మీడియా ఎంచుకోండి!"), backgroundColor: Colors.red));
      return;
    }
    _videoAdVlcController?.stopRendererScanning();
    _videoAdVlcController?.dispose();

    _videoAdVlcController = VlcPlayerController.file(
      File(videoPath),
      hwAcc: HwAcc.full,
      autoPlay: true,
    );
    setState(() {
      isVideoAdPlaying = true;
    });
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
        if (newsBulletinList[currentNewsIndex].mediaPath.isNotEmpty && newsBulletinList[currentNewsIndex].isVideo) {
          _startBulletinMedia(newsBulletinList[currentNewsIndex].mediaPath, true);
        }
      } else {
        _bulletinVideoController?.dispose();
        _bulletinVideoController = null;
      }
    });
  }

  void _nextNewsItem() {
    setState(() {
      currentNewsIndex = (currentNewsIndex + 1) % newsBulletinList.length;
      topHeadlineText = newsBulletinList[currentNewsIndex].title;
      headlineCtrl.text = topHeadlineText;
      if (newsBulletinList[currentNewsIndex].mediaPath.isNotEmpty && newsBulletinList[currentNewsIndex].isVideo) {
        _startBulletinMedia(newsBulletinList[currentNewsIndex].mediaPath, true);
      } else {
        _bulletinVideoController?.dispose();
        _bulletinVideoController = null;
      }
    });
  }

  void _prevNewsItem() {
    setState(() {
      currentNewsIndex = (currentNewsIndex - 1 + newsBulletinList.length) % newsBulletinList.length;
      topHeadlineText = newsBulletinList[currentNewsIndex].title;
      headlineCtrl.text = topHeadlineText;
      if (newsBulletinList[currentNewsIndex].mediaPath.isNotEmpty && newsBulletinList[currentNewsIndex].isVideo) {
        _startBulletinMedia(newsBulletinList[currentNewsIndex].mediaPath, true);
      } else {
        _bulletinVideoController?.dispose();
        _bulletinVideoController = null;
      }
    });
  }

  Future<void> _pickBulletinMedia() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.amber),
                title: const Text('గ్యాలరీ నుండి MP4 వీడియో ఎంచుకోండి', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
                  if (video != null && mounted) {
                    setState(() {
                      newsBulletinList[currentNewsIndex].mediaPath = video.path;
                      newsBulletinList[currentNewsIndex].isVideo = true;
                    });
                    _startBulletinMedia(video.path, true);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.cyanAccent),
                title: const Text('గ్యాలరీ నుండి JPEG / GIF ఇమేజ్ ఎంచుకోండి', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
                  if (image != null && mounted) {
                    setState(() {
                      newsBulletinList[currentNewsIndex].mediaPath = image.path;
                      newsBulletinList[currentNewsIndex].isVideo = false;
                      _bulletinVideoController?.dispose();
                      _bulletinVideoController = null;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickBreakingNewsLogo() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (image != null && mounted) {
      setState(() {
        breakingNewsLogoPath = image.path; 
      });
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
              title: const Text("న్యూస్ బులెటిన్ మేనేజర్", style: TextStyle(color: Colors.white, fontSize: 14)),
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
                          labelText: "కొత్త బులెటిన్ హెడ్‌లైన్ టెక్స్ట్",
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                        onPressed: () async {
                          final XFile? media = await _picker.pickVideo(source: ImageSource.gallery);
                          if (media != null && newTitleCtrl.text.isNotEmpty) {
                            setState(() {
                              newsBulletinList.add(NewsBulletinItem(title: newTitleCtrl.text, mediaPath: media.path, isVideo: true));
                              customHeadlines.add(newTitleCtrl.text);
                              currentNewsIndex = newsBulletinList.length - 1;
                              topHeadlineText = newsBulletinList[currentNewsIndex].title;
                              headlineCtrl.text = topHeadlineText;
                            });
                            newTitleCtrl.clear();
                            Navigator.pop(context);
                            _startBulletinMedia(media.path, true);
                          }
                        },
                        icon: const Icon(Icons.video_library, color: Colors.black),
                        label: const Text("కొత్త న్యూస్ & వీడియో జోడించు", style: TextStyle(color: Colors.black)),
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
                          Expanded(
                            child: Text(
                              videoAdsList[index].isEmpty ? "మీడియా లేదు" : "ఫైల్ అటాచ్ అయింది",
                              style: const TextStyle(color: Colors.yellow, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.video_library, color: Colors.cyan, size: 22),
                            onPressed: () async {
                              final XFile? media = await _picker.pickVideo(source: ImageSource.gallery);
                              if (media != null) {
                                setDialogState(() { videoAdsList[index] = media.path; });
                                setState(() { videoAdsList[index] = media.path; });
                              }
                            },
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(40, 30)),
                            onPressed: () {
                              Navigator.pop(context);
                              _playVideoAd(videoAdsList[index]);
                            },
                            child: const Text("Play", style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    );
                  },
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

  void _showQrGeneratorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("PCR QR కోడ్ జనరేటర్", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qrDataController,
                style: const TextStyle(color: Colors.yellow),
                decoration: const InputDecoration(labelText: "లైవ్ లింక్", labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.white,
                child: QrImageView(data: qrDataController.text, version: QrVersions.auto, size: 150.0),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white))),
          ],
        );
      },
    );
  }

  void _showIpInputDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("IP / Stream Link సెట్టింగ్స్", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: ipController,
            style: const TextStyle(color: Colors.yellow),
            decoration: const InputDecoration(labelText: "RTSP / HTTP లింక్", labelStyle: TextStyle(color: Colors.white54)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() { ipCameraUrl = ipController.text; });
                Navigator.pop(context);
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showMultiStreamDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("Restream & YouTube Multi-Live సెటప్", style: TextStyle(color: Colors.white, fontSize: 14)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: youtubeUrlController,
                  style: const TextStyle(color: Colors.yellow, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: "RTMP URL (ఉదా: rtmp://bangalore.restream.io/live)",
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: restreamKeyController,
                  style: const TextStyle(color: Colors.yellow, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: "Stream Key",
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isLiveBroadcasting ? Colors.green : Colors.red),
              onPressed: () async {
                if (controller == null || controller!.value.isInitialized != true) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("కెమెరా ఇంకా సిద్ధంగా లేదు. దయచేసి కొన్ని సెకన్లు ఆగండి!"), backgroundColor: Colors.red),
                  );
                  return;
                }

                Navigator.pop(context);
                
                String rtmpUrl = youtubeUrlController.text.trim();
                String streamKey = restreamKeyController.text.trim();

                if (rtmpUrl.isEmpty || streamKey.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("దయచేసి RTMP URL మరియు Stream Key సరిగ్గా ఇవ్వండి!"), backgroundColor: Colors.red),
                  );
                  return;
                }

                String fullRtmpUrl = rtmpUrl.endsWith('/') ? "$rtmpUrl$streamKey" : "$rtmpUrl/$streamKey";

                try {
                  if (!isLiveBroadcasting) {
                    await controller?.startVideoStreaming(fullRtmpUrl);
                    setState(() { isLiveBroadcasting = true; });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Multi-Live బ్రాడ్‌కాస్ట్ విజయవంతంగా ప్రారంభమైంది! Restream లో లైవ్ చూడండి."), backgroundColor: Colors.green),
                    );
                  } else {
                    await controller?.stopVideoStreaming();
                    setState(() { isLiveBroadcasting = false; });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Multi-Live ఆపివేయబడింది!"), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  debugPrint("Streaming Error: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("బ్రాడ్‌కాస్ట్ ఎర్రర్: $e"), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text(isLiveBroadcasting ? "Stop Live" : "Start Multi-Live", style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
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
                        final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
                        if (image != null) setDialogState(() { channelLogoPath = image.path; });
                      },
                      icon: const Icon(Icons.upload),
                      label: const Text("ఛానల్ లోగో (JPEG/GIF) అప్లోడ్ చేయి"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: headlineCtrl,
                      style: const TextStyle(color: Colors.yellow),
                      decoration: const InputDecoration(labelText: "కొత్త హెడ్‌లైన్ టైప్ చేయండి"),
                    ),
                    const SizedBox(height: 5),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      onPressed: () {
                        if (headlineCtrl.text.trim().isNotEmpty) {
                          setState(() {
                            customHeadlines.add(headlineCtrl.text.trim());
                            topHeadlineText = headlineCtrl.text.trim();
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

  @override
  Widget build(BuildContext context) {
    bool isScreenLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    Widget cameraWidget = isIpCameraActive && _vlcViewController != null
        ? VlcPlayer(controller: _vlcViewController!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.red)))
        : (controller != null && (controller!.value.isInitialized == true)
            ? LayoutBuilder(
                builder: (context, constraints) {
                  var cameraValue = controller!.value;
                  return ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: isScreenLandscape ? constraints.maxHeight * cameraValue.aspectRatio : constraints.maxWidth,
                          height: isScreenLandscape ? constraints.maxHeight : constraints.maxWidth / cameraValue.aspectRatio,
                          child: CameraPreview(controller!),
                        ),
                      ),
                    ),
                  );
                },
              )
            : const Center(child: CircularProgressIndicator(color: Colors.white)));

    Widget reporterBadgeWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (watermarkText.isNotEmpty) 
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(watermarkText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0)),
          ),
        Container(
          color: Colors.red.shade700, 
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), 
          child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0)),
        ),
        const SizedBox(height: 2), 
        Container(
          color: Colors.white, 
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
          child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13.0)),
        ),
        Container(
          color: Colors.red.shade700, 
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), 
          child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0)),
        ),
      ],
    );

    Widget visualScreenLogoWidget = Positioned(
      top: 15, right: 15, 
      child: channelLogoPath.isNotEmpty
          ? SizedBox(
              width: logoWidth,
              height: logoHeight,
              child: Image.file(File(channelLogoPath), fit: BoxFit.contain, filterQuality: FilterQuality.high),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
              color: Colors.blue[900]?.withOpacity(0.9), 
              child: const Text("SS YATRA TV", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
    );

    return WillPopScope(
      onWillPop: () async {
        if (isNewsBulletinMode) {
          setState(() {
            isNewsBulletinMode = false;
            hideControls = false;
          });
          return false;
        } else if (!hideControls) {
          setState(() {
            hideControls = true;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () { 
                  setState(() { 
                    hideControls = !hideControls; 
                  }); 
                },
                child: isNewsBulletinMode
                    ? Container(
                        color: Colors.black,
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.zero,
                              padding: EdgeInsets.only(
                                top: MediaQuery.of(context).padding.top > 0 ? MediaQuery.of(context).padding.top : 8,
                                bottom: 12,
                                left: 15,
                                right: 15,
                              ),
                              color: Colors.red.shade900,
                              child: Text(
                                topHeadlineText,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 55.0, left: 6, right: 6, top: 6), 
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.amberAccent, width: 2.5),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(child: cameraWidget),
                                              Positioned(bottom: 10, left: 10, child: reporterBadgeWidget),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            showVideoControls = !showVideoControls;
                                          });
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.cyanAccent, width: 2.5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: newsBulletinList[currentNewsIndex].mediaPath.isNotEmpty
                                                      ? (!newsBulletinList[currentNewsIndex].isVideo
                                                          ? Image.file(
                                                              File(newsBulletinList[currentNewsIndex].mediaPath),
                                                              fit: BoxFit.cover,
                                                              width: double.infinity,
                                                              height: double.infinity,
                                                            )
                                                          : (_bulletinVideoController != null && _bulletinVideoController!.value.isInitialized
                                                              ? FittedBox(
                                                                  fit: BoxFit.cover,
                                                                  child: SizedBox(
                                                                    width: _bulletinVideoController!.value.size.width,
                                                                    height: _bulletinVideoController!.value.size.height,
                                                                    child: VideoPlayer(_bulletinVideoController!),
                                                                  ),
                                                                )
                                                              : Container(
                                                                  color: Colors.black,
                                                                  child: const Center(child: CircularProgressIndicator(color: Colors.amber)),
                                                                )))
                                                      : Container(
                                                          color: Colors.black, 
                                                          child: Center(
                                                            child: ElevatedButton.icon(
                                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                                              onPressed: _pickBulletinMedia,
                                                              icon: const Icon(Icons.perm_media),
                                                              label: const Text("గ్యాలరీ నుండి MP4 / JPEG / GIF ఎంచుకోండి"),
                                                            ),
                                                          ),
                                                        ),
                                                ),
                                                visualScreenLogoWidget,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : (isVideoAdPlaying && _videoAdVlcController != null)
                        ? Container(
                            color: Colors.black,
                            child: VlcPlayer(
                              controller: _videoAdVlcController!,
                              aspectRatio: 16 / 9,
                              placeholder: const Center(child: CircularProgressIndicator(color: Colors.amber)),
                            ),
                          )
                        : Stack(
                            children: [
                              Positioned.fill(child: cameraWidget),
                              visualScreenLogoWidget,
                            ],
                          ),
              ),
            ),

            if (!isNewsBulletinMode)
              Positioned(
                bottom: 65, 
                left: 15, 
                child: reporterBadgeWidget,
              ),
            
            Positioned(
              bottom: 0, 
              left: 0, 
              right: 0, 
              child: Container(
                height: 55, 
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  border: Border.all(color: Colors.amber.shade400, width: 1.5),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickBreakingNewsLogo,
                      child: Container(
                        width: 55,
                        height: double.infinity,
                        color: Colors.black,
                        child: breakingNewsLogoPath.isNotEmpty
                            ? Image.file(File(breakingNewsLogoPath), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                            : const Center(
                                child: Icon(Icons.newspaper, color: Colors.amber, size: 28),
                              ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Marquee(
                          text: breakingNewsText, 
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), 
                          blankSpace: 100.0, 
                          velocity: 40.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (!hideControls)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      hideControls = true;
                    });
                  },
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {}, 
                        child: Wrap(
                          alignment: WrapAlignment.center, spacing: 15, runSpacing: 15,
                          children: [
                            _buildControlButton(Icons.flip_camera_android, "Phone Cam", _switchCamera, Colors.white),
                            _buildControlButton(Icons.wifi_tethering, "IP Cam", _toggleIpCamera, isIpCameraActive ? Colors.green : Colors.orange),
                            _buildControlButton(Icons.video_library, "Media Ads", _showAdsManagerDialog, Colors.amberAccent),
                            _buildControlButton(Icons.qr_code_2, "QR Gen", _showQrGeneratorDialog, Colors.tealAccent),
                            _buildControlButton(Icons.edit, "Logo & Edit", _showEditDialog, Colors.blue),
                            _buildControlButton(Icons.settings_ethernet, "Set IP", _showIpInputDialog, Colors.cyan),
                            _buildControlButton(Icons.live_tv, "Multi-Live", _showMultiStreamDialog, isLiveBroadcasting ? Colors.green : Colors.redAccent),
                            _buildControlButton(
                              isNewsBulletinMode ? Icons.newspaper : Icons.featured_play_list, 
                              isNewsBulletinMode ? "Exit Bulletin" : "News Bulletin", 
                              _toggleNewsBulletinMode, 
                              isNewsBulletinMode ? Colors.cyanAccent : Colors.pinkAccent,
                            ),
                            _buildControlButton(Icons.playlist_add, "Bulletin Mgr", _showBulletinManagerDialog, Colors.amber),
                            _buildControlButton(
                              isAnimatedAdsMode ? Icons.fullscreen : Icons.timer, 
                              isAnimatedAdsMode ? "Ads Active" : "Auto Timer Ads", 
                              _toggleAutoTimerAds, 
                              isAnimatedAdsMode ? Colors.greenAccent : Colors.amber,
                            ),
                            _buildControlButton(Icons.screen_rotation, "Rotate", _toggleRotation, Colors.purple),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
