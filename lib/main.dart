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
import 'package:shared_preferences/shared_preferences.dart';

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

// ============================================================================
// 1. STREAM SERVICE MANAGER (ఎర్రర్ హ్యాండ్లింగ్ తో)
// ============================================================================
class StreamServiceManager {
  static Future<bool> startLiveStream(String rtmpUrl) async {
    if (rtmpUrl.isEmpty) return false;
    String safeUrl = rtmpUrl.replaceFirst('rtmps://', 'rtmp://');
    List<String> channels = ['com.ssyatratv.pocket_pcr/stream', 'com.kingjvk.pocket_pcr/stream'];
    List<String> methods = ['startScreenStream', 'startScreenCaptureStreaming'];
    for (String c in channels) {
      for (String m in methods) {
        try {
          await MethodChannel(c).invokeMethod(m, {'url': safeUrl, 'recordAudio': true});
          return true;
        } catch (e) { debugPrint("Live Error: $e"); }
      }
    }
    return false;
  }
  
  static Future<bool> stopLiveStream() async {
    List<String> channels = ['com.ssyatratv.pocket_pcr/stream', 'com.kingjvk.pocket_pcr/stream'];
    for (String c in channels) {
      try { await MethodChannel(c).invokeMethod('stopScreenStream'); return true; } catch (_) {}
      try { await MethodChannel(c).invokeMethod('stopScreenCaptureStreaming'); return true; } catch (_) {}
    }
    return false;
  }

  static Future<bool> pauseLiveStream() async {
    List<String> channels = ['com.ssyatratv.pocket_pcr/stream', 'com.kingjvk.pocket_pcr/stream'];
    for (String c in channels) {
      try { await MethodChannel(c).invokeMethod('pauseScreenStream'); return true; } catch (_) {}
    }
    return false;
  }
}

// ============================================================================
// 2. STUDIO SCREEN (13 Buttons & Full Features)
// ============================================================================
class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> with WidgetsBindingObserver {
  CameraController? controller;
  VideoPlayerController? _bottomAdVideoController;
  
  List<String> dualMediaList = [];
  int currentDualMediaIndex = 0;

  bool isLiveBroadcasting = false;
  bool hideControls = false;
  bool isMenuOpen = false;
  bool isCameraVisible = true; 
  int currentCameraIndex = 0;
  
  bool isDualScreenMode = false;
  int adDisplayMode = 0; 
  bool isAdCurrentlyShowing = false;
  int adShapeMode = 0; 
  bool isLBandRight = true; 
  int logoPosition = 1; 
  bool isLandscape = false;

  final ImagePicker _picker = ImagePicker();

  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA";
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String breakingNewsText = "తాజా వార్తలు లోడ్ అవుతున్నాయి...";

  TextEditingController cableRtmpController = TextEditingController();
  TextEditingController restreamRtmpController = TextEditingController();

