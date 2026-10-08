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

class MasterPCRBoard extends StatefulWidget {
  const MasterPCRBoard({Key? key}) : super(key: key);

  @override
  State<MasterPCRBoard> createState() => _MasterPCRBoardState();
}

class _MasterPCRBoardState extends State<MasterPCRBoard> {
  static const MethodChannel _channel = MethodChannel('com.kingjvk.pocket_pcr/stream');

  final Map<String, VlcPlayerController> _rtspControllers = {};
  CameraController? _phoneCamCtrl;
  List<CameraDescription> _cameras = [];
  bool _isFrontCam = true;

  bool isRecording = false;
  int liveStreamState = 0; 
  bool showControls = true; 
  bool isStudioMultiView = true; 
  
  // --- Layout & Swapping State ---
  int layoutMode = 6; // 4 లేదా 6 కెమెరాల గ్రిడ్ కోసం
  String mainCameraId = "REPORTER_CAM"; // ప్రధాన తెరపై ఉండే కెమెరా
  List<String> hexCams = ["IP_1", "IP_2", "DRONE_1", "IP_3", "IP_4", "HDMI_1"]; 

  String cableRtmpUrl = "";
  String cableStreamKey = "";
  String satelliteSrtUrl = "";
  String satelliteStreamKey = "";

  String breakingNewsText = "బ్రేకింగ్ న్యూస్: తాజా వార్తలు లోడ్ అవుతున్నాయి...";
  Timer? _newsTimer;

  // --- Logo Settings (Supports MP4, JPEG, PNG, GIF) ---
  String channelLogoPath = "";
  int logoPosition = 0; 
  VideoPlayerController? _logoVideoCtrl;

  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> cameraList = [
    {"id": "REPORTER_CAM", "name": "Reporter", "type": "PHONE", "active": true, "muted": false, "url": ""},
    {"id": "DRONE_1", "name": "DJI Drone", "type": "DRONE", "active": false, "muted": true, "url": "rtsp://192.168.1.1:554/live"}, 
    {"id": "HDMI_1", "name": "Sony Cam 1", "type": "USB", "active": false, "muted": false, "url": ""},
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
  }

  Future<void> _initPhoneCamera() async {
    try { 
      _cameras = await availableCameras(); 
      if (_cameras.isNotEmpty) _setCamera(_isFrontCam ? CameraLensDirection.front : CameraLensDirection.back); 
    } catch (e) {}
  }

  Future<void> _setCamera(CameraLensDirection dir) async {
    try {
      CameraDescription? cam = _cameras.firstWhere((c) => c.lensDirection == dir, orElse: () => _cameras.first);
      await _phoneCamCtrl?.dispose(); 
      _phoneCamCtrl = CameraController(cam, ResolutionPreset.max, enableAudio: true); 
      await _phoneCamCtrl!.initialize(); 
      if (mounted) setState(() {}); 
    } catch (e) {}
  }

  // --- టచ్ చేస్తే కెమెరాలు స్వైప్ అయ్యే ఫంక్షన్ ---
  void _swapCamera(int gridIndex) {
    setState(() {
      String temp = mainCameraId;
      mainCameraId = hexCams[gridIndex];
      hexCams[gridIndex] = temp;
    });
  }

  // --- Logo & Watermark Upload (GIF, MP4, JPEG) ---
  Future<void> _uploadLogo() async { 
    final XFile? media = await _picker.pickMedia(); 
    if (media != null) { 
      setState(() => _setLogo(media.path)); 
      SharedPreferences prefs = await SharedPreferences.getInstance(); 
      await prefs.setString('pcr_channelLogoPath', media.path); 
    } 
  }

