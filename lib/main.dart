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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const StudioScreen(),
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
  String verticalAdImagePath = "";
  String horizontalAdImagePath = "";
  
  double verticalAdWidth = 110.0;
  double landscapeVerticalWidth = 180.0;
  double horizontalAdHeight = 100.0;
  double landscapeHorizontalHeight = 70.0;

  double verticalAdRotation = 0.0;
  double horizontalAdRotation = 0.0;

  String lShapeCustomText = "SS YATRA TV - L-SHAPE AD BANNER";
  TextEditingController lShapeTextCtrl = TextEditingController();

  final List<String> videoAdsList = List.generate(10, (index) => index == 0 ? "https://www.quirksmode.org/html5/videos/big_buck_bunny.mp4" : "");

  String channelName = "SS\nYATRA\nTV";
  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA"; 
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String stateNews = "కొత్తకోటలో భారీ ర్యాలీ.. ప్రజలతో మంత్రి సమావేశం.. మరిన్ని అప్‌డేట్స్ కోసం చూస్తూనే ఉండండి...";
  String googleNews = "తాజా వార్తలు లోడ్ అవుతున్నాయి... దయచేసి వేచి ఉండండి...";
  
  bool selectYt = false, selectFb = false, selectInsta = false, selectX = false, selectThreads = false, selectSnap = false, selectIptv = false;
  TextEditingController ytCtrl = TextEditingController();
  TextEditingController fbCtrl = TextEditingController();
  TextEditingController instaCtrl = TextEditingController();
  TextEditingController xCtrl = TextEditingController();
  TextEditingController threadsCtrl = TextEditingController();
  TextEditingController snapCtrl = TextEditingController();
  TextEditingController iptvCtrl = TextEditingController();

  TextEditingController channelCtrl = TextEditingController();
  TextEditingController watermarkCtrl = TextEditingController();
  TextEditingController locCtrl = TextEditingController();
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController roleCtrl = TextEditingController();
  TextEditingController newsCtrl = TextEditingController();

  Timer? _newsTimer;
  Timer? _lBandAutoTimer; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    channelCtrl.text = channelName;
    watermarkCtrl.text = watermarkText;
    locCtrl.text = locationText;
    nameCtrl.text = reporterName;
    roleCtrl.text = reporterRole;
    newsCtrl.text = stateNews;
    lShapeTextCtrl.text = lShapeCustomText;
    qrDataController.text = "http://192.168.1.100:8081/video";

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    
    _initCamera();
    _requestPermissions();
    _fetchGoogleNews(); 
    
    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _fetchGoogleNews();
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
    _lBandAutoTimer?.cancel();
    controller?.dispose();
    _vlcViewController?.dispose();
    _videoAdVlcController?.dispose();
    ipController.dispose();
    qrDataController.dispose();
    lShapeTextCtrl.dispose();
    channelCtrl.dispose();
    watermarkCtrl.dispose();
    locCtrl.dispose();
    nameCtrl.dispose();
    roleCtrl.dispose();
    newsCtrl.dispose();
    ytCtrl.dispose();
    fbCtrl.dispose();
    instaCtrl.dispose();
    xCtrl.dispose();
    threadsCtrl.dispose();
    snapCtrl.dispose();
    iptvCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone, Permission.storage].request();
  }

  // 🔥 అత్యుత్తమ HD కెమెరా క్లారిటీ కోసం max రెసొల్యూషన్ సెట్టింగ్
  void _initCamera() async {
    if (cameras.isEmpty) return;
    try {
      await controller?.dispose();
      controller = CameraController(
        cameras[currentCameraIndex],
        ResolutionPreset.max, // అల్ట్రా హెచ్‌డి క్లారిటీ
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

    _videoAdVlcController?.dispose();
    _videoAdVlcController = VlcPlayerController.network(
      videoUrl,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(),
    );

    setState(() {
      isVideoAdPlaying = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ఫుల్ హెచ్‌డి యాడ్ ప్లే అవుతోంది..."), backgroundColor: Colors.orange),
    );
  }

  void _stopVideoAd() {
    _videoAdVlcController?.stopRendererScanning();
    _videoAdVlcController?.dispose();
    setState(() {
      isVideoAdPlaying = false;
      _videoAdVlcController = null;
    });
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
                              decoration: const InputDecoration(hintText: "హెచ్‌డి వీడియో లింక్ / పాత్", hintStyle: TextStyle(color: Colors.white38)),
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

  void _showLBandImagesManagerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isLandscapeMode = MediaQuery.of(context).orientation == Orientation.landscape;
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("L-Shape నిలువు & అడ్డు యాడ్స్ ఎడిటర్", style: TextStyle(color: Colors.white, fontSize: 15)),
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

                    const Text("1. నిలువు (Vertical) యాడ్ JPEG:", style: TextStyle(color: Colors.yellow, fontSize: 12)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(verticalAdImagePath.isEmpty ? "ఇమేజ్ సెలెక్ట్ కాలేదు" : "సెలెక్ట్ చేయబడింది", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ),
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
                    const SizedBox(height: 5),
                    const Text("నిలువు బాక్స్ వెడల్పు (Width):", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Slider(
                      value: isLandscapeMode ? landscapeVerticalWidth : verticalAdWidth,
                      min: 80,
                      max: 300,
                      activeColor: Colors.blue,
                      onChanged: (val) {
                        setDialogState(() {
                          if (isLandscapeMode) {
                            landscapeVerticalWidth = val;
                          } else {
                            verticalAdWidth = val;
                          }
                        });
                        setState(() {});
                      },
                    ),
                    const Text("నిలువు ఇమేజ్ రొటేట్ (Rotate 90°):", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.rotate_left, color: Colors.amber, size: 20),
                          onPressed: () {
                            setDialogState(() { verticalAdRotation -= 1.5708; });
                            setState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.rotate_right, color: Colors.amber, size: 20),
                          onPressed: () {
                            setDialogState(() { verticalAdRotation += 1.5708; });
                            setState(() {});
                          },
                        ),
                        const Text("తిప్పడానికి క్లిక్ చేయండి", style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),

                    const Divider(color: Colors.white24, height: 20),

                    const Text("2. అడ్డు (Horizontal) బాటమ్ యాడ్ JPEG:", style: TextStyle(color: Colors.yellow, fontSize: 12)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(horizontalAdImagePath.isEmpty ? "ఇమేజ్ లేదా డిఫాల్ట్ టెక్స్ట్" : "సెలెక్ట్ చేయబడింది", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ),
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
                    const SizedBox(height: 5),
                    const Text("అడ్డు బ్యానర్ ఎత్తు (Height):", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Slider(
                      value: isLandscapeMode ? landscapeHorizontalHeight : horizontalAdHeight,
                      min: 50,
                      max: 184,
                      activeColor: Colors.blue,
                      onChanged: (val) {
                        setDialogState(() {
                          if (isLandscapeMode) {
                            landscapeHorizontalHeight = val;
                          } else {
                            horizontalAdHeight = val;
                          }
                        });
                        setState(() {});
                      },
                    ),
                    const Text("బాటమ్ టెక్స్ట్ (ఇమేజ్ లేకపోతే):", style: TextStyle(color: Colors.white54, fontSize: 11)),
                    TextField(
                      controller: lShapeTextCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      decoration: const InputDecoration(hintText: "టెక్స్ట్ రాయండి", hintStyle: TextStyle(color: Colors.white38)),
                      onChanged: (val) {
                        setState(() { lShapeCustomText = val; });
                      },
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
              const Text("మీ ఛానల్ లేదా స్టూడియో లింక్ కోసం QR కోడ్:", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 10),
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
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("QR స్కానర్ యాక్టివేట్ అయింది!"), backgroundColor: Colors.green));
                    },
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 16),
                    label: const Text("Scan", style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                    onPressed: () {
                      Navigator.pop(context);
                      _showQrGeneratorDialog();
                    },
                    icon: const Icon(Icons.qr_code, color: Colors.white, size: 16),
                    label: const Text("Generate QR", style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
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
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("గ్రాఫిక్స్ ఎడిట్ చేయండి", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: channelCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "ఛానల్ పేరు", labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: watermarkCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "వాటర్ మార్క్", labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: locCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "లొకేషన్", labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "రిపోర్టర్ పేరు", labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: roleCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "రిపోర్టర్ హోదా", labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: newsCtrl, style: const TextStyle(color: Colors.yellow), maxLines: 2, decoration: const InputDecoration(labelText: "స్టేట్ న్యూస్", labelStyle: TextStyle(color: Colors.white54))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() {
                  channelName = channelCtrl.text;
                  watermarkText = watermarkCtrl.text;
                  locationText = locCtrl.text;
                  reporterName = nameCtrl.text;
                  reporterRole = roleCtrl.text;
                  stateNews = newsCtrl.text;
                });
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
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("మల్టీ-ప్లాట్‌ఫార్మ్ లైవ్ స్ట్రీమింగ్ సెటప్", style: TextStyle(color: Colors.white, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(title: const Text("YouTube Live", style: TextStyle(color: Colors.white)), value: selectYt, activeColor: Colors.red, onChanged: (val) => setDialogState(() => selectYt = val!)),
                    if (selectYt) TextField(controller: ytCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "YouTube RTMP URL")),
                    
                    CheckboxListTile(title: const Text("Facebook Live", style: TextStyle(color: Colors.white)), value: selectFb, activeColor: Colors.blue, onChanged: (val) => setDialogState(() => selectFb = val!)),
                    if (selectFb) TextField(controller: fbCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "Facebook Stream URL")),
                    
                    CheckboxListTile(title: const Text("Instagram Live", style: TextStyle(color: Colors.white)), value: selectInsta, activeColor: Colors.pink, onChanged: (val) => setDialogState(() => selectInsta = val!)),
                    if (selectInsta) TextField(controller: instaCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "Instagram RTMP URL")),
                    
                    CheckboxListTile(title: const Text("X (Twitter) Live", style: TextStyle(color: Colors.white)), value: selectX, activeColor: Colors.white, onChanged: (val) => setDialogState(() => selectX = val!)),
                    if (selectX) TextField(controller: xCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "X Stream URL")),
                    
                    CheckboxListTile(title: const Text("Threads Live", style: TextStyle(color: Colors.white)), value: selectThreads, activeColor: Colors.purple, onChanged: (val) => setDialogState(() => selectThreads = val!)),
                    if (selectThreads) TextField(controller: threadsCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "Threads Stream URL")),
                    
                    CheckboxListTile(title: const Text("Snapchat Live", style: TextStyle(color: Colors.white)), value: selectSnap, activeColor: Colors.amber, onChanged: (val) => setDialogState(() => selectSnap = val!)),
                    if (selectSnap) TextField(controller: snapCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "Snapchat Stream URL")),
                    
                    CheckboxListTile(title: const Text("IPTV / Cable Server", style: TextStyle(color: Colors.white)), value: selectIptv, activeColor: Colors.green, onChanged: (val) => setDialogState(() => selectIptv = val!)),
                    if (selectIptv) TextField(controller: iptvCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "IPTV Encoder URL")),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    setState(() { isLiveBroadcasting = true; });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("సెలెక్ట్ చేసిన అన్ని సోషల్ మీడియా ఛానెల్స్‌కు లైవ్ ప్రసారం ప్రారంభమైంది!"), backgroundColor: Colors.green));
                  },
                  child: const Text("Start Multi-Live", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleAutoTimerAds() {
    setState(() {
      isAutoTimerActive = !isAutoTimerActive;
    });

    if (isAutoTimerActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("L-Band ఆటో టైమర్ ఆన్ చేయబడింది (ప్రతి 15 నిమిషాలకు ఒకసారి)"), backgroundColor: Colors.green),
      );
      
      _lBandAutoTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
        setState(() { isLBandMode = true; }); 
        
        Timer(const Duration(minutes: 1), () {
          if (mounted) {
            setState(() { isLBandMode = false; }); 
          }
        });
      });
    } else {
      _lBandAutoTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ఆటో టైమర్ ఆఫ్ చేయబడింది"), backgroundColor: Colors.orange),
      );
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

  @override
  Widget build(BuildContext context) {
    bool isScreenLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // 🔥 డిస్‌ప్లే క్రాపింగ్ సమస్య లేకుండా పూర్తి స్క్రీన్‌ను నింపే పర్‌ఫెక్ట్ కెమెరా ప్రివ్యూ
    Widget cameraWidget = isIpCameraActive && _vlcViewController != null
        ? VlcPlayer(controller: _vlcViewController!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.red)))
        : (controller != null && controller!.value.isInitialized 
            ? Listener(
                onPointerSignal: (pointerSignal) {},
                child: GestureDetector(
                  onScaleStart: (details) {
                    _baseScale = _currentZoomLevel;
                  },
                  onScaleUpdate: (details) async {
                    if (controller == null) return;
                    double zoom = _baseScale * details.scale;
                    if (zoom < _minZoomLevel) zoom = _minZoomLevel;
                    if (zoom > _maxZoomLevel) zoom = _maxZoomLevel;
                    setState(() {
                      _currentZoomLevel = zoom;
                    });
                    await controller?.setZoomLevel(zoom);
                  },
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller!.value.previewSize?.height ?? 1080,
                        height: controller!.value.previewSize?.width ?? 1920,
                        child: CameraPreview(controller!),
                      ),
                    ),
                  ),
                ),
              )
            : const Center(child: CircularProgressIndicator(color: Colors.white)));

    double currentVerticalWidth = isScreenLandscape ? landscapeVerticalWidth : verticalAdWidth;
    double currentHorizontalHeight = isScreenLandscape ? landscapeHorizontalHeight : horizontalAdHeight;

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
              Positioned.fill(
                child: cameraWidget,
              )
            else
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 85,
                child: Container(
                  color: Colors.white,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: currentVerticalWidth,
                        right: 0,
                        bottom: currentHorizontalHeight,
                        child: SizedBox.expand(
                          child: ClipRect(
                            child: cameraWidget,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: currentVerticalWidth,
                        child: Container(
                          color: lShapeColor,
                          child: Center(
                            child: verticalAdImagePath.isNotEmpty
                                ? Transform.rotate(
                                    angle: verticalAdRotation,
                                    child: Image.file(File(verticalAdImagePath), fit: BoxFit.cover, filterQuality: FilterQuality.high),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.star, color: Colors.white, size: 20),
                                      SizedBox(height: 2),
                                      Text("VERTICAL AD", textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 10)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: currentHorizontalHeight,
                        child: Container(
                          color: lShapeColor,
                          alignment: Alignment.center,
                          child: horizontalAdImagePath.isNotEmpty
                              ? Transform.rotate(
                                  angle: horizontalAdRotation,
                                  child: Image.file(File(horizontalAdImagePath), fit: BoxFit.cover, filterQuality: FilterQuality.high),
                                )
                              : Text(lShapeCustomText, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
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
                  label: const Text("Close Ad & Resume Live", style: TextStyle(color: Colors.white)),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),

            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.black.withOpacity(0.8), width: 3.0)),
                ),
              ),
            ),
            
            if (isLiveBroadcasting)
              Positioned(
                top: 30, left: 30,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: Colors.red,
                  child: const Row(children: [Icon(Icons.fiber_manual_record, color: Colors.white, size: 12), SizedBox(width: 5), Text("MULTI-LIVE ON", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
                ),
              ),

            Positioned(top: 30, right: 30, child: Container(padding: const EdgeInsets.all(8), color: Colors.blue[900]?.withOpacity(0.8), child: Text(channelName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)))),
            Positioned(
              bottom: 95, left: 15, 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (watermarkText.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 5, left: 2), child: Text(watermarkText, style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 13.0, shadows: const [Shadow(blurRadius: 2.0, color: Colors.black)])),),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), color: Colors.red, child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.0))),
                  const SizedBox(height: 4), 
                  Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14.0))),
                  Container(color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontSize: 12.0))),
                ],
              ),
            ),
            Positioned(
              bottom: 3, left: 3, right: 3, 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 35, color: Colors.blue[900], padding: const EdgeInsets.symmetric(horizontal: 10), 
                    child: Row(children: [const Text("LATEST NEWS: ", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)), Expanded(child: Marquee(text: googleNews, style: const TextStyle(color: Colors.white), blankSpace: 100.0, velocity: 35.0))]),
                  ),
                  Container(
                    height: 40, color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10), 
                    child: Row(children: [const Text("STATE NEWS: ", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 18)), Expanded(child: Marquee(text: stateNews, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), blankSpace: 50.0, velocity: 45.0))]),
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
                        _buildControlButton(Icons.edit, "Edit Text", _showEditDialog, Colors.blue),
                        _buildControlButton(Icons.settings_ethernet, "Set IP", _showIpInputDialog, Colors.cyan),
                        _buildControlButton(Icons.live_tv, "Multi-Live", _showMultiStreamDialog, Colors.redAccent),
                        _buildControlButton(
                          isLBandMode ? Icons.fullscreen : Icons.view_sidebar, 
                          isLBandMode ? "Ad Off" : "L-Shape Edit", 
                          () { 
                            setState(() { isLBandMode = !isLBandMode; }); 
                            if(isLBandMode) _showLBandImagesManagerDialog();
                          }, 
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