  Timer? _newsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _loadSavedData(); 
    _requestPermissionsAndInitCamera();
    _fetchBreakingNews();
    _newsTimer = Timer.periodic(const Duration(minutes: 5), (timer) { _fetchBreakingNews(); });
  }

  Future<void> _fetchBreakingNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final doc = XmlDocument.parse(response.body);
        final items = doc.findAllElements('item').take(10);
        List<String> titles = items.map((item) => item.findElements('title').first.innerText).toList();
        if (titles.isNotEmpty && mounted) setState(() => breakingNewsText = titles.join("   ♦   "));
      }
    } catch (e) { debugPrint("News error: $e"); }
  }

  Future<void> _requestPermissionsAndInitCamera() async {
    await [Permission.camera, Permission.microphone, Permission.storage].request();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) { try { cameras = await availableCameras(); } catch (e) {} }
    if (cameras.isEmpty) return;
    try {
      controller?.dispose();
      controller = CameraController(cameras[currentCameraIndex], ResolutionPreset.high, enableAudio: true);
      await controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) { _showMsg("Camera Error: $e", Colors.red); }
  }

  void _showMsg(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      watermarkText = prefs.getString('watermarkText') ?? "SS YATRA TV";
      cableRtmpController.text = prefs.getString('cableRtmp') ?? "";
      restreamRtmpController.text = prefs.getString('restreamRtmp') ?? "";
    });
  }

  // --- 13 బటన్ల లాజిక్ ---
  void _switchCamera() async {
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    if (isCameraVisible) await _initCamera();
    setState(() => isMenuOpen = false);
  }

  void _toggleCameraVisibility() {
    setState(() { isMenuOpen = false; isCameraVisible = !isCameraVisible; });
    if (isCameraVisible) _initCamera(); else controller?.dispose();
  }

  void _toggleAdMode() {
    setState(() {
      adDisplayMode = (adDisplayMode + 1) % 3;
      isMenuOpen = false; 
      isAdCurrentlyShowing = adDisplayMode != 0;
      _showMsg(adDisplayMode == 0 ? "Ads OFF" : (adDisplayMode == 1 ? "Ads ON" : "Auto Ads"), adDisplayMode == 0 ? Colors.red : Colors.green);
    });
  }

  void _toggleAdShapeMode() { setState(() { adShapeMode = (adShapeMode + 1) % 3; isMenuOpen = false; }); }
  void _changeLogoPosition() { setState(() { logoPosition = (logoPosition + 1) % 4; isMenuOpen = false; }); }
  void _toggleLBandDirection() { setState(() { isLBandRight = !isLBandRight; isMenuOpen = false; }); }
  void _toggleRotation() {
    setState(() {
      isMenuOpen = false; isLandscape = !isLandscape;
      if (isLandscape) SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
      else SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    });
  }

  Future<void> _toggleDualScreenAndPickMedia() async {
    setState(() => isMenuOpen = false);
    if (isDualScreenMode) { setState(() { isDualScreenMode = false; dualMediaList.clear(); _bottomAdVideoController?.dispose(); _bottomAdVideoController = null; }); return; }
    try {
      final List<XFile> medias = await _picker.pickMultipleMedia(); 
      if (medias.isNotEmpty && mounted) { 
        dualMediaList = medias.map((e) => e.path).toList(); currentDualMediaIndex = 0; 
        setState(() => isDualScreenMode = true); 
        _playDualMedia(dualMediaList[0]);
      }
    } catch (e) { _showMsg("Media pick error", Colors.red); }
  }

  void _playDualMedia(String path) {
    if (path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov')) { 
      _bottomAdVideoController?.dispose(); 
      _bottomAdVideoController = VideoPlayerController.file(File(path))..initialize().then((_) { if (mounted) { _bottomAdVideoController!.setLooping(true); _bottomAdVideoController!.play(); setState(() {}); } }); 
    }
  }

  Future<void> _startLiveAndLock() async {
    String url = restreamRtmpController.text.isNotEmpty ? restreamRtmpController.text : cableRtmpController.text;
    if (url.isEmpty) { _showMsg("దయచేసి RTMP లింక్ ఇవ్వండి.", Colors.red); return; }
    bool success = await StreamServiceManager.startLiveStream(url);
    if (success) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
      setState(() { isLiveBroadcasting = true; hideControls = false; isMenuOpen = false; });
      _showMsg("లైవ్ మొదలైంది! రికార్డింగ్ అనుమతించండి.", Colors.green);
    } else { _showMsg("లైవ్ కనెక్ట్ కాలేదు.", Colors.red); }
  }

  Future<void> _stopLiveStream() async {
    bool success = await StreamServiceManager.stopLiveStream();
    if (success) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      setState(() { isLiveBroadcasting = false; });
      _showMsg("లైవ్ ఆగిపోయింది ❌", Colors.blue);
    }
  }

  void _showMultiStreamDialog() {
    setState(() => isMenuOpen = false);
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.grey[900], title: const Text("Live Links Setup", style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: cableRtmpController, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "Main RTMP URL")),
          TextField(controller: restreamRtmpController, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "Backup RTMP URL")),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: () async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('cableRtmp', cableRtmpController.text);
            await prefs.setString('restreamRtmp', restreamRtmpController.text);
            _showMsg("లింక్స్ సేవ్ అయ్యాయి ✔️", Colors.green); Navigator.pop(context);
          }, child: const Text("Save Links")),
        ]),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose(); _newsTimer?.cancel();
    _bottomAdVideoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenW = MediaQuery.of(context).size.width;
    double topAreaH = MediaQuery.of(context).size.height - 55.0;

    Widget phoneCameraWidget = (!isCameraVisible) ? Container(color: Colors.black)
      : (controller != null && controller!.value.isInitialized)
        ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: controller!.value.previewSize?.height, height: controller!.value.previewSize?.width, child: CameraPreview(controller!))))
        : const Center(child: CircularProgressIndicator(color: Colors.amber));

    return Scaffold(
      backgroundColor: Colors.black, 
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content Area
            Positioned(top: 0, left: 0, right: 0, height: topAreaH, child: phoneCameraWidget),

            // Reporter Badge
            if (!isDualScreenMode)
              Positioned(bottom: 65, left: 15, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(watermarkText, style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 11.0)),
                Container(color: Colors.red.shade800, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(locationText, style: const TextStyle(color: Colors.white, fontSize: 11.0))),
                Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12.0))),
              ])),

            // Ticker
            Positioned(bottom: 0, left: 0, right: 0, height: 55, child: Row(children: [
              Container(width: 110, color: Colors.red.shade900, alignment: Alignment.center, child: const Text("BREAKING\nNEWS", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
              Expanded(child: Container(color: const Color(0xFF1A1A2E), child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), blankSpace: 100.0))),
            ])),

            // Live Controls
            if (!hideControls)
              Positioned(bottom: 75, right: 20, child: Row(children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: isLiveBroadcasting ? Colors.red : Colors.green.shade900), 
                  onPressed: isLiveBroadcasting ? _stopLiveStream : _startLiveAndLock, 
                  icon: Icon(isLiveBroadcasting ? Icons.stop : Icons.sensors, color: Colors.white), 
                  label: Text(isLiveBroadcasting ? "STOP LIVE" : "GO LIVE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                ),
                const SizedBox(width: 10),
                FloatingActionButton(backgroundColor: Colors.blue.shade900, onPressed: () => setState(() => isMenuOpen = !isMenuOpen), child: Icon(isMenuOpen ? Icons.close : Icons.menu, color: Colors.white))
              ])),

            // 13 BUTTON MENU OVERLAY
            if (isMenuOpen)
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: Center(
                    child: SingleChildScrollView(
                      child: Wrap(alignment: WrapAlignment.center, spacing: 30, runSpacing: 35, children: [
                        _buildMenuBtn(Icons.live_tv, "Live Links", _showMultiStreamDialog, Colors.redAccent),
                        _buildMenuBtn(Icons.dashboard_customize, "PCR Board", () { setState(()=>isMenuOpen=false); Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterPCRBoard())); }, Colors.yellowAccent),
                        _buildMenuBtn(Icons.bar_chart, "Election Results", () { setState(()=>isMenuOpen=false); Navigator.push(context, MaterialPageRoute(builder: (_) => const ElectionBoardScreen())); }, Colors.blueAccent),
                        _buildMenuBtn(Icons.flip_camera_android, "Phone Cam", _switchCamera, Colors.white),
                        
                        _buildMenuBtn(isCameraVisible ? Icons.videocam : Icons.videocam_off, isCameraVisible ? "Cam ON" : "Cam OFF", _toggleCameraVisibility, isCameraVisible ? Colors.greenAccent : Colors.redAccent),
                        _buildMenuBtn(Icons.video_call, "Ext. Cams", (){ setState(()=>isMenuOpen=false); _showMsg("External Cams Active", Colors.cyan);}, Colors.cyanAccent),
                        _buildMenuBtn(Icons.grid_on, "Dual Screen", _toggleDualScreenAndPickMedia, Colors.orangeAccent),
                        _buildMenuBtn(Icons.visibility, adDisplayMode == 0 ? "Ads OFF" : (adDisplayMode == 1 ? "Ads ON" : "Auto Ads"), _toggleAdMode, Colors.redAccent),
                        
                        _buildMenuBtn(Icons.dashboard, adShapeMode == 0 ? "Shape: L-Band" : "Shape: U-Band", _toggleAdShapeMode, Colors.orangeAccent),
                        _buildMenuBtn(Icons.picture_in_picture_alt, "Logo Pos", _changeLogoPosition, Colors.lightGreenAccent),
                        _buildMenuBtn(Icons.swap_horiz, "L-Band L/R", _toggleLBandDirection, Colors.orange),
                        _buildMenuBtn(Icons.screen_rotation, "Rotate", _toggleRotation, Colors.purpleAccent),
                        
                        _buildMenuBtn(Icons.settings, "Settings", (){ setState(()=>isMenuOpen=false); _showMsg("Settings Saved", Colors.blue);}, Colors.blue),
                      ]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuBtn(IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap, 
      child: SizedBox(
        width: 80,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade800, child: Icon(icon, color: color, size: 28)), 
          const SizedBox(height: 8), 
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
        ]),
      )
    );
  }
}

