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

class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> with WidgetsBindingObserver {
  CameraController? controller;
  VlcPlayerController? _vlcViewController;
  VlcPlayerController? _videoAdVlcController; 
  
  bool hideControls = false;
  int currentCameraIndex = 0;
  bool isLandscape = false;
  bool isIpCameraActive = false;
  bool isLiveBroadcasting = false;
  bool isLBandMode = false; 
  bool isAutoTimerActive = false; 
  bool isVideoAdPlaying = false; 

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  double _baseScale = 1.0;

  String ipCameraUrl = ""; 
  TextEditingController ipController = TextEditingController();
  TextEditingController qrDataController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Color lShapeColor = const Color(0xFF95C8F2);
  
  // 🔥 L-Shape JPEG/GIF పాత్స్
  String verticalAdImagePath = "";
  String horizontalAdImagePath = "";
  
  // 🔥 L-Shape సైజులు మరియు ఇమేజ్ ఫిట్ అడ్జస్ట్మెంట్ (Padding/Scale)
  double verticalAdWidth = 130.0;
  double landscapeVerticalWidth = 200.0;
  double horizontalAdHeight = 130.0;
  double landscapeHorizontalHeight = 100.0;

  double verticalImagePadding = 0.0; // నిలువు ఇమేజ్ అంచుల సర్దుబాటు కోసం
  double horizontalImagePadding = 0.0; // అడ్డు ఇమేజ్ అంచుల సర్దుబాటు కోసం

  int verticalAdRotationTurns = 0; 
  int horizontalAdRotationTurns = 0;

  String lShapeCustomText = "SS YATRA TV - L-SHAPE AD BANNER";
  TextEditingController lShapeTextCtrl = TextEditingController();

  final List<String> videoAdsList = List.generate(10, (index) => index == 0 ? "https://www.quirksmode.org/html5/videos/big_buck_bunny.mp4" : "");

  String channelLogoPath = "";
  double logoWidth = 70.0;
  double logoHeight = 70.0;
  String newsBadgeImagePath = ""; 

  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA"; 
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String stateNews = "తెలంగాణ తాజా వార్తలు లోడ్ అవుతున్నాయి...";
  String googleNews = "జాతీయ వార్తలు లోడ్ అవుతున్నాయి...";

  TextEditingController rtmpUrlController = TextEditingController();
  TextEditingController watermarkCtrl = TextEditingController();
  TextEditingController locCtrl = TextEditingController();
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController roleCtrl = TextEditingController();
  TextEditingController newsCtrl = TextEditingController();

