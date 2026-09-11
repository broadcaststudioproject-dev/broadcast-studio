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
  final String title;
  String videoPathOrUrl;
  NewsBulletinItem({required this.title, required this.videoPathOrUrl});
}

class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> with WidgetsBindingObserver {
  CameraController? controller;
  VideoPlayerController? _bulletinVideoController;
  VideoPlayerController? _videoAdVideoController;
  
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
    NewsBulletinItem(title: "సమగ్ర విచారణకు సీఎం రేవంత్ ఆదేశం.. ఐపీఎస్ విజయ్‌కుమార్ నియామకం!", videoPathOrUrl: ""),
    NewsBulletinItem(title: "ఎర్రవలి ఫార్మ్‌హౌస్ ఘటనపై బీఆర్ఎస్ నేతల తీవ్ర ఆగ్రహం!", videoPathOrUrl: ""),
    NewsBulletinItem(title: "తెలంగాణలో పెరుగుతున్న పొలిటికల్ హీట్.. అసెంబ్లీలో శుద్ధి రగడ!", videoPathOrUrl: ""),
  ];

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
  String newsBadgeImagePath = ""; 

  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA"; 
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String breakingNewsText = "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి... దయచేసి వేచి ఉండండి...";

  TextEditingController rtmpUrlController = TextEditingController();
  TextEditingController watermarkCtrl = TextEditingController();
  TextEditingController locCtrl = TextEditingController();
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController roleCtrl = TextEditingController();
  TextEditingController newsCtrl = TextEditingController();

  Timer? _newsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    watermarkCtrl.text = watermarkText;
    locCtrl.text = locationText;
    nameCtrl.text = reporterName;
    roleCtrl.text = reporterRole;
    newsCtrl.text = breakingNewsText;
    qrDataController.text = "https://ssyatratv.com/live-stream";
    rtmpUrlController.text = "rtmp://live.restream.io/live/your_stream_key_here";

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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _newsTimer?.cancel();
    controller?.dispose();
    _bulletinVideoController?.dispose();
    _videoAdVideoController?.dispose();
    ipController.dispose();
    qrDataController.dispose();
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

  Future<void> _initCamera() async {
    if (cameras.isEmpty || isIpCameraActive) return;
    try {
      if (controller != null) {
        await controller!.dispose();
        controller = null;
      }
      final camController = CameraController(
        cameras[currentCameraIndex],
        ResolutionPreset.max,
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
    setState(() { isIpCameraActive = !isIpCameraActive; });
    if (!isIpCameraActive) _initCamera();
  }

  // బులెటిన్ వీడియో ప్లేయర్ (VideoPlayer లింక్)
  Future<void> _startBulletinVideo(String path) async {
    if (path.isEmpty) return;
    await _bulletinVideoController?.dispose();
    
    _bulletinVideoController = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        setState(() {});
        _bulletinVideoController?.play();
        _bulletinVideoController?.setLooping(true);
      });
  }

  Future<void> _playVideoAd(String path) async {
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("దయచేసి ముందుగా గ్యాలరీ నుండి వీడియో ఎంచుకోండి!"), backgroundColor: Colors.red));
      return;
    }
    await _videoAdVideoController?.dispose();
    _videoAdVideoController = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        setState(() { isVideoAdPlaying = true; });
        _videoAdVideoController?.play();
      });
  }

  void _stopVideoAd() {
    _videoAdVideoController?.pause();
    setState(() {
      isVideoAdPlaying = false;
    });
  }

  void _toggleNewsBulletinMode() {
    setState(() {
      isNewsBulletinMode = !isNewsBulletinMode;
      if (isNewsBulletinMode) {
        if (newsBulletinList[currentNewsIndex].videoPathOrUrl.isNotEmpty) {
          _startBulletinVideo(newsBulletinList[currentNewsIndex].videoPathOrUrl);
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
      if (newsBulletinList[currentNewsIndex].videoPathOrUrl.isNotEmpty) {
        _startBulletinVideo(newsBulletinList[currentNewsIndex].videoPathOrUrl);
      } else {
        _bulletinVideoController?.dispose();
        _bulletinVideoController = null;
      }
    });
  }

  void _prevNewsItem() {
    setState(() {
      currentNewsIndex = (currentNewsIndex - 1 + newsBulletinList.length) % newsBulletinList.length;
      if (newsBulletinList[currentNewsIndex].videoPathOrUrl.isNotEmpty) {
        _startBulletinVideo(newsBulletinList[currentNewsIndex].videoPathOrUrl);
      } else {
        _bulletinVideoController?.dispose();
        _bulletinVideoController = null;
      }
    });
  }

  Future<void> _pickBulletinVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null && mounted) {
      setState(() {
        newsBulletinList[currentNewsIndex].videoPathOrUrl = video.path;
      });
      await _startBulletinVideo(video.path);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("వీడియో വിജയవంతంగా లోడ్ అయింది!"), backgroundColor: Colors.green));
    }
  }

  Future<void> _fetchBreakingNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = [];
        for (var item in items.take(20)) {
          titles.add(item.findElements('title').first.innerText);
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
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (image != null && mounted) {
      setState(() { verticalAnimatedAdPath = image.path; });
    }
  }

  Future<void> _pickHorizontalAd() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (image != null && mounted) {
      setState(() { horizontalAnimatedAdPath = image.path; });
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
              title: const Text("గ్యాలరీ HD MP4 వీడియో యాడ్స్ మేనేజర్", style: TextStyle(color: Colors.white, fontSize: 15)),
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
                              videoAdsList[index].isEmpty ? "వీడియో లేదు" : "అటాచ్ చేయబడింది",
                              style: const TextStyle(color: Colors.yellow, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.video_library, color: Colors.cyan, size: 22),
                            onPressed: () async {
                              final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
                              if (video != null) {
                                setDialogState(() { videoAdsList[index] = video.path; });
                                setState(() { videoAdsList[index] = video.path; });
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

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("ఛానల్ లోగో & బ్యాడ్జ్ ఎడిట్", style: TextStyle(color: Colors.white, fontSize: 13)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                        if (image != null) setDialogState(() { channelLogoPath = image.path; });
                      },
                      icon: const Icon(Icons.upload),
                      label: const Text("ఛానల్ లోగో అప్లోడ్ చేయి"),
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
    double screenWidth = MediaQuery.of(context).size.width;

    Widget cameraWidget = controller != null && controller!.value.isInitialized 
        ? CameraPreview(controller!)
        : const Center(child: CircularProgressIndicator(color: Colors.white));

    Widget detailsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (watermarkText.isNotEmpty) 
          Text(watermarkText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 7.0)),
        Container(color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 7.0))),
        const SizedBox(height: 1), 
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 7.0))),
        Container(color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontSize: 7.0))),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () { setState(() { hideControls = !hideControls; }); },
        child: Stack(
          children: [
            if (isNewsBulletinMode)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                        color: Colors.red.shade900,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18), onPressed: _prevNewsItem),
                            Expanded(
                              child: Text(
                                newsBulletinList[currentNewsIndex].title,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.video_call, color: Colors.amberAccent, size: 26),
                              onPressed: _pickBulletinVideo,
                            ),
                            IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18), onPressed: _nextNewsItem),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 50.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(child: cameraWidget),
                                    Positioned(bottom: 10, left: 10, child: detailsWidget),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: _bulletinVideoController != null && _bulletinVideoController!.value.isInitialized
                                    ? AspectRatio(
                                        aspectRatio: _bulletinVideoController!.value.aspectRatio,
                                        child: VideoPlayer(_bulletinVideoController!),
                                      )
                                    : Container(
                                        color: Colors.black, 
                                        child: Center(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                                            onPressed: _pickBulletinVideo,
                                            icon: const Icon(Icons.video_library),
                                            label: const Text("గ్యాలరీ నుండి MP4 ఎంచుకోండి"),
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
                ),
              )
            else if (isVideoAdPlaying && _videoAdVideoController != null && _videoAdVideoController!.value.isInitialized)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _videoAdVideoController!.value.aspectRatio,
                      child: VideoPlayer(_videoAdVideoController!),
                    ),
                  ),
                ),
              )
            else if (!isAnimatedAdsMode)
              Positioned.fill(child: cameraWidget)
            else
              Positioned.fill(
                child: Container(
                  color: adLayerColor,
                  child: Stack(
                    children: [
                      Positioned.fill(child: cameraWidget),
                      Positioned(
                        left: 10 + _vertOffset.dx, top: 10 + _vertOffset.dy,
                        child: GestureDetector(
                          onTap: _pickVerticalAd,
                          child: Container(
                            width: 140, height: 420,
                            decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 1.5)),
                            child: verticalAnimatedAdPath.isNotEmpty
                                ? Image.file(File(verticalAnimatedAdPath), fit: BoxFit.fill)
                                : const Center(child: Text("JPEG/GIF AD", style: TextStyle(color: Colors.white, fontSize: 10))),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 150 + _horizOffset.dx, bottom: 45 + _horizOffset.dy, 
                        child: GestureDetector(
                          onTap: _pickHorizontalAd,
                          child: Container(
                            width: screenWidth - 155, height: 90, 
                            decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 1.5)),
                            child: horizontalAnimatedAdPath.isNotEmpty
                                ? Image.file(File(horizontalAnimatedAdPath), fit: BoxFit.fill)
                                : const Center(child: Text("JPEG/GIF AD", style: TextStyle(color: Colors.white, fontSize: 10))),
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
                  label: const Text("Close Ad", style: TextStyle(color: Colors.white)),
                  icon: const Icon(Icons.close),
                ),
              ),

            Positioned(
              top: 30, right: 30, 
              child: channelLogoPath.isNotEmpty
                  ? SizedBox(width: logoWidth, height: logoHeight, child: Image.file(File(channelLogoPath), fit: BoxFit.contain))
                  : Container(padding: const EdgeInsets.all(8), color: Colors.blue[900], child: const Text("SS YATRA TV", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),

            if (!isNewsBulletinMode)
              Positioned(bottom: isAnimatedAdsMode ? 140 : 55, left: 15, child: detailsWidget),
            
            Positioned(
              bottom: 5, left: 5, right: 5, 
              child: Container(
                height: 42, 
                decoration: BoxDecoration(color: Colors.red.shade900, border: Border.all(color: Colors.amber, width: 1.5)),
                child: Row(
                  children: [
                    Container(width: 125, color: Colors.yellow.shade800, alignment: Alignment.center, child: const Text("BREAKING", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
                    Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
                  ],
                ),
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
                        _buildControlButton(Icons.flip_camera_android, "Camera", _switchCamera, Colors.white),
                        _buildControlButton(Icons.video_library, "Video Ads", _showAdsManagerDialog, Colors.amberAccent),
                        _buildControlButton(Icons.qr_code_2, "QR Gen", _showQrGeneratorDialog, Colors.tealAccent),
                        _buildControlButton(Icons.edit, "Edit Studio", _showEditDialog, Colors.blue),
                        _buildControlButton(Icons.newspaper, isNewsBulletinMode ? "Exit Bulletin" : "Bulletin", _toggleNewsBulletinMode, Colors.pinkAccent),
                        _buildControlButton(Icons.timer, "Ads Mode", _toggleAutoTimerAds, Colors.amber),
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
