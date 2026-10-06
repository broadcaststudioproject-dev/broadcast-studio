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
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';

class MasterPCRBoard extends StatefulWidget {
  const MasterPCRBoard({Key? key}) : super(key: key);

  @override
  State<MasterPCRBoard> createState() => _MasterPCRBoardState();
}

class _MasterPCRBoardState extends State<MasterPCRBoard> {
  static const MethodChannel _channel = MethodChannel('com.kingjvk.pocket_pcr/stream');
  int? _usbTextureId; 

  final Map<String, VlcPlayerController> _rtspControllers = {};

  // --- Phone Camera State ---
  CameraController? _phoneCamCtrl;
  List<CameraDescription> _cameras = [];
  bool _isFrontCam = true;

  // --- Screen Recorder State ---
  bool isRecording = false;

  bool showControls = true; 
  
  // --- Studio Multi-View ---
  bool isStudioMultiView = true; 
  int selectedHexIndex = 0; 
  List<String> hexCams = ["IP_1", "IP_2", "DRONE_1", "IP_3", "IP_4", "HDMI_1"]; 
  String liveCameraId = "REPORTER_CAM";

  // --- Google News ---
  String breakingNewsText = "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";
  Timer? _newsTimer;

  // --- Advanced Logo Settings (JPEG/GIF/MP4) ---
  String channelLogoPath = "";
  int logoPosition = 0; 
  VideoPlayerController? _logoVideoCtrl;

  // --- Ads Settings ---
  bool showAds = false;
  int adShapeMode = 0; 
  bool isLBandRight = true;
  String leftAdPath = ""; String rightAdPath = ""; String bottomAdPath = "";
  VideoPlayerController? _leftAdCtrl; VideoPlayerController? _rightAdCtrl; VideoPlayerController? _bottomAdCtrl;

  final ImagePicker _picker = ImagePicker();

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

  // --- Screen Recording Logic ---
  Future<void> _toggleRecord() async {
    try {
      if (isRecording) {
        final String path = await FlutterScreenRecording.stopRecordScreen;
        setState(() => isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Video Saved: $path"), backgroundColor: Colors.green));
      } else {
        await FlutterScreenRecording.startRecordScreenAndAudio(
          "PCR_Live_${DateTime.now().millisecondsSinceEpoch}",
          titleNotification: 'Pocket PCR Studio',
          messageNotification: 'Recording 4K Broadcast...',
        );
        setState(() => isRecording = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("4K Recording Started!"), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint("Record Error: $e");
    }
  }

  // --- Phone Camera Logic ---
  Future<void> _initPhoneCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) _setCamera(_isFrontCam ? CameraLensDirection.front : CameraLensDirection.back);
  }
  Future<void> _setCamera(CameraLensDirection dir) async {
    CameraDescription? cam;
    try { cam = _cameras.firstWhere((c) => c.lensDirection == dir); } catch (_) { cam = _cameras.first; }
    if (cam != null) {
      _phoneCamCtrl?.dispose();
      _phoneCamCtrl = CameraController(cam, ResolutionPreset.max, enableAudio: true);
      await _phoneCamCtrl!.initialize();
      if (mounted) setState(() {});
    }
  }
  void _switchPhoneCamera() {
    _isFrontCam = !_isFrontCam;
    _setCamera(_isFrontCam ? CameraLensDirection.front : CameraLensDirection.back);
  }

  // --- Logo & Ads Logic ---
  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      logoPosition = prefs.getInt('pcr_logoPosition') ?? 0;
      adShapeMode = prefs.getInt('pcr_adShapeMode') ?? 0;
      isLBandRight = prefs.getBool('pcr_isLBandRight') ?? true;
      String savedLogo = prefs.getString('pcr_channelLogoPath') ?? "";
      if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) _setLogo(savedLogo);
      
      leftAdPath = prefs.getString('pcr_leftAd') ?? "";
      rightAdPath = prefs.getString('pcr_rightAd') ?? "";
      bottomAdPath = prefs.getString('pcr_bottomAd') ?? "";
      
