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
  TextEditingController topHeadlineController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String topHeadline = "తెలంగాణ ప్రజలకు SS YATRA TV ప్రత్యేక వార్తలు...";
  final List<String> videoAdsList = List.generate(10, (index) => index == 0 ? "https://www.quirksmode.org/html5/videos/big_buck_bunny.mp4" : "");
  final List<String> lBandImagesList = List.generate(10, (index) => "");
  int selectedLBandIndex = 0;

  String channelName = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA"; 
  String reporterName = "JANAMPALLY VINOD KUMAR";
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
  TextEditingController locCtrl = TextEditingController();
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController newsCtrl = TextEditingController();

  Timer? _newsTimer;
  Timer? _lBandAutoTimer; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    channelCtrl.text = channelName;
    locCtrl.text = locationText;
    nameCtrl.text = reporterName;
    newsCtrl.text = stateNews;
    topHeadlineController.text = topHeadline;
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
    topHeadlineController.dispose();
    channelCtrl.dispose();
    locCtrl.dispose();
    nameCtrl.dispose();
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
    _videoAdVlcController?.dispose();
    _videoAdVlcController = VlcPlayerController.network(videoUrl, hwAcc: HwAcc.full, autoPlay: true, options: VlcPlayerOptions());
    setState(() { isVideoAdPlaying = true; });
  }

  void _stopVideoAd() {
    _videoAdVlcController?.stopRendererScanning();
    _videoAdVlcController?.dispose();
    setState(() { isVideoAdPlaying = false; _videoAdVlcController = null; });
  }

  void _showAdsManagerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("10 HD వీడియో యాడ్స్ మేనేజర్", style: TextStyle(color: Colors.white, fontSize: 16)),
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
                              decoration: const InputDecoration(hintText: "హెచ్‌డి వీడియో లింక్", hintStyle: TextStyle(color: Colors.white38)),
                              onChanged: (val) { videoAdsList[index] = val; },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.video_library, color: Colors.cyan, size: 20),
                            onPressed: () async {
                              final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
                              if (video != null) {
                                setDialogState(() { videoAdsList[index] = video.path; });
                              }
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

  void _showLBandImagesManagerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("10 L-Band / L-Shape JPEG యాడ్స్", style: TextStyle(color: Colors.white, fontSize: 15)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    TextEditingController imgCtrl = TextEditingController(text: lBandImagesList[index]);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Text("L-Img ${index + 1}:", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: TextField(
                              controller: imgCtrl,
                              style: const TextStyle(color: Colors.yellow, fontSize: 11),
                              decoration: const InputDecoration(hintText: "JPEG ఇమేజ్ పాత్", hintStyle: TextStyle(color: Colors.white38)),
                              onChanged: (val) { lBandImagesList[index] = val; },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.photo_library, color: Colors.amberAccent, size: 20),
                            onPressed: () async {
                              final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
                              if (image != null) {
                                setDialogState(() { lBandImagesList[index] = image.path; });
                              }
                            },
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(40, 30)),
                            onPressed: () { Navigator.pop(context); setState(() { selectedLBandIndex = index; isLBandMode = true; }); },
                            child: const Text("Set", style: TextStyle(fontSize: 11)),
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("PCR QR కోడ్ జనరేటర్", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: qrDataController, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "స్ట్రీమ్ లింక్", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 20),
              Container(padding: const EdgeInsets.all(10), color: Colors.white, child: QrImageView(data: qrDataController.text, version: QrVersions.auto, size: 160.0)),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close", style: TextStyle(color: Colors.white)))],
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
          content: TextField(controller: ipController, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "RTSP / HTTP లింక్", labelStyle: TextStyle(color: Colors.white54))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () { setState(() { ipCameraUrl = ipController.text; }); Navigator.pop(context); _toggleIpCamera(); },
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
          title: const Text("న్యూస్ రీల్ & గ్రాఫిక్స్ ఎడిటర్", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: topHeadlineController, style: const TextStyle(color: Colors.yellow), maxLines: 2, decoration: const InputDecoration(labelText: "టాప్ హెడ్‌లైన్ (Big Headline)", labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: channelCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "ఛానల్ పేరు", labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: locCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "లొకేషన్", labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "రిపోర్టర్ పేరు", labelStyle: TextStyle(color: Colors.white54))),
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
                  topHeadline = topHeadlineController.text;
                  channelName = channelCtrl.text;
                  locationText = locCtrl.text;
                  reporterName = nameCtrl.text;
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
              title: const Text("మల్టీ-ప్లాట్‌ఫార్మ్ లైవ్ స్ట్రీమింగ్", style: TextStyle(color: Colors.white, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(title: const Text("YouTube / FB / Insta / X / Threads / Snap", style: TextStyle(color: Colors.white, fontSize: 12)), value: selectYt, activeColor: Colors.red, onChanged: (val) => setDialogState(() => selectYt = val!)),
                    TextField(controller: ytCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "RTMP Stream URL")),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () { setState(() { isLiveBroadcasting = true; }); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లైవ్ ప్రసారం ప్రారంభమైంది!"), backgroundColor: Colors.green)); },
                  child: const Text("Start Live", style: TextStyle(color: Colors.white)),
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
        Timer(const Duration(minutes: 1), () { if (mounted) setState(() { isLBandMode = false; }); });
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

    Widget cameraWidget = isIpCameraActive && _vlcViewController != null
        ? VlcPlayer(controller: _vlcViewController!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.red)))
        : (controller != null && controller!.value.isInitialized 
            ? GestureDetector(
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
                    child: SizedBox(
                      width: isScreenLandscape ? (controller!.value.previewSize?.width ?? 1920) : (controller!.value.previewSize?.height ?? 1080),
                      height: isScreenLandscape ? (controller!.value.previewSize?.height ?? 1080) : (controller!.value.previewSize?.width ?? 1920),
                      child: CameraPreview(controller!),
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
            Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.red[800],
                  padding: EdgeInsets.symmetric(vertical: isScreenLandscape ? 6 : 12, horizontal: 10),
                  child: SafeArea(
                    bottom: false,
                    child: Text(
                      topHeadline,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: isScreenLandscape ? 14 : 18),
                    ),
                  ),
                ),
                
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: isVideoAdPlaying && _videoAdVlcController != null
                            ? VlcPlayer(controller: _videoAdVlcController!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator()))
                            : (!isLBandMode ? cameraWidget : Row(
                                children: [
                                  Container(
                                    width: isScreenLandscape ? 180 : 120,
                                    color: Colors.orange[900],
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text("L-SHAPE AD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                        const Text("Size: HD 1080p", style: TextStyle(color: Colors.yellowAccent, fontSize: 9)),
                                        const SizedBox(height: 10),
                                        Expanded(
                                          child: lBandImagesList[selectedLBandIndex].isNotEmpty
                                              ? Image.file(File(lBandImagesList[selectedLBandIndex]), fit: BoxFit.cover)
                                              : const Center(child: Text("Ad Banner", style: TextStyle(color: Colors.white70, fontSize: 10))),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(child: cameraWidget),
                                ],
                              )),
                      ),
                      
                      Positioned(
                        top: 10, right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: Colors.blue[900]!.withOpacity(0.9),
                          child: Text(channelName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),

                      if (isLiveBroadcasting)
                        Positioned(
                          top: 10, left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: Colors.red,
                            child: const Row(children: [Icon(Icons.fiber_manual_record, color: Colors.white, size: 10), SizedBox(width: 4), Text("LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))]),
                          ),
                        ),
                    ],
                  ),
                ),

                Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        color: Colors.amber[800],
                        child: const Text("SPONSOR AD\n95155 95777", textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9)),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text("$locationText | $reporterName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
                            const SizedBox(height: 2),
                            Container(height: 25, color: Colors.blue[900], child: Row(children: [const Text(" LATEST: ", style: TextStyle(color: Colors.yellow, fontSize: 11, fontWeight: FontWeight.bold)), Expanded(child: Marquee(text: googleNews, style: const TextStyle(color: Colors.white, fontSize: 11), velocity: 30.0))])),
                            Container(height: 28, color: Colors.red[900], child: Row(children: [const Text(" STATE: ", style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold)), Expanded(child: Marquee(text: stateNews, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), velocity: 35.0))])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (isVideoAdPlaying)
              Positioned(
                top: 50, right: 40,
                child: FloatingActionButton.extended(
                  backgroundColor: Colors.red,
                  onPressed: _stopVideoAd,
                  label: const Text("Close Ad", style: TextStyle(color: Colors.white)),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),

            if (!hideControls)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center, spacing: 12, runSpacing: 12,
                      children: [
                        _buildControlButton(Icons.flip_camera_android, "Cam", _switchCamera, Colors.white),
                        _buildControlButton(Icons.wifi_tethering, "IP Cam", _toggleIpCamera, isIpCameraActive ? Colors.green : Colors.orange),
                        _buildControlButton(Icons.video_library, "Video Ads", _showAdsManagerDialog, Colors.amberAccent),
                        _buildControlButton(Icons.qr_code_2, "QR Gen", _showQrGeneratorDialog, Colors.tealAccent),
                        _buildControlButton(Icons.edit, "Edit News", _showEditDialog, Colors.blue),
                        _buildControlButton(Icons.settings_ethernet, "Set IP", _showIpInputDialog, Colors.cyan),
                        _buildControlButton(Icons.live_tv, "Multi-Live", _showMultiStreamDialog, Colors.redAccent),
                        _buildControlButton(isLBandMode ? Icons.fullscreen : Icons.view_sidebar, isLBandMode ? "Ad Off" : "L-Shape", () { setState(() { isLBandMode = !isLBandMode; }); if(isLBandMode) _showLBandImagesManagerDialog(); }, Colors.amber),
                        _buildControlButton(isAutoTimerActive ? Icons.timer : Icons.timer_off, isAutoTimerActive ? "Auto ON" : "Auto OFF", _toggleAutoTimerAds, isAutoTimerActive ? Colors.greenAccent : Colors.grey),
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
          CircleAvatar(radius: 22, backgroundColor: Colors.white30, child: Icon(icon, color: iconColor, size: 22)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }
}
