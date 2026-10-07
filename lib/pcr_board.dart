import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart'; 
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:io';

// ============================================================================
// 1. MASTER PCR BOARD SCREEN (Studio, Cameras, Ads, Multi-Live Hub)
// ============================================================================

class MasterPCRBoard extends StatefulWidget {
  const MasterPCRBoard({Key? key}) : super(key: key);

  @override
  State<MasterPCRBoard> createState() => _MasterPCRBoardState();
}

class _MasterPCRBoardState extends State<MasterPCRBoard> {
  static const MethodChannel _channel = MethodChannel('com.kingjvk.pocket_pcr/stream');

  final Map<String, VlcPlayerController> _rtspControllers = {};

  // --- Phone Camera State ---
  CameraController? _phoneCamCtrl;
  List<CameraDescription> _cameras = [];
  bool _isFrontCam = true;

  // --- States ---
  bool isRecording = false;
  int liveStreamState = 0; // 0 = Off, 1 = Live, 2 = Paused
  bool showControls = true; 

  // --- Studio Multi-View ---
  bool isStudioMultiView = true; 
  int selectedHexIndex = 0; 
  List<String> hexCams = ["IP_1", "IP_2", "DRONE_1", "IP_3", "IP_4", "HDMI_1"]; 
  String liveCameraId = "REPORTER_CAM";

  // --- Multi-Live URL & Stream Keys ---
  String cableRtmpUrl = "";
  String cableStreamKey = "";
  String satelliteSrtUrl = "";
  String satelliteStreamKey = "";

  final TextEditingController _cableUrlCtrl = TextEditingController();
  final TextEditingController _cableKeyCtrl = TextEditingController();
  final TextEditingController _satUrlCtrl = TextEditingController();
  final TextEditingController _satKeyCtrl = TextEditingController();

  // --- Google News / Ticker ---
  String breakingNewsText = "బ్రేకింగ్ న్యూస్: తాజా వార్తలు లోడ్ అవుతున్నాయి...";
  Timer? _newsTimer;

  // --- Logo Settings ---
  String channelLogoPath = "";
  int logoPosition = 0; 
  VideoPlayerController? _logoVideoCtrl;

  // --- Ads Settings ---
  bool showAds = false;
  int adShapeMode = 0; 
  bool isLBandRight = true;
  String leftAdPath = ""; 
  String rightAdPath = ""; 
  String bottomAdPath = "";
  VideoPlayerController? _leftAdCtrl; 
  VideoPlayerController? _rightAdCtrl; 
  VideoPlayerController? _bottomAdCtrl;

  final ImagePicker _picker = ImagePicker();

  // --- Election Scoreboard Overlay State (Inline Overlay for PCR) ---
  bool showElectionOverlay = false; 
  List<Map<String, dynamic>> electionResults = [
    {"party": "INC", "seats": "64", "trend": "+15", "color": Colors.orange},
    {"party": "BRS", "seats": "39", "trend": "-24", "color": Colors.pink},
    {"party": "BJP", "seats": "8", "trend": "+7", "color": Colors.deepOrange},
    {"party": "AIMIM", "seats": "7", "trend": "0", "color": Colors.green},
    {"party": "OTH", "seats": "1", "trend": "+2", "color": Colors.blueGrey},
  ];

  // --- Cameras List ---
  final List<Map<String, dynamic>> cameraList = [
    {"id": "REPORTER_CAM", "name": "Reporter", "type": "PHONE", "active": true, "muted": false, "url": ""},
    {"id": "DRONE_1", "name": "DJI Drone", "type": "DRONE", "active": false, "muted": true, "url": "rtsp://192.168.1.1:554/live"}, 
    {"id": "HDMI_1", "name": "Sony Cam 1", "type": "USB", "active": false, "muted": false, "url": ""},
    {"id": "HDMI_2", "name": "Panasonic 2", "type": "USB", "active": false, "muted": false, "url": ""},
    {"id": "IP_1", "name": "CCTV Left", "type": "IP", "active": false, "muted": true, "url": "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mp4"}, 
    {"id": "IP_2", "name": "CCTV Right", "type": "IP", "active": false, "muted": true, "url": "rtsp://192.168.1.100:8080/video"},
    {"id": "IP_3", "name": "Mobile WiFi 1", "type": "IP", "active": false, "muted": true, "url": "rtsp://192.168.1.101:8080/video"},
    {"id": "IP_4", "name": "Mobile WiFi 2", "type": "IP", "active": false, "muted": true, "url": "rtsp://192.168.1.102:8080/video"},
  ];