  Timer? _newsTimer;
  Timer? _telanganaNewsTimer;
  Timer? _lBandAutoTimer; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    watermarkCtrl.text = watermarkText;
    locCtrl.text = locationText;
    nameCtrl.text = reporterName;
    roleCtrl.text = reporterRole;
    newsCtrl.text = stateNews;
    lShapeTextCtrl.text = lShapeCustomText;
    qrDataController.text = "http://192.168.1.100:8081/video";
    rtmpUrlController.text = "rtmp://live.restream.io/live/your_stream_key_here";

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    
    _initCamera();
    _requestPermissions();
    _fetchGoogleNews(); 
    _fetchTelanganaNews(); 
    
    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _fetchGoogleNews();
    });

    _telanganaNewsTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _fetchTelanganaNews();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller == null || !controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newsTimer?.cancel();
    _telanganaNewsTimer?.cancel();
    _lBandAutoTimer?.cancel();
    controller?.dispose();
    _vlcViewController?.dispose();
    _videoAdVlcController?.dispose();
    ipController.dispose();
    qrDataController.dispose();
    lShapeTextCtrl.dispose();
    rtmpUrlController.dispose();
    watermarkCtrl.dispose();
    locCtrl.dispose();
    nameCtrl.dispose();
    roleCtrl.dispose();
    newsCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone, Permission.storage].request();
  }

  void _initCamera() async {
    if (cameras.isEmpty) return;
    try {
      await controller?.dispose();
      controller = CameraController(
        cameras[currentCameraIndex],
        ResolutionPreset.max,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller!.initialize();
      _minZoomLevel = await controller!.getMinZoomLevel();
      _maxZoomLevel = await controller!.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;
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
    _initCamera();
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
        options: VlcPlayerOptions(),
      );
      setState(() { isIpCameraActive = true; });
    }
  }

  void _playVideoAd(String videoUrl) {
    if (videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఈ స్లాట్‌లో వీడియో యాడ్ లేదు!"), backgroundColor: Colors.red));
      return;
    }

    _videoAdVlcController?.stopRendererScanning();
    _videoAdVlcController?.dispose();

    final VlcPlayerOptions options = VlcPlayerOptions(
      advanced: VlcAdvancedOptions([
        VlcAdvancedOptions.networkCaching(2000),
      ]),
    );

    if (videoUrl.startsWith('http://') || videoUrl.startsWith('https://')) {
      _videoAdVlcController = VlcPlayerController.network(
        videoUrl,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: options,
      );
    } else {
      _videoAdVlcController = VlcPlayerController.file(
        File(videoUrl),
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: options,
      );
    }

    setState(() {
      isVideoAdPlaying = true;
    });
  }

  void _stopVideoAd() {
    _videoAdVlcController?.stopRendererScanning();
    _videoAdVlcController?.dispose();
    setState(() {
      isVideoAdPlaying = false;
      _videoAdVlcController = null;
    });
  }

  Future<void> _fetchGoogleNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = [];
        for (var item in items.take(15)) {
          titles.add(item.findElements('title').first.innerText);
        }
        if (titles.isNotEmpty && mounted) setState(() { googleNews = titles.join("   ♦   "); });
      }
    } catch (e) {
      debugPrint("News Error: $e");
    }
  }

  Future<void> _fetchTelanganaNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss/search?q=Telangana+news&hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = [];
        for (var item in items.take(15)) {
          titles.add(item.findElements('title').first.innerText);
        }
        if (titles.isNotEmpty && mounted) {
          setState(() { 
            stateNews = titles.join("   ♦   "); 
          });
        }
      }
    } catch (e) {
      debugPrint("Telangana News Error: $e");
    }
  }

  void _showAdsManagerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("10 ఫుల్ హెచ్‌డి వీడియో యాడ్స్ మేనేజర్", style: TextStyle(color: Colors.white, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    TextEditingController adCtrl = TextEditingController(text: videoAdsList[index]);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Text("Ad ${index + 1}:", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: TextField(
                              controller: adCtrl,
                              style: const TextStyle(color: Colors.yellow, fontSize: 11),
                              decoration: const InputDecoration(hintText: "డైరెక్ట్ MP4 లింక్ లేదా గ్యాలరీ పాత్", hintStyle: TextStyle(color: Colors.white38)),
                              onChanged: (val) { videoAdsList[index] = val; },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.video_library, color: Colors.cyan, size: 20),
                            onPressed: () async {
                              final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
                              if (video != null) {
                                setDialogState(() {
                                  videoAdsList[index] = video.path;
                                });
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

  // 🔥 L-Shape యాడ్స్ సైజులు, JPEG/GIF అప్‌లోడ్ మరియు అంచులు (Padding/Fit) అడ్జస్ట్ చేసే డైలాగ్
  void _showLBandImagesManagerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isLandscapeMode = MediaQuery.of(context).orientation == Orientation.landscape;
            double curVWidth = isLandscapeMode ? landscapeVerticalWidth : verticalAdWidth;
            double curHHeight = isLandscapeMode ? landscapeHorizontalHeight : horizontalAdHeight;

            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("L-Shape JPEG/GIF అంచులు & సైజులు", style: TextStyle(color: Colors.white, fontSize: 14)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("బ్యాక్‌గ్రౌండ్ కలర్:", style: TextStyle(color: Colors.yellow, fontSize: 12)),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _colorOptionButton(setDialogState, const Color(0xFF95C8F2), "Sky Blue"),
                        _colorOptionButton(setDialogState, Colors.blue[800]!, "Dark Blue"),
                        _colorOptionButton(setDialogState, Colors.orange[800]!, "Orange"),
                        _colorOptionButton(setDialogState, Colors.red[800]!, "Red"),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 20),

                    // 1. నిలువు (Vertical) JPEG/GIF & అంచుల అడ్జస్ట్‌మెంట్
                    const Text("1. నిలువు (Vertical) JPEG/GIF బాక్స్:", style: TextStyle(color: Colors.yellow, fontSize: 12)),
                    Text("వెడల్పు: ${curVWidth.toInt()} px", style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                    Slider(
                      value: curVWidth, min: 80, max: 300, activeColor: Colors.blue,
                      onChanged: (val) {
                        setDialogState(() {
                          if (isLandscapeMode) { landscapeVerticalWidth = val; } else { verticalAdWidth = val; }
                        });
                        setState(() {});
                      },
                    ),
                    const Text("నిలువు ఇమేజ్ అంచులు (Padding/Scale):", style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Slider(
                      value: verticalImagePadding, min: 0.0, max: 40.0, activeColor: Colors.amber,
                      onChanged: (val) {
                        setDialogState(() { verticalImagePadding = val; });
                        setState(() { verticalImagePadding = val; });
                      },
                    ),
                    Row(
                      children: [
                        Expanded(child: Text(verticalAdImagePath.isEmpty ? "ఫైల్ లేదు" : "JPEG/GIF అటాచ్ అయింది", style: const TextStyle(color: Colors.white70, fontSize: 10))),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(80, 30)),
                          onPressed: () async {
                            final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
                            if (image != null) {
                              setDialogState(() { verticalAdImagePath = image.path; });
                            }
                          },
                          icon: const Icon(Icons.upload, size: 14),
                          label: const Text("Upload", style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),

                    const Divider(color: Colors.white24, height: 20),

                    // 2. అడ్డు (Horizontal) JPEG/GIF & అంచుల అడ్జస్ట్‌మెంట్
                    const Text("2. అడ్డు (Horizontal) JPEG/GIF బ్యానర్:", style: TextStyle(color: Colors.yellow, fontSize: 12)),
                    Text("ఎత్తు: ${curHHeight.toInt()} px", style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                    Slider(
                      value: curHHeight, min: 60, max: 220, activeColor: Colors.blue,
                      onChanged: (val) {
                        setDialogState(() {
                          if (isLandscapeMode) { landscapeHorizontalHeight = val; } else { horizontalAdHeight = val; }
                        });
                        setState(() {});
                      },
                    ),
                    const Text("అడ్డు ఇమేజ్ అంచులు (Padding/Scale):", style: TextStyle(color: Colors.white54, fontSize: 10)),
                    Slider(
                      value: horizontalImagePadding, min: 0.0, max: 40.0, activeColor: Colors.amber,
                      onChanged: (val) {
                        setDialogState(() { horizontalImagePadding = val; });
                        setState(() { horizontalImagePadding = val; });
                      },
                    ),
                    Row(
                      children: [
                        Expanded(child: Text(horizontalAdImagePath.isEmpty ? "ఫైల్ లేదు" : "JPEG/GIF అటాచ్ అయింది", style: const TextStyle(color: Colors.white70, fontSize: 10))),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(80, 30)),
                          onPressed: () async {
                            final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
                            if (image != null) {
                              setDialogState(() { horizontalAdImagePath = image.path; });
                            }
                          },
                          icon: const Icon(Icons.upload, size: 14),
                          label: const Text("Upload", style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    setState(() { isLBandMode = true; });
                    Navigator.pop(context);
                  },
                  child: const Text("Apply L-Shape", style: TextStyle(color: Colors.white)),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white))),
              ],
            );
          },
        );
      },
    );
  }

  Widget _colorOptionButton(StateSetter setDialogState, Color color, String name) {
    return GestureDetector(
      onTap: () {
        setDialogState(() { lShapeColor = color; });
        setState(() { lShapeColor = color; });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.white, width: lShapeColor == color ? 2 : 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(name, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
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
                decoration: const InputDecoration(labelText: "స్ట్రీమ్ లింక్ / IP అడ్రస్", labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(10),
                color: Colors.white,
                child: QrImageView(
                  data: qrDataController.text.isNotEmpty ? qrDataController.text : "https://ssyatratv.com",
                  version: QrVersions.auto,
                  size: 180.0,
                ),
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
          title: const Text("IP / Stream Link & QR సెట్టింగ్స్", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipController,
                style: const TextStyle(color: Colors.yellow),
                decoration: const InputDecoration(labelText: "RTSP / HTTP లింక్", labelStyle: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() { ipCameraUrl = ipController.text; });
                Navigator.pop(context);
                if (isIpCameraActive) {
                  _toggleIpCamera();
                  Future.delayed(const Duration(milliseconds: 500), () => _toggleIpCamera());
                } else {
                  _toggleIpCamera();
                }
              },
              child: const Text("Save & Start", style: TextStyle(color: Colors.white)),
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
              title: const Text("ఛానల్ లోగో & న్యూస్ బ్యాడ్జ్ ఎడిట్", style: TextStyle(color: Colors.white, fontSize: 13)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("1. ఛానల్ లోగో (Image/GIF):", style: TextStyle(color: Colors.yellow, fontSize: 12)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(channelLogoPath.isEmpty ? "లోగో లేదు" : "లోగో అటాచ్ చేయబడింది", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, minimumSize: const Size(80, 30)),
                          onPressed: () async {
                            final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
                            if (image != null) {
                              setDialogState(() { channelLogoPath = image.path; });
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 14),
                          label: const Text("Upload", style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text("లోగో వెడల్పు & ఎత్తు:", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Slider(
                      value: logoWidth, min: 40, max: 150, activeColor: Colors.blue,
                      onChanged: (val) {
                        setDialogState(() { logoWidth = val; });
                        setState(() { logoWidth = val; });
                      },
                    ),

                    const Divider(color: Colors.white24, height: 20),
                    const Text("2. న్యూస్ బ్యాడ్జ్ (JPEG/GIF):", style: TextStyle(color: Colors.yellow, fontSize: 12)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(newsBadgeImagePath.isEmpty ? "బ్యాడ్జ్ లేదు" : "బ్యాడ్జ్ అటాచ్ అయింది", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, minimumSize: const Size(80, 30)),
                          onPressed: () async {
                            final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
                            if (image != null) {
                              setDialogState(() { newsBadgeImagePath = image.path; });
                            }
                          },
                          icon: const Icon(Icons.image, size: 14),
                          label: const Text("Badge", style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),

                    const Divider(color: Colors.white24, height: 20),
                    TextField(controller: watermarkCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "వాటర్ మార్క్ టెక్స్ట్", labelStyle: TextStyle(color: Colors.white54))),
                    TextField(controller: locCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "లొకేషన్", labelStyle: TextStyle(color: Colors.white54))),
                    TextField(controller: nameCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "రిపోర్టర్ పేరు", labelStyle: TextStyle(color: Colors.white54))),
                    TextField(controller: roleCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "రిపోర్టర్ హోదా", labelStyle: TextStyle(color: Colors.white54))),
                    TextField(controller: newsCtrl, style: const TextStyle(color: Colors.yellow), maxLines: 2, decoration: const InputDecoration(labelText: "స్టేట్ న్యూస్ (మాన్యువల్ ఓవర్‌రైడ్)", labelStyle: TextStyle(color: Colors.white54))),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    setState(() {
                      watermarkText = watermarkCtrl.text;
                      locationText = locCtrl.text;
                      reporterName = nameCtrl.text;
                      reporterRole = roleCtrl.text;
                      if(newsCtrl.text.isNotEmpty) {
                        stateNews = newsCtrl.text;
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Save", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMultiStreamDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("డైరెక్ట్ RTMP / Restream లైవ్ సెటప్", style: TextStyle(color: Colors.white, fontSize: 14)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("మీ Restream.io లేదా YouTube కస్టమ్ RTMP లింక్‌ని ఇక్కడ ఇవ్వండి.", style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 15),
                    TextField(
                      controller: rtmpUrlController,
                      style: const TextStyle(color: Colors.yellow, fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: "RTMP Server URL & Stream Key",
                        labelStyle: TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: isLiveBroadcasting ? Colors.green : Colors.red),
                  onPressed: () {
                    setState(() { isLiveBroadcasting = !isLiveBroadcasting; });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isLiveBroadcasting ? "లైవ్ ప్రారంభమైంది!" : "లైవ్ ఆపివేయబడింది!"), backgroundColor: isLiveBroadcasting ? Colors.green : Colors.orange),
                    );
                  },
                  child: Text(isLiveBroadcasting ? "Stop Live" : "Start Live", style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleAutoTimerAds() {
    setState(() { isAutoTimerActive = !isAutoTimerActive; });
    if (isAutoTimerActive) {
      _lBandAutoTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
        setState(() { isLBandMode = true; }); 
        Timer(const Duration(minutes: 1), () { if (mounted) { setState(() { isLBandMode = false; }); } });
      });
    } else {
      _lBandAutoTimer?.cancel();
    }
  }

  void _toggleRotation() {
    setState(() {
      isLandscape = !isLandscape;
      if (isLandscape) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isScreenLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    double currentVerticalWidth = isScreenLandscape ? landscapeVerticalWidth : verticalAdWidth;
    double currentHorizontalHeight = isScreenLandscape ? landscapeHorizontalHeight : horizontalAdHeight;

    Widget cameraWidget = isIpCameraActive && _vlcViewController != null
        ? VlcPlayer(controller: _vlcViewController!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.red)))
        : (controller != null && controller!.value.isInitialized 
            ? Listener(
                onPointerSignal: (pointerSignal) {},
                child: GestureDetector(
                  onScaleStart: (details) { _baseScale = _currentZoomLevel; },
                  onScaleUpdate: (details) async {
                    if (controller == null) return;
                    double zoom = _baseScale * details.scale;
                    if (zoom < _minZoomLevel) zoom = _minZoomLevel;
                    if (zoom > _maxZoomLevel) zoom = _maxZoomLevel;
                    setState(() { _currentZoomLevel = zoom; });
                    await controller?.setZoomLevel(zoom);
                  },
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: controller!.value.previewSize?.width ?? 1080,
                        height: controller!.value.previewSize?.height ?? 1920,
                        child: CameraPreview(controller!),
                      ),
                    ),
                  ),
                ),
              )
            : const Center(child: CircularProgressIndicator(color: Colors.white)));

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () { setState(() { hideControls = !hideControls; }); },
        child: Stack(
          children: [
            if (isVideoAdPlaying && _videoAdVlcController != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: VlcPlayer(
                    controller: _videoAdVlcController!,
                    aspectRatio: 16 / 9,
                    placeholder: const Center(child: CircularProgressIndicator(color: Colors.amber)),
                  ),
                ),
              )
            else if (!isLBandMode)
              Positioned.fill(child: cameraWidget)
            else
              Positioned.fill(
                child: Container(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0, left: currentVerticalWidth, right: 0, bottom: currentHorizontalHeight,
                        child: SizedBox.expand(child: ClipRect(child: cameraWidget)),
                      ),
                      // నిలువు L-Shape బాక్స్ (అంచులు/Padding అడ్జస్ట్ చేసేలా)
                      Positioned(
                        left: 0, top: 0, bottom: 0, width: currentVerticalWidth,
                        child: Container(
                          color: lShapeColor,
                          padding: EdgeInsets.all(verticalImagePadding),
                          child: Center(
                            child: verticalAdImagePath.isNotEmpty
                                ? Image.file(File(verticalAdImagePath), fit: BoxFit.fill, width: double.infinity, height: double.infinity)
                                : const Text("VERTICAL AD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          ),
                        ),
                      ),
                      // అడ్డు L-Shape బ్యానర్ (అంచులు/Padding అడ్జస్ట్ చేసేలా)
                      Positioned(
                        left: 0, right: 0, bottom: 0, height: currentHorizontalHeight,
                        child: Container(
                          color: lShapeColor,
                          padding: EdgeInsets.all(horizontalImagePadding),
                          alignment: Alignment.center,
                          child: Center(
                            child: horizontalAdImagePath.isNotEmpty
                                ? Image.file(File(horizontalAdImagePath), fit: BoxFit.fill, width: double.infinity, height: double.infinity)
                                : Text(lShapeCustomText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (isVideoAdPlaying)
              Positioned(
                top: 40, right: 40,
                child: FloatingActionButton.extended(
                  backgroundColor: Colors.red,
                  onPressed: _stopVideoAd,
                  label: const Text("Close Ad & Resume", style: TextStyle(color: Colors.white)),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),

            Positioned(
              top: 30, right: 30, 
              child: channelLogoPath.isNotEmpty
                  ? SizedBox(
                      width: logoWidth,
                      height: logoHeight,
                      child: Image.file(File(channelLogoPath), fit: BoxFit.contain, filterQuality: FilterQuality.high),
                    )
                  : Container(
                      padding: const EdgeInsets.all(8), 
                      color: Colors.blue[900]?.withOpacity(0.8), 
                      child: const Text("SS YATRA TV", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
            ),

            Positioned(
              bottom: isLBandMode ? currentHorizontalHeight + 15 : 95, 
              left: isLBandMode ? currentVerticalWidth + 15 : 15, 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (watermarkText.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 5, left: 2), child: Text(watermarkText, style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 13.0))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), color: Colors.red, child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.0))),
                  const SizedBox(height: 4), 
                  Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14.0))),
                  Container(color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontSize: 12.0))),
                ],
              ),
            ),
            
            // న్యూస్ స్క్రోలింగ్ బార్ (ఎడమ వైపు JPEG/GIF బ్యాడ్జ్‌తో సహా)
            Positioned(
              bottom: 5, left: 5, right: 5, 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isLBandMode)
                    Container(
                      height: 32, 
                      color: Colors.blue.shade900, 
                      child: Row(
                        children: [
                          Container(
                            color: Colors.yellow.shade800,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            child: newsBadgeImagePath.isNotEmpty
                                ? Image.file(File(newsBadgeImagePath), fit: BoxFit.contain, width: 70)
                                : const Text("BREAKING", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Marquee(
                                text: googleNews, 
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), 
                                blankSpace: 100.0, 
                                velocity: 35.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 2),
                  Container(
                    height: 38, 
                    color: Colors.red.shade900, 
                    child: Row(
                      children: [
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          child: newsBadgeImagePath.isNotEmpty
                              ? Image.file(File(newsBadgeImagePath), fit: BoxFit.contain, width: 70)
                              : const Text("LIVE NEWS", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Marquee(
                              text: stateNews, 
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), 
                              blankSpace: 50.0, 
                              velocity: 42.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                        _buildControlButton(Icons.video_library, "Video Ads", _showAdsManagerDialog, Colors.amberAccent),
                        _buildControlButton(Icons.qr_code_2, "QR Gen", _showQrGeneratorDialog, Colors.tealAccent),
                        _buildControlButton(Icons.edit, "Logo & Edit", _showEditDialog, Colors.blue),
                        _buildControlButton(Icons.settings_ethernet, "Set IP", _showIpInputDialog, Colors.cyan),
                        _buildControlButton(Icons.live_tv, "Multi-Live", _showMultiStreamDialog, isLiveBroadcasting ? Colors.green : Colors.redAccent),
                        _buildControlButton(
                          isLBandMode ? Icons.fullscreen : Icons.view_sidebar, 
                          isLBandMode ? "Ad Off" : "L-Shape Edit", 
                          () { setState(() { isLBandMode = !isLBandMode; }); if(isLBandMode) _showLBandImagesManagerDialog(); }, 
                          Colors.amber,
                        ),
                        _buildControlButton(
                          isAutoTimerActive ? Icons.timer : Icons.timer_off, 
                          isAutoTimerActive ? "Auto ON" : "Auto OFF", 
                          _toggleAutoTimerAds, 
                          isAutoTimerActive ? Colors.greenAccent : Colors.grey,
                        ),
                        _buildControlButton(Icons.screen_rotation, "Rotate", _toggleRotation, Colors.purple),
                      ],
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
