import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:marquee/marquee.dart';

class MasterPCRBoard extends StatefulWidget {
  const MasterPCRBoard({Key? key}) : super(key: key);

  @override
  State<MasterPCRBoard> createState() => _MasterPCRBoardState();
}

class _MasterPCRBoardState extends State<MasterPCRBoard> {
  static const MethodChannel _channel = MethodChannel('com.kingjvk.pocket_pcr/stream');
  int? _usbTextureId; 
  final Map<String, VlcPlayerController> _rtspControllers = {};

  bool showControls = true; 
  bool isRecording = false;
  bool showAds = true;
  bool splitScreenMode = false;
  
  // Single view కోసం మెయిన్ కెమెరా
  String liveCameraId = "REPORTER_CAM";

  // Quad (4) Split Screen కోసం కెమెరాలు
  List<String> quadCameras = ["REPORTER_CAM", "IP_1", "HDMI_1", "DRONE_1"];
  // ఏ బాక్స్ సెలెక్ట్ అయ్యిందో తెలుసుకోవడానికి ఇండెక్స్ (0, 1, 2, 3)
  int selectedQuadIndex = 0;

  final List<Map<String, dynamic>> cameraList = [
    {"id": "REPORTER_CAM", "name": "Reporter", "type": "PHONE", "active": true, "url": ""},
    {"id": "DRONE_1", "name": "DJI Drone", "type": "DRONE", "active": false, "url": "rtsp://192.168.1.1:554/live"}, 
    {"id": "HDMI_1", "name": "Sony Cam 1", "type": "USB", "active": false, "url": ""},
    {"id": "HDMI_2", "name": "Panasonic 2", "type": "USB", "active": false, "url": ""},
    {"id": "HDMI_3", "name": "PTZ Cam 3", "type": "USB", "active": false, "url": ""},
    {"id": "HDMI_4", "name": "Stage Cam 4", "type": "USB", "active": false, "url": ""},
    {"id": "HDMI_5", "name": "Wide Cam 5", "type": "USB", "active": false, "url": ""},
    {"id": "IP_1", "name": "CCTV Left", "type": "IP", "active": false, "url": "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mp4"}, 
    {"id": "IP_2", "name": "CCTV Right", "type": "IP", "active": false, "url": "rtsp://192.168.1.100:8080/video"},
    {"id": "IP_3", "name": "Mobile WiFi 1", "type": "IP", "active": false, "url": "rtsp://192.168.1.101:8080/video"},
    {"id": "IP_4", "name": "Mobile WiFi 2", "type": "IP", "active": false, "url": "rtsp://192.168.1.102:8080/video"},
  ];

  Future<void> _startUsbCamera() async {
    try {
      final int textureId = await _channel.invokeMethod('startUsbCamera');
      setState(() => _usbTextureId = textureId);
    } catch (e) {
      debugPrint("USB Error: $e");
    }
  }

  Future<void> _stopUsbCamera() async {
    try {
      await _channel.invokeMethod('stopUsbCamera');
      setState(() => _usbTextureId = null);
    } catch (e) {}
  }

  void _toggleRTSPCamera(String camId, String url, bool isActive) {
    if (isActive) {
      _rtspControllers[camId] = VlcPlayerController.network(
        url,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(),
      );
    } else {
      _rtspControllers[camId]?.stopRendererScanning();
      _rtspControllers[camId]?.dispose();
      _rtspControllers.remove(camId);
    }
  }

  void toggleRecord() {
    setState(() => isRecording = !isRecording);
  }