  @override
  void initState() {
    super.initState();
    _initPhoneCamera();
    _loadSavedData();
    _fetchBreakingNews();
    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) => _fetchBreakingNews());
  }

  Future<void> _fetchBreakingNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = items.take(15).map((e) => e.findElements('title').first.innerText).toList();
        if (titles.isNotEmpty && mounted) {
          setState(() { breakingNewsText = "♦ " + titles.join("   ♦   "); });
        }
      }
    } catch (e) {}
  }

  // --- MULTI-LIVE CONFIG DIALOG ---
  void _showGoLiveMenuModal() {
    _cableUrlCtrl.text = cableRtmpUrl;
    _cableKeyCtrl.text = cableStreamKey;
    _satUrlCtrl.text = satelliteSrtUrl;
    _satKeyCtrl.text = satelliteStreamKey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("🔴 PCR Studio Multi-Live Hub", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(color: Colors.grey),
              
              // 1. LOCAL CABLE CONFIG 
              const Text("1. Local Cable — RTMP/SRT", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              TextField(controller: _cableUrlCtrl, style: const TextStyle(color: Colors.white, fontSize: 11), decoration: InputDecoration(labelText: "Server URL (RTMP/SRT)", labelStyle: const TextStyle(color: Colors.grey), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade700)))),
              const SizedBox(height: 4),
              TextField(controller: _cableKeyCtrl, style: const TextStyle(color: Colors.white, fontSize: 11), decoration: InputDecoration(labelText: "Stream Key (Optional for SRT)", labelStyle: const TextStyle(color: Colors.grey), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade700)))),
              const SizedBox(height: 10),
              
              // 2. SATELLITE/PLAYOUT CONFIG 
              const Text("2. Satellite/Playout — SRT/RTMP", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              TextField(controller: _satUrlCtrl, style: const TextStyle(color: Colors.white, fontSize: 11), decoration: InputDecoration(labelText: "SRT / RTMP Server URL", labelStyle: const TextStyle(color: Colors.grey), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade700)))),
              const SizedBox(height: 4),
              TextField(controller: _satKeyCtrl, style: const TextStyle(color: Colors.white, fontSize: 11), decoration: InputDecoration(labelText: "Stream Key / Passphrase", labelStyle: const TextStyle(color: Colors.grey), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade700)))),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                      onPressed: () async {
                        setState(() { cableRtmpUrl = _cableUrlCtrl.text.trim(); cableStreamKey = _cableKeyCtrl.text.trim(); satelliteSrtUrl = _satUrlCtrl.text.trim(); satelliteStreamKey = _satKeyCtrl.text.trim(); });
                        SharedPreferences prefs = await SharedPreferences.getInstance();
                        await prefs.setString('pcr_cableUrl', cableRtmpUrl); await prefs.setString('pcr_cableKey', cableStreamKey); await prefs.setString('pcr_satUrl', satelliteSrtUrl); await prefs.setString('pcr_satKey', satelliteStreamKey);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stream Links Saved!"), backgroundColor: Colors.green));
                      },
                      child: const Text("SAVE CONFIG", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: liveStreamState == 1 ? Colors.red : Colors.green),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _executeLiveStream(liveStreamState == 1 ? 0 : 1);
                      },
                      child: Text(liveStreamState == 1 ? "STOP LIVE" : "START LIVE NOW", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeLiveStream(int actionState) async {
    if (cableRtmpUrl.isEmpty && satelliteSrtUrl.isEmpty && actionState != 0) { 
      _showGoLiveMenuModal(); return; 
    }
    setState(() => liveStreamState = actionState);
    try {
      if (liveStreamState == 1) { 
        String finalCableUrl = cableStreamKey.isEmpty ? cableRtmpUrl : (cableRtmpUrl.endsWith('/') ? "$cableRtmpUrl$cableStreamKey" : "$cableRtmpUrl/$cableStreamKey");
        String finalSatUrl = satelliteStreamKey.isEmpty ? satelliteSrtUrl : (satelliteSrtUrl.endsWith('/') ? "$satelliteSrtUrl$satelliteStreamKey" : "$satelliteSrtUrl/$satelliteStreamKey");

        await _channel.invokeMethod('startScreenCaptureStreaming', {
          'cableRtmp': finalCableUrl,
          'satelliteSrt': finalSatUrl
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Streaming LIVE to Local Cable & Satellite!"), backgroundColor: Colors.green));
      } else if (liveStreamState == 2) { 
        await _channel.invokeMethod('pauseScreenCaptureStreaming');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Live Stream Paused"), backgroundColor: Colors.orange));
      } else { 
        await _channel.invokeMethod('stopScreenCaptureStreaming');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Live Broadcast Stopped"), backgroundColor: Colors.red));
      }
    } catch (e) {}
  }

  void _toggleRecord() {
    setState(() => isRecording = !isRecording);
    if (isRecording && mounted) {
      showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: Colors.grey[900], title: const Row(children: [Icon(Icons.warning, color: Colors.amber), SizedBox(width: 10), Text("4K Recording", style: TextStyle(color: Colors.white))]), content: const Text("హై-క్వాలిటీ 4K రికార్డింగ్ కోసం మీ ఫోన్ లోని 'In-built Screen Recorder' ఉపయోగించండి.", style: TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: Colors.red)))]));
    }
  }

  Future<void> _initPhoneCamera() async {
    try { _cameras = await availableCameras(); if (_cameras.isNotEmpty) _setCamera(_isFrontCam ? CameraLensDirection.front : CameraLensDirection.back); } catch (e) {}
  }

  Future<void> _setCamera(CameraLensDirection dir) async {
    try {
      CameraDescription? cam;
      try { cam = _cameras.firstWhere((c) => c.lensDirection == dir); } catch (_) { cam = _cameras.first; }
      if (cam != null) { await _phoneCamCtrl?.dispose(); _phoneCamCtrl = CameraController(cam, ResolutionPreset.max, enableAudio: true); await _phoneCamCtrl!.initialize(); if (mounted) setState(() {}); }
    } catch (e) {}
  }

  void _switchPhoneCamera() { _isFrontCam = !_isFrontCam; _setCamera(_isFrontCam ? CameraLensDirection.front : CameraLensDirection.back); }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      logoPosition = prefs.getInt('pcr_logoPosition') ?? 0;
      adShapeMode = prefs.getInt('pcr_adShapeMode') ?? 0;
      isLBandRight = prefs.getBool('pcr_isLBandRight') ?? true;
      cableRtmpUrl = prefs.getString('pcr_cableUrl') ?? ""; cableStreamKey = prefs.getString('pcr_cableKey') ?? "";
      satelliteSrtUrl = prefs.getString('pcr_satUrl') ?? ""; satelliteStreamKey = prefs.getString('pcr_satKey') ?? "";
      String savedLogo = prefs.getString('pcr_channelLogoPath') ?? "";
      if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) _setLogo(savedLogo);
      leftAdPath = prefs.getString('pcr_leftAd') ?? ""; rightAdPath = prefs.getString('pcr_rightAd') ?? ""; bottomAdPath = prefs.getString('pcr_bottomAd') ?? "";
      _initAdPlayer('left', leftAdPath); _initAdPlayer('right', rightAdPath); _initAdPlayer('bottom', bottomAdPath);
    });
  }

  void _setLogo(String path) {
    channelLogoPath = path;
    if (path.toLowerCase().endsWith('.mp4')) {
      _logoVideoCtrl?.dispose();
      _logoVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { if (mounted) { _logoVideoCtrl!.setLooping(true); _logoVideoCtrl!.setVolume(0); _logoVideoCtrl!.play(); setState((){}); } });
    } else { _logoVideoCtrl?.dispose(); _logoVideoCtrl = null; }
  }

  Future<void> _uploadLogo() async { final XFile? media = await _picker.pickMedia(); if (media != null) { setState(() => _setLogo(media.path)); SharedPreferences prefs = await SharedPreferences.getInstance(); await prefs.setString('pcr_channelLogoPath', media.path); } }
  void _changeLogoPosition() { setState(() => logoPosition = (logoPosition + 1) % 4); SharedPreferences.getInstance().then((prefs) => prefs.setInt('pcr_logoPosition', logoPosition)); }
  Future<void> _saveSettings() async { SharedPreferences prefs = await SharedPreferences.getInstance(); await prefs.setInt('pcr_adShapeMode', adShapeMode); await prefs.setBool('pcr_isLBandRight', isLBandRight); await prefs.setString('pcr_leftAd', leftAdPath); await prefs.setString('pcr_rightAd', rightAdPath); await prefs.setString('pcr_bottomAd', bottomAdPath); }

  void _initAdPlayer(String pos, String path) {
    if (path.isEmpty || !File(path).existsSync()) return;
    bool isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov');
    if (pos == 'left') { _leftAdCtrl?.dispose(); _leftAdCtrl = null; if (isVideo) { _leftAdCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { if (mounted) { _leftAdCtrl!.setLooping(true); _leftAdCtrl!.setVolume(0.0); _leftAdCtrl!.play(); setState(() {}); } }); } } 
    else if (pos == 'right') { _rightAdCtrl?.dispose(); _rightAdCtrl = null; if (isVideo) { _rightAdCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { if (mounted) { _rightAdCtrl!.setLooping(true); _rightAdCtrl!.setVolume(0.0); _rightAdCtrl!.play(); setState(() {}); } }); } } 
    else if (pos == 'bottom') { _bottomAdCtrl?.dispose(); _bottomAdCtrl = null; if (isVideo) { _bottomAdCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { if (mounted) { _bottomAdCtrl!.setLooping(true); _bottomAdCtrl!.setVolume(0.0); _bottomAdCtrl!.play(); setState(() {}); } }); } }
  }

  Future<void> _pickAdMedia(String pos) async { try { final XFile? media = await _picker.pickMedia(); if (media != null && mounted) { setState(() { if (pos == 'left') leftAdPath = media.path; if (pos == 'right') rightAdPath = media.path; if (pos == 'bottom') bottomAdPath = media.path; _initAdPlayer(pos, media.path); }); await _saveSettings(); } } catch (e) {} }
  void _toggleRTSPCamera(String camId, String url, bool isActive, bool isMuted) { if (isActive) { _rtspControllers[camId] = VlcPlayerController.network(url, hwAcc: HwAcc.full, autoPlay: true, options: VlcPlayerOptions()); _rtspControllers[camId]?.setVolume(isMuted ? 0 : 100); } else { _rtspControllers[camId]?.stopRendererScanning(); _rtspControllers[camId]?.dispose(); _rtspControllers.remove(camId); } }
  void _toggleMute(Map<String, dynamic> cam) { setState(() { cam['muted'] = !cam['muted']; if (cam['active'] && (cam['type'] == 'IP' || cam['type'] == 'DRONE')) _rtspControllers[cam['id']]?.setVolume(cam['muted'] ? 0 : 100); }); }

  @override
  void