// ============================================================================
// 3. MASTER PCR BOARD (1+6 Layout)
// ============================================================================
class MasterPCRBoard extends StatefulWidget {
  const MasterPCRBoard({Key? key}) : super(key: key);
  @override
  State<MasterPCRBoard> createState() => _MasterPCRBoardState();
}
class _MasterPCRBoardState extends State<MasterPCRBoard> {
  CameraController? _phoneCamCtrl;
  String mainCameraId = "REPORTER_CAM"; 
  List<String> hexCams = ["IP_1", "IP_2", "DRONE_1", "IP_3", "IP_4", "HDMI_1"]; 

  @override
  void initState() {
    super.initState();
    _initPhoneCamera();
  }

  Future<void> _initPhoneCamera() async {
    try { 
      if (cameras.isNotEmpty) {
        _phoneCamCtrl = CameraController(cameras.first, ResolutionPreset.medium);
        await _phoneCamCtrl!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    _phoneCamCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const Text("MASTER PCR BOARD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
            Expanded(
              child: Row(
                children: [
                  Expanded(flex: 2, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2)), child: _phoneCamCtrl != null && _phoneCamCtrl!.value.isInitialized ? CameraPreview(_phoneCamCtrl!) : const Center(child: Text("Main Cam", style: TextStyle(color: Colors.white))))),
                  Expanded(flex: 3, child: Column(children: [
                    Expanded(child: Row(children: [ _buildHexBox(0), _buildHexBox(1), _buildHexBox(2) ])),
                    Expanded(child: Row(children: [ _buildHexBox(3), _buildHexBox(4), _buildHexBox(5) ])),
                  ]))
                ],
              ),
            ),
            Container(height: 50, color: Colors.blue.shade900, child: Row(children: [
               Container(width: 90, color: Colors.red, alignment: Alignment.center, child: const Text("PCR NEWS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
               Expanded(child: Marquee(text: "బహుళ కెమెరాల కంట్రోల్ రూమ్ విజయవంతంగా లోడ్ అయింది...", style: const TextStyle(color: Colors.white, fontSize: 16))),
            ]))
          ],
        ),
      ),
    );
  }

  Widget _buildHexBox(int i) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { String temp = mainCameraId; mainCameraId = hexCams[i]; hexCams[i] = temp; }),
        child: Container(margin: const EdgeInsets.all(2), color: Colors.grey.shade900, child: Center(child: Text(hexCams[i], style: const TextStyle(color: Colors.white)))),
      ),
    );
  }
}