      _initAdPlayer('left', leftAdPath);
      _initAdPlayer('right', rightAdPath);
      _initAdPlayer('bottom', bottomAdPath);
    });
  }

  void _setLogo(String path) {
    channelLogoPath = path;
    if (path.toLowerCase().endsWith('.mp4')) {
      _logoVideoCtrl?.dispose();
      _logoVideoCtrl = VideoPlayerController.file(File(path))..initialize().then((_) {
        _logoVideoCtrl!.setLooping(true); _logoVideoCtrl!.setVolume(0); _logoVideoCtrl!.play(); setState((){});
      });
    } else {
      _logoVideoCtrl?.dispose(); _logoVideoCtrl = null;
    }
  }

  Future<void> _uploadLogo() async {
    final XFile? media = await _picker.pickMedia(); 
    if (media != null) {
      setState(() => _setLogo(media.path));
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('pcr_channelLogoPath', media.path);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logo Updated!"), backgroundColor: Colors.green));
    }
  }

  void _changeLogoPosition() {
    setState(() => logoPosition = (logoPosition + 1) % 4);
    SharedPreferences.getInstance().then((prefs) => prefs.setInt('pcr_logoPosition', logoPosition));
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pcr_adShapeMode', adShapeMode);
    await prefs.setBool('pcr_isLBandRight', isLBandRight);
    await prefs.setString('pcr_leftAd', leftAdPath);
    await prefs.setString('pcr_rightAd', rightAdPath);
    await prefs.setString('pcr_bottomAd', bottomAdPath);
  }

  void _initAdPlayer(String pos, String path) {
    if (path.isEmpty || !File(path).existsSync()) return;
    bool isVideo = path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov');
    
    if (pos == 'left') {
      _leftAdCtrl?.dispose(); _leftAdCtrl = null;
      if (isVideo) { _leftAdCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { _leftAdCtrl!.setLooping(true); _leftAdCtrl!.setVolume(0.0); _leftAdCtrl!.play(); setState(() {}); }); }
    } else if (pos == 'right') {
      _rightAdCtrl?.dispose(); _rightAdCtrl = null;
      if (isVideo) { _rightAdCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { _rightAdCtrl!.setLooping(true); _rightAdCtrl!.setVolume(0.0); _rightAdCtrl!.play(); setState(() {}); }); }
    } else if (pos == 'bottom') {
      _bottomAdCtrl?.dispose(); _bottomAdCtrl = null;
      if (isVideo) { _bottomAdCtrl = VideoPlayerController.file(File(path))..initialize().then((_) { _bottomAdCtrl!.setLooping(true); _bottomAdCtrl!.setVolume(0.0); _bottomAdCtrl!.play(); setState(() {}); }); }
    }
  }

  Future<void> _pickAdMedia(String pos) async {
    try {
      final XFile? media = await _picker.pickMedia();
      if (media != null && mounted) {
        setState(() {
          if (pos == 'left') leftAdPath = media.path;
          if (pos == 'right') rightAdPath = media.path;
          if (pos == 'bottom') bottomAdPath = media.path;
          _initAdPlayer(pos, media.path);
        });
        await _saveSettings();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ad Updated!"), backgroundColor: Colors.green));
      }
    } catch (e) {}
  }

  // --- Camera Power & Mute Toggles ---
  void _toggleRTSPCamera(String camId, String url, bool isActive, bool isMuted) {
    if (isActive) {
      _rtspControllers[camId] = VlcPlayerController.network(url, hwAcc: HwAcc.full, autoPlay: true, options: VlcPlayerOptions());
      _rtspControllers[camId]?.setVolume(isMuted ? 0 : 100);
    } else {
      _rtspControllers[camId]?.stopRendererScanning(); _rtspControllers[camId]?.dispose(); _rtspControllers.remove(camId);
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

  Future<void> _fetchBreakingNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = items.take(15).map((e) => e.findElements('title').first.innerText).toList();
        if (titles.isNotEmpty && mounted) setState(() => breakingNewsText = titles.join("   ♦   "));
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    _phoneCamCtrl?.dispose(); _logoVideoCtrl?.dispose();
    _leftAdCtrl?.dispose(); _rightAdCtrl?.dispose(); _bottomAdCtrl?.dispose();
    for (var controller in _rtspControllers.values) { controller.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          double screenW = constraints.maxWidth;
          double screenH = constraints.maxHeight;
          double leftPad = 0; double rightPad = 0; double bottomPad = showControls ? 145.0 : 40.0;
          
          if (showAds) {
            double adWidth = screenW * 0.20;
            double adHeight = screenH * 0.15;
            if (adShapeMode == 0) { // L-Band
              if (isLBandRight) { rightPad = adWidth; bottomPad += adHeight; } else { leftPad = adWidth; bottomPad += adHeight; }
            } else if (adShapeMode == 1) { // 2-Sides
              leftPad = adWidth * 0.8; rightPad = adWidth * 0.8;
            } else if (adShapeMode == 2) { // U-Band
              leftPad = adWidth * 0.8; rightPad = adWidth * 0.8; bottomPad += adHeight;
            }
          }

          return GestureDetector(
            onDoubleTap: () => setState(() => showControls = !showControls),
            child: SafeArea(
              child: Stack(
                children: [
                  // --- 1. Main Live Video Layer ---
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    top: 0, left: leftPad, right: rightPad, bottom: bottomPad,
                    child: isStudioMultiView ? _buildStudioLayout() : _buildLiveFeed(liveCameraId),
                  ),

                  // --- 2. Ads Layers ---
                  if (showAds && (adShapeMode == 0 && !isLBandRight || adShapeMode == 1 || adShapeMode == 2))
                    Positioned(top: 0, left: 0, bottom: bottomPad - (showControls ? 145 : 40), width: leftPad, child: _buildAdBox(leftAdPath, _leftAdCtrl)),
                  if (showAds && (adShapeMode == 0 && isLBandRight || adShapeMode == 1 || adShapeMode == 2))
                    Positioned(top: 0, right: 0, bottom: bottomPad - (showControls ? 145 : 40), width: rightPad, child: _buildAdBox(rightAdPath, _rightAdCtrl)),
                  if (showAds && (adShapeMode == 0 || adShapeMode == 2))
                    Positioned(left: leftPad, right: rightPad, bottom: showControls ? 145 : 40, height: screenH * 0.15, child: _buildAdBox(bottomAdPath, _bottomAdCtrl)),

                  // --- 3. Advanced Logo ---
                  Positioned(
                    top: (logoPosition == 0 || logoPosition == 1) ? 15.0 : null,
                    bottom: (logoPosition == 2 || logoPosition == 3) ? (showControls ? 155.0 : 55.0) : null,
                    left: (logoPosition == 0 || logoPosition == 2) ? 15.0 : null,
                    right: (logoPosition == 1 || logoPosition == 3) ? 15.0 : null,
                    child: channelLogoPath.isNotEmpty
                        ? SizedBox(
                            width: 70, height: 70, 
                            child: _logoVideoCtrl != null && _logoVideoCtrl!.value.isInitialized 
                                ? VideoPlayer(_logoVideoCtrl!) 
                                : Image.file(File(channelLogoPath), fit: BoxFit.contain)
                          )
                        : Container(padding: const EdgeInsets.all(5), color: Colors.red[900], child: const Text("SS YATRA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
                  ),

                  // --- 4. Top Controls ---
                  AnimatedOpacity(
                    opacity: showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !showControls,
                      child: Positioned(
                        top: 8, left: 10, right: 10,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildRecordButton(), const SizedBox(width: 6),
                              _buildControlButton("STUDIO VIEW", isStudioMultiView ? Colors.blue.shade800 : Colors.purple.shade800, () => setState(() => isStudioMultiView = !isStudioMultiView)), const SizedBox(width: 6),
                              _buildControlButton(showAds ? "ADS: ON" : "ADS: OFF", showAds ? Colors.green : Colors.orange, () => setState(() => showAds = !showAds)), const SizedBox(width: 6),
                              _buildControlButton(adShapeMode == 0 ? "SHAPE: L-Band" : (adShapeMode == 1 ? "SHAPE: 2-Sides" : "SHAPE: U-Band"), Colors.teal, () { setState(() { adShapeMode = (adShapeMode + 1) % 3; }); _saveSettings(); }), const SizedBox(width: 6),
                              if (adShapeMode == 0) _buildControlButton("Swap L/R", Colors.brown, () { setState(() { isLBandRight = !isLBandRight; }); _saveSettings(); }), const SizedBox(width: 6),
                              _buildControlButton("Logo Pos", Colors.blueAccent, _changeLogoPosition), const SizedBox(width: 6),
                              _buildControlButton("Upload Logo", Colors.indigo, _uploadLogo), const SizedBox(width: 6),
                              _buildControlButton("Left Ad", Colors.pink, () => _pickAdMedia('left')), const SizedBox(width: 6),
                              _buildControlButton("Right Ad", Colors.pink, () => _pickAdMedia('right')), const SizedBox(width: 6),
                              _buildControlButton("Bottom Ad", Colors.pink, () => _pickAdMedia('bottom')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // --- 5. Bottom Compact Cameras ---
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    bottom: showControls ? 40 : -100,
                    left: 0, right: 0,
                    child: Container(
                      height: 100, color: Colors.black87.withOpacity(0.95),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: cameraList.length,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        itemBuilder: (context, index) => _buildCompactCameraBox(cameraList[index]),
                      ),
                    ),
                  ),

                  // --- 6. Ticker ---
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 40, color: Colors.blue[900],
                      child: Row(
                        children: [
                          Container(color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center, child: const Text("BREAKING NEWS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11))),
                          Expanded(child: Marquee(text: breakingNewsText, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), blankSpace: 100.0, velocity: 45.0, startPadding: 10.0))
                        ]
                      )
                    ),
                  )
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildAdBox(String path, VideoPlayerController? vCtrl) {
    return Container(
      color: Colors.black,
      child: path.isNotEmpty && File(path).existsSync()
          ? (vCtrl != null && vCtrl.value.isInitialized ? FittedBox(fit: BoxFit.fill, child: SizedBox(width: vCtrl.value.size.width, height: vCtrl.value.size.height, child: VideoPlayer(vCtrl))) : Image.file(File(path), fit: BoxFit.fill))
          : const Center(child: Text("AD SPACE", style: TextStyle(color: Colors.white30, fontSize: 10))),
    );
  }

  Widget _buildStudioLayout() {
    return Row(
      children: [
        Expanded(flex: 5, child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2)), child: _buildLiveFeed("REPORTER_CAM"))),
        Container(width: 2, color: Colors.white24),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              Expanded(child: Row(children: [Expanded(child: _buildHexBox(0)), Expanded(child: _buildHexBox(1)), Expanded(child: _buildHexBox(2))])),
              Expanded(child: Row(children: [Expanded(child: _buildHexBox(3)), Expanded(child: _buildHexBox(4)), Expanded(child: _buildHexBox(5))])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHexBox(int index) {
    bool isSelected = (selectedHexIndex == index);
    return GestureDetector(
      onTap: () => setState(() => selectedHexIndex = index),
      child: Container(
        decoration: BoxDecoration(color: Colors.black, border: Border.all(color: isSelected ? Colors.red : Colors.grey.shade800, width: isSelected ? 2.5 : 1)),
        child: Stack(
          children: [
            Positioned.fill(child: _buildLiveFeed(hexCams[index])),
            if(isSelected) Positioned(top: 2, left: 2, child: Container(padding: const EdgeInsets.all(2), color: Colors.red, child: const Text("SELECTED", style: TextStyle(color: Colors.white, fontSize: 8))))
          ],
        ),
      ),
    );
  }

  Widget _buildLiveFeed(String camId) {
    var camData = cameraList.firstWhere((cam) => cam['id'] == camId, orElse: () => cameraList[0]);
    if (camId == "REPORTER_CAM") {
      if (_phoneCamCtrl != null && _phoneCamCtrl!.value.isInitialized) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _phoneCamCtrl!.value.previewSize?.height ?? 1, height: _phoneCamCtrl!.value.previewSize?.width ?? 1, child: CameraPreview(_phoneCamCtrl!)))),
            Positioned(bottom: 10, right: 10, child: GestureDetector(onTap: _switchPhoneCamera, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.flip_camera_android, color: Colors.white, size: 20))))
          ],
        );
      }
      return const Center(child: CircularProgressIndicator(color: Colors.red));
    }
    if (camData['type'] == "IP" || camData['type'] == "DRONE") return _rtspControllers.containsKey(camId) ? VlcPlayer(controller: _rtspControllers[camId]!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.red))) : Container(color: Colors.black, child: const Center(child: Text("NO SIGNAL", style: TextStyle(color: Colors.red, fontSize: 10))));
    return Container(color: Colors.black, child: const Center(child: Text("NO SIGNAL", style: TextStyle(color: Colors.red, fontSize: 10))));
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _toggleRecord,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: isRecording ? Colors.red : Colors.grey[800], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1)),
        child: Row(children: [Icon(Icons.circle, color: isRecording ? Colors.white : Colors.red, size: 10), const SizedBox(width: 5), Text(isRecording ? "STOP REC" : "REC 4K", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))]),
      ),
    );
  }

  Widget _buildControlButton(String title, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))));
  }

  Widget _buildCompactCameraBox(Map<String, dynamic> cam) {
    bool isLive = isStudioMultiView ? hexCams.contains(cam['id']) : (liveCameraId == cam['id']);
    bool isActive = cam['active']; bool isMuted = cam['muted'];

    return Container(
      width: 100, margin: const EdgeInsets.only(right: 6),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.black, border: Border.all(color: isLive ? Colors.red : (isActive ? Colors.green : Colors.grey.shade800), width: isLive ? 2.5 : 1)),
              child: Stack(
                children: [
                  Center(child: Text(isActive ? "Live" : "OFF", style: TextStyle(color: isActive ? Colors.greenAccent : Colors.red, fontSize: 10))),
                  Positioned(top: 1, left: 1, child: Container(padding: const EdgeInsets.all(1), color: Colors.black54, child: Text(cam['type'], style: const TextStyle(color: Colors.yellow, fontSize: 7)))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(cam['name'], style: const TextStyle(color: Colors.white, fontSize: 9, overflow: TextOverflow.ellipsis)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    cam['active'] = !isActive;
                    if (cam['type'] == "IP" || cam['type'] == "DRONE") _toggleRTSPCamera(cam['id'], cam['url'], !isActive, cam['muted']);
                  });
                },
                child: Icon(isActive ? Icons.power_settings_new : Icons.power_off, color: isActive ? Colors.green : Colors.red, size: 16),
              ),
              const SizedBox(width: 5),
              GestureDetector(onTap: () => _toggleMute(cam), child: Icon(isMuted ? Icons.mic_off : Icons.mic, color: isMuted ? Colors.red : Colors.blueAccent, size: 16)),
              const SizedBox(width: 5),
              if (isActive)
                GestureDetector(
                  onTap: () => setState(() { if (isStudioMultiView) hexCams[selectedHexIndex] = cam['id']; else liveCameraId = cam['id']; }),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: isLive ? Colors.red : Colors.grey.shade700, borderRadius: BorderRadius.circular(2)), child: const Text("CUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8))),
                ),
            ],
          )
        ],
      ),
    );
  }
}