  @override
  void dispose() {
    _stopUsbCamera();
    for (var controller in _rtspControllers.values) {
      controller.dispose();
    }
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
            children: [
              // 1. మెయిన్ వీడియో వ్యూ
              Positioned(
                top: 0, left: 0, right: 0, 
                // కంట్రోల్స్ ఆన్‌లో ఉంటే వీడియో కింద దాకా వెళ్లకుండా కట్ అవుతుంది.
                bottom: showControls ? 160 : 0, 
                child: splitScreenMode ? _buildQuadScreenView() : _buildLiveFeed(liveCameraId),
              ),

              // 2. Ads మరియు Reporter Badge
              if (showAds) _buildAdsLayer(),

              // 3. Controls (కెమెరా లిస్ట్ & పైన బటన్స్)
              AnimatedOpacity(
                opacity: showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !showControls,
                  child: Stack(
                    children: [
                      // పైన ఉన్న బటన్స్
                      Positioned(
                        top: 10, left: 10, right: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _buildRecordButton(),
                                const SizedBox(width: 10),
                                _buildControlButton(
                                  title: splitScreenMode ? "SINGLE VIEW" : "4 SPLIT SCREEN",
                                  color: splitScreenMode ? Colors.blue : Colors.grey.withOpacity(0.8),
                                  onTap: () => setState(() => splitScreenMode = !splitScreenMode),
                                ),
                                const SizedBox(width: 10),
                                _buildControlButton(
                                  title: showAds ? "ADS: ON" : "ADS: OFF",
                                  color: showAds ? Colors.green : Colors.orange,
                                  onTap: () => setState(() => showAds = !showAds),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                              child: const Text("Double Tap to Hide", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      
                      // కింద ఉన్న కెమెరా లిస్ట్ మరియు టిక్కర్
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ఇక్కడ బ్రేకింగ్ న్యూస్ టిక్కర్
                            Container(
                              height: 35, color: Colors.blue[900]?.withOpacity(0.9),
                              child: Row(
                                children: [
                                  Container(color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10), child: const Center(child: Text("BREAKING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                                  Expanded(
                                    child: Marquee(
                                      text: "సత్యశోధక్ సమాజ్ ఫౌండేషన్ ఆధ్వర్యంలో ఉచిత శిక్షణ, గూగుల్ ఫీడ్ న్యూస్ అప్డేట్స్ లోడ్ అవుతున్నాయి...   ♦   ",
                                      style: const TextStyle(color: Colors.white, fontSize: 16),
                                      blankSpace: 50.0,
                                      velocity: 40.0,
                                    )
                                  ),
                                ],
                              ),
                            ),
                            // ఇక్కడ 11 కెమెరాల లిస్ట్
                            Container(
                              height: 125,
                              color: Colors.black87.withOpacity(0.9),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: cameraList.length,
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                                itemBuilder: (context, index) => _buildCameraPreviewBox(cameraList[index]),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  // --- 4 బాక్సుల (Quad) స్ప్లిట్ స్క్రీన్ డిజైన్ ---
  Widget _buildQuadScreenView() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildQuadBox(0)),
              Container(width: 2, color: Colors.white),
              Expanded(child: _buildQuadBox(1)),
            ],
          ),
        ),
        Container(height: 2, color: Colors.white),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildQuadBox(2)),
              Container(width: 2, color: Colors.white),
              Expanded(child: _buildQuadBox(3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuadBox(int index) {
    bool isSelected = (selectedQuadIndex == index);
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedQuadIndex = index;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected && showControls ? Colors.redAccent : Colors.transparent, 
            width: 3
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: _buildLiveFeed(quadCameras[index])),
            if (showControls)
              Positioned(
                top: 5, left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  color: Colors.black54,
                  child: Text(
                    "CAM ${index + 1}", 
                    style: TextStyle(color: isSelected ? Colors.redAccent : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildLiveFeed(String camId) {
    var camData = cameraList.firstWhere((cam) => cam['id'] == camId, orElse: () => cameraList[0]);
    
    if (camData['type'] == "USB") {
      if (_usbTextureId != null) {
        return Texture(textureId: _usbTextureId!); 
      }
      return _buildNoSignal(camData['name'], Icons.usb);
    } 
    else if (camData['type'] == "IP" || camData['type'] == "DRONE") {
      if (_rtspControllers.containsKey(camId)) {
        return VlcPlayer(
          controller: _rtspControllers[camId]!,
          aspectRatio: 16 / 9,
          placeholder: const Center(child: CircularProgressIndicator(color: Colors.red)),
        );
      }
      return _buildNoSignal(camData['name'], Icons.wifi);
    }
    
    return Container(
      color: Colors.grey[900],
      child: const Center(child: Text("REPORTER CAM\n(Front Camera)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 20))),
    );
  }

  Widget _buildNoSignal(String name, IconData icon) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey, size: 40),
            const SizedBox(height: 5),
            Text("$name\nNO SIGNAL", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdsLayer() {
    return Stack(
      children: [
        Positioned(
          top: 20, right: 20,
          child: Container(padding: const EdgeInsets.all(5), color: Colors.red, child: const Text("SS YATRA TV", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ),
        // బ్యాడ్జ్ పొజిషన్ కింద కెమెరా లిస్ట్ మరియు టిక్కర్ పైకి వెళ్ళింది
        Positioned(
          bottom: showControls ? 170 : 20, left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: const Text("JANAMPALLY VINOD KUMAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18))),
              Container(color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), child: const Text("SPECIAL CORRESPONDENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: toggleRecord,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(color: isRecording ? Colors.red : Colors.grey[800], borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.white, width: 1)),
        child: Row(
          children: [
            Icon(Icons.circle, color: isRecording ? Colors.white : Colors.red, size: 14),
            const SizedBox(width: 8),
            Text(isRecording ? "REC 4K" : "STANDBY", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({required String title, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)), child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildCameraPreviewBox(Map<String, dynamic> cam) {
    // సింగిల్ మోడ్‌లో ఉంటే liveCameraId తో చెక్ చేస్తాం. స్ప్లిట్ మోడ్‌లో ఉంటే quadCameras లిస్ట్‌లో ఉందో లేదో చూస్తాం.
    bool isLive = splitScreenMode ? quadCameras.contains(cam['id']) : (liveCameraId == cam['id']);
    bool isActive = cam['active'];

    return Container(
      width: 130, margin: const EdgeInsets.only(right: 10),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isActive ? Colors.grey[800] : Colors.black,
                border: Border.all(color: isLive ? Colors.red : (isActive ? Colors.green : Colors.grey[700]!), width: isLive ? 3 : 1),
              ),
              child: Stack(
                children: [
                  Center(child: Text(isActive ? "Preview (Live)" : "OFF", style: TextStyle(color: isActive ? Colors.greenAccent : Colors.red, fontSize: 12))),
                  Positioned(top: 2, left: 2, child: Container(padding: const EdgeInsets.all(2), color: Colors.black54, child: Text(cam['type'], style: const TextStyle(color: Colors.yellow, fontSize: 9)))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(cam['name'], style: const TextStyle(color: Colors.white, fontSize: 10, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    cam['active'] = !isActive;
                    if (cam['type'] == "USB") {
                      if (!isActive) _startUsbCamera(); else _stopUsbCamera();
                    } else if (cam['type'] == "IP" || cam['type'] == "DRONE") {
                      _toggleRTSPCamera(cam['id'], cam['url'], !isActive);
                    }
                  });
                },
                child: Icon(isActive ? Icons.power_settings_new : Icons.power_off, color: isActive ? Colors.green : Colors.red, size: 20),
              ),
              const SizedBox(width: 15),
              if (isActive)
                GestureDetector(
                  onTap: () => setState(() { 
                    if (splitScreenMode) {
                      // స్ప్లిట్ మోడ్: సెలెక్ట్ చేసిన బాక్స్‌లోకి ఈ కెమెరా పంపిస్తాం
                      quadCameras[selectedQuadIndex] = cam['id'];
                    } else {
                      // సింగిల్ మోడ్: మెయిన్ స్క్రీన్‌కి ఈ కెమెరా పంపిస్తాం
                      liveCameraId = cam['id']; 
                    }
                  }),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(3)), child: const Text("CUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
                ),
            ],
          )
        ],
      ),
    );
  }
}