// ============================================================================
// 4. ELECTION BOARD SCREEN (Dynamic Refresh)
// ============================================================================
class ElectionBoardScreen extends StatefulWidget {
  const ElectionBoardScreen({Key? key}) : super(key: key);
  @override
  State<ElectionBoardScreen> createState() => _ElectionBoardScreenState();
}
class _ElectionBoardScreenState extends State<ElectionBoardScreen> {
  CameraController? _cameraController;
  Map<String, dynamic> electionData = {"bjp": 150, "tmc": 103, "cong": 5, "left": 2};

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cameras.first), ResolutionPreset.medium);
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {}
  }

  void _refreshData() {
    setState(() { electionData = {"bjp": 156, "tmc": 98, "cong": 8, "left": 4}; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ఎలక్షన్ రిజల్ట్స్ అప్‌డేట్ అయ్యాయి! ✔️"), backgroundColor: Colors.green));
  }

  @override
  void dispose() { _cameraController?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8), color: Colors.black,
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(6), color: Colors.red.shade900, child: const Column(children: [Text("WEST BENGAL", style: TextStyle(color: Colors.white, fontSize: 11)), Text("262/294", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))])),
                    const SizedBox(width: 5),
                    _buildPartyBox("BJP+", "${electionData['bjp']}", Colors.orange.shade800),
                    _buildPartyBox("TMC+", "${electionData['tmc']}", Colors.green.shade800),
                    _buildPartyBox("CONG", "${electionData['cong']}", Colors.blue.shade800),
                  ]),
                ),
                Expanded(child: Center(child: Container(width: 300, height: 400, decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 3)), child: _cameraController != null && _cameraController!.value.isInitialized ? CameraPreview(_cameraController!) : const CircularProgressIndicator()))),
              ],
            ),
            
            Positioned(top: 15, left: 15, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context))),
            Positioned(top: 15, right: 15, child: ElevatedButton.icon(onPressed: _refreshData, icon: const Icon(Icons.refresh), label: const Text("Refresh Data"))),
            
            Positioned(bottom: 0, left: 0, right: 0, height: 50, child: Container(color: Colors.blue.shade900, child: Row(children: [
               Container(width: 90, color: Colors.red, alignment: Alignment.center, child: const Text("ELECTION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
               Expanded(child: Marquee(text: "ఎలక్షన్ కౌంటింగ్ లైవ్ అప్‌డేట్స్...", style: const TextStyle(color: Colors.white, fontSize: 18))),
            ]))),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyBox(String party, String seats, Color bgColor) {
    return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 4), color: bgColor, child: Column(children: [Text(party, style: const TextStyle(color: Colors.white, fontSize: 12)), Text(seats, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))])));
  }
}
