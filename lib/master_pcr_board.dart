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
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

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
  int layoutMode = 6; 
  String mainCameraId = "REPORTER_CAM"; 
  List<String> hexCams = ["IP_1", "IP_2", "DRONE_1", "IP_3", "IP_4", "HDMI_1"]; 

  String cableRtmpUrl = "rtmp://your-stream-url"; // మీ RTMP URL ఇక్కడ ఇవ్వండి

  // --- Logo Settings ---
  String channelLogoPath = "";
  int logoPosition = 0; 
  VideoPlayerController? _logoVideoCtrl;
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> cameraList = [
    {"id": "REPORTER_CAM", "name": "Reporter", "type": "PHONE", "active": true, "muted": false, "url": ""},
    {"id": "DRONE_1", "name": "DJI Drone", "type": "DRONE", "active": false, "muted": true, "url": "rtsp://192.168.1.1:554/live"}, 
    {"id": "HDMI_1", "name": "Sony Cam 1", "type": "USB", "active": false, "muted": false, "url": ""},
    {"id": "IP_1", "name": "CCTV Left", "type": "IP", "active": false, "muted": true, "url": "https://www.youtube.com/watch?v=5qap5aO4i9A"}, // ఉదాహరణకు యూట్యూబ్ లింక్
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

  void _swapCamera(int gridIndex) {
    setState(() {
      String temp = mainCameraId;
      mainCameraId = hexCams[gridIndex];
      hexCams[gridIndex] = temp;
    });
  }

  // --- యూట్యూబ్ లింక్ సపోర్ట్ చేసే టోగుల్ కెమెరా ఫంక్షన్ ---
  Future<void> _toggleRTSPCamera(String camId, String url, bool isActive, bool isMuted) async { 
    if (isActive) { 
      String finalUrl = url;
      
      if (url.contains("youtube.com") || url.contains("youtu.be")) {
        var ytExplode = yt.YoutubeExplode();
        try {
          var videoId = yt.VideoId(url);
          var manifest = await ytExplode.videos.streamsClient.getManifest(videoId);
          var streamInfo = manifest.muxed.withHighestBitrate();
          finalUrl = streamInfo.url.toString(); 
        } catch (e) {
          debugPrint("YouTube Extract Error: $e");
        } finally {
          ytExplode.close();
        }
      }

      setState(() {
        _rtspControllers[camId] = VlcPlayerController.network(
          finalUrl, 
          hwAcc: HwAcc.full, 
          autoPlay: true, 
          options: VlcPlayerOptions()
        ); 
        _rtspControllers[camId]?.setVolume(isMuted ? 0 : 100);
      });
    } else { 
      _rtspControllers[camId]?.stopRendererScanning(); 
      _rtspControllers[camId]?.dispose(); 
      setState(() {
        _rtspControllers.remove(camId);
      });
    } 
  }

  void _toggleMute(Map<String, dynamic> cam) { 
    setState(() { 
      cam['muted'] = !cam['muted']; 
      if (cam['active'] && (cam['type'] == 'IP' || cam['type'] == 'DRONE')) {
        _rtspControllers[cam['id']]?.setVolume(cam['muted'] ? 0 : 100); 
      }
    }); 
  }

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
              Positioned(
                top: 0, left: 0, right: 0, bottom: showControls ? 185.0 : 40.0,
                child: isStudioMultiView ? _buildStudioLayout() : _buildLiveFeed(mainCameraId)
              ),
              Positioned(
                top: 15.0, left: 15.0,
                child: channelLogoPath.isNotEmpty 
                  ? SizedBox(width: 80, height: 80, child: _logoVideoCtrl != null && _logoVideoCtrl!.value.isInitialized ? VideoPlayer(_logoVideoCtrl!) : Image.file(File(channelLogoPath), fit: BoxFit.contain)) 
                  : Container(padding: const EdgeInsets.all(5), color: Colors.red[900], child: const Text("LOGO", style: TextStyle(color: Colors.white, fontSize: 10))),
              ),
              if (showControls)
                Positioned(
                  top: 15, left: 100, right: 10,
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
                          _channel.invokeMethod('startScreenCaptureStreaming', {'cableRtmp': cableRtmpUrl});
                        }),
                      ],
                    ),
                  ),
                ),
              // --- కింద కెమెరాల లిస్ట్ బాక్స్ ---
              if (showControls)
                Positioned(
                  bottom: 40, left: 0, right: 0,
                  child: Container(
                    height: 140, color: Colors.black87.withOpacity(0.95),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal, itemCount: cameraList.length, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      itemBuilder: (context, index) => _buildCompactCameraBox(cameraList[index]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudioLayout() { 
    return Row(
      children: [
        Expanded(flex: 5, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2)), child: _buildLiveFeed(mainCameraId))), 
        Container(width: 2, color: Colors.white24), 
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

  Widget _buildHexBox(int index) { 
    return GestureDetector(
      onTap: () => _swapCamera(index),
      child: Container(
        decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.grey.shade800, width: 1)), 
        child: Stack(
          children: [
            Positioned.fill(child: _buildLiveFeed(hexCams[index])),
            Positioned(top: 2, left: 2, child: Container(padding: const EdgeInsets.all(2), color: Colors.black54, child: const Text("TAP TO SWAP", style: TextStyle(color: Colors.white, fontSize: 8))))
          ]
        )
      )
    ); 
  }

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

  Widget _buildCompactCameraBox(Map<String, dynamic> cam) { 
    bool isLive = hexCams.contains(cam['id']) || (mainCameraId == cam['id']); 
    bool isActive = cam['active']; 
    bool isMuted = cam['muted']; 
    
    return Container(
      width: 100, 
      margin: const EdgeInsets.only(right: 6), 
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black, 
                border: Border.all(color: isLive ? Colors.red : (isActive ? Colors.green : Colors.grey.shade800), width: isLive ? 2.5 : 1)
              ), 
              child: Stack(
                children: [
                  Center(child: Text(isActive ? "Live" : "OFF", style: TextStyle(color: isActive ? Colors.greenAccent : Colors.red, fontSize: 10))), 
                  Positioned(top: 1, left: 1, child: Container(padding: const EdgeInsets.all(1), color: Colors.black54, child: Text(cam['type'], style: const TextStyle(color: Colors.yellow, fontSize: 7))))
                ]
              )
            )
          ), 
          const SizedBox(height: 2), 
          Text(cam['name'], style: const TextStyle(color: Colors.white, fontSize: 9, overflow: TextOverflow.ellipsis)), 
          Row(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              // --- పవర్ బటన్ (యూట్యూబ్ లింక్ ప్రాసెస్ అయ్యేలా await జోడించబడింది) ---
              GestureDetector(
                onTap: () async { 
                  bool willBeActive = !isActive;
                  setState(() { cam['active'] = willBeActive; }); 
                  if (cam['type'] == "IP" || cam['type'] == "DRONE") { 
                    await _toggleRTSPCamera(cam['id'], cam['url'], willBeActive, cam['muted']); 
                  } 
                }, 
                child: Icon(isActive ? Icons.power_settings_new : Icons.power_off, color: isActive ? Colors.green : Colors.red, size: 16)
              ), 
              const SizedBox(width: 5), 
              GestureDetector(
                onTap: () => _toggleMute(cam), 
                child: Icon(isMuted ? Icons.mic_off : Icons.mic, color: isMuted ? Colors.red : Colors.blueAccent, size: 16)
              ), 
              const SizedBox(width: 5), 
              if (isActive) 
                GestureDetector(
                  onTap: () => setState(() { mainCameraId = cam['id']; }), 
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), 
                    decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2)), 
                    child: const Text("CUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8))
                  )
                )
            ]
          )
        ]
      ),
    ); 
  }
}