  void _setLogo(String path) {
    channelLogoPath = path;
    if (path.toLowerCase().endsWith('.mp4')) {
      _logoVideoCtrl?.dispose();
      _logoVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { 
        if (mounted) { _logoVideoCtrl!.setLooping(true); _logoVideoCtrl!.setVolume(0); _logoVideoCtrl!.play(); setState((){}); } 
      });
    } else { 
      _logoVideoCtrl?.dispose(); _logoVideoCtrl = null; 
    }
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      logoPosition = prefs.getInt('pcr_logoPosition') ?? 0;
      layoutMode = prefs.getInt('pcr_layoutMode') ?? 6;
      String savedLogo = prefs.getString('pcr_channelLogoPath') ?? "";
      if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) _setLogo(savedLogo);
    });
  }

  void _toggleRTSPCamera(String camId, String url, bool isActive) { 
    if (isActive) { 
      _rtspControllers[camId] = VlcPlayerController.network(url, hwAcc: HwAcc.full, autoPlay: true); 
    } else { 
      _rtspControllers[camId]?.dispose(); _rtspControllers.remove(camId); 
    } 
  }

  @override
  void dispose() { 
    _phoneCamCtrl?.dispose(); _logoVideoCtrl?.dispose(); 
    for (var controller in _rtspControllers.values) { controller.dispose(); } 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onDoubleTap: () => setState(() => showControls = !showControls),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // --- Main UI Layout ---
              Positioned(
                top: 0, left: 0, right: 0, bottom: showControls ? 145.0 : 40.0,
                child: isStudioMultiView ? _buildStudioLayout() : _buildLiveFeed(mainCameraId)
              ),

              // --- Logo Overlay (GIF, Image, or Video) ---
              Positioned(
                top: (logoPosition == 0 || logoPosition == 1) ? 15.0 : null, 
                bottom: (logoPosition == 2 || logoPosition == 3) ? (showControls ? 155.0 : 55.0) : null,
                left: (logoPosition == 0 || logoPosition == 2) ? 15.0 : null, 
                right: (logoPosition == 1 || logoPosition == 3) ? 15.0 : null,
                child: channelLogoPath.isNotEmpty 
                  ? SizedBox(width: 80, height: 80, child: _logoVideoCtrl != null && _logoVideoCtrl!.value.isInitialized ? VideoPlayer(_logoVideoCtrl!) : Image.file(File(channelLogoPath), fit: BoxFit.contain)) 
                  : Container(padding: const EdgeInsets.all(5), color: Colors.red[900], child: const Text("LOGO", style: TextStyle(color: Colors.white, fontSize: 10))),
              ),

              // --- Top Controls ---
              if (showControls)
                Positioned(
                  top: 15, left: 10, right: 10,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildControlButton("1+${layoutMode} LAYOUT", Colors.teal, () {
                          setState(() { layoutMode = layoutMode == 4 ? 6 : 4; });
                          SharedPreferences.getInstance().then((p) => p.setInt('pcr_layoutMode', layoutMode));
                        }), 
                        const SizedBox(width: 6),
                        _buildControlButton("UPLOAD LOGO", Colors.indigo, _uploadLogo),
                        const SizedBox(width: 6),
                        _buildControlButton("GO LIVE / REC", Colors.red, () {
                          // TODO: Invoke MethodChannel for Native Screen Recording + RTMP
                          _channel.invokeMethod('startScreenCaptureStreaming');
                        }),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Dynamic 1+4 or 1+6 Layout ---
  Widget _buildStudioLayout() { 
    return Row(
      children: [
        // ప్రధాన కెమెరా (ఎడమ వైపు)
        Expanded(
          flex: 5, 
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2)), 
            child: _buildLiveFeed(mainCameraId)
          )
        ), 
        Container(width: 2, color: Colors.white24), 
        
        // చిన్న కెమెరాలు (కుడి వైపు - డైనమిక్ గ్రిడ్)
        Expanded(
          flex: 6, 
          child: Column(
            children: layoutMode == 4 
            ? [
                Expanded(child: Row(children: [Expanded(child: _buildHexBox(0)), Expanded(child: _buildHexBox(1))])),
                Expanded(child: Row(children: [Expanded(child: _buildHexBox(2)), Expanded(child: _buildHexBox(3))])),
              ]
            : [
                Expanded(child: Row(children: [Expanded(child: _buildHexBox(0)), Expanded(child: _buildHexBox(1)), Expanded(child: _buildHexBox(2))])),
                Expanded(child: Row(children: [Expanded(child: _buildHexBox(3)), Expanded(child: _buildHexBox(4)), Expanded(child: _buildHexBox(5))])),
              ]
          )
        )
      ]
    ); 
  }

  // --- Tap-to-Switch (కెమెరా స్టిచ్చింగ్) లాజిక్ ---
  Widget _buildHexBox(int index) { 
    return GestureDetector(
      onTap: () => _swapCamera(index), // టాప్ చేయగానే మెయిన్ స్క్రీన్ కి మారుతుంది
      child: Container(
        decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.grey.shade800, width: 1)), 
        child: Stack(
          children: [
            Positioned.fill(child: _buildLiveFeed(hexCams[index])),
            Positioned(top: 2, left: 2, child: Container(padding: const EdgeInsets.all(2), color: Colors.black54, child: Text("TAP TO SWAP", style: const TextStyle(color: Colors.white, fontSize: 8))))
          ]
        )
      )
    ); 
  }

  // --- కెమెరా ఫీడ్ రెండరింగ్ ---
  Widget _buildLiveFeed(String camId) { 
    var camData = cameraList.firstWhere((cam) => cam['id'] == camId, orElse: () => cameraList[0]); 
    
    if (camId == "REPORTER_CAM") { 
      if (_phoneCamCtrl != null && _phoneCamCtrl!.value.isInitialized) { 
        return CameraPreview(_phoneCamCtrl!); 
      } 
      return const Center(child: CircularProgressIndicator(color: Colors.red)); 
    } 
    
    if (camData['type'] == "IP" || camData['type'] == "DRONE") { 
      return _rtspControllers.containsKey(camId) 
        ? VlcPlayer(controller: _rtspControllers[camId]!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.red))) 
        : Container(color: Colors.black, child: const Center(child: Text("NO SIGNAL", style: TextStyle(color: Colors.red, fontSize: 10)))); 
    } 
    
    return Container(color: Colors.black, child: const Center(child: Text("NO SIGNAL", style: TextStyle(color: Colors.red, fontSize: 10)))); 
  }

  Widget _buildControlButton(String title, Color color, VoidCallback onTap) { 
    return GestureDetector(
      onTap: onTap, 
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), 
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), 
        child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))
      )
    ); 
  }
}
