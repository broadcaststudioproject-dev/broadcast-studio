import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

void main() {
  runApp(const PocketPCRApp());
}

class PocketPCRApp extends StatelessWidget {
  const PocketPCRApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pocket PCR Studio',
      theme: ThemeData.dark(),
      home: const MasterPCRBoard(),
    );
  }
}

class MasterPCRBoard extends StatefulWidget {
  const MasterPCRBoard({Key? key}) : super(key: key);

  @override
  State<MasterPCRBoard> createState() => _MasterPCRBoardState();
}

class _MasterPCRBoardState extends State<MasterPCRBoard> {
  // --- Native Android USB ఛానెల్ ---
  static const MethodChannel _channel = MethodChannel('com.kingjvk.pocket_pcr/stream');
  int? _usbTextureId; 

  // --- IP / Drone కెమెరాల కంట్రోలర్స్ (Real RTSP Players) ---
  final Map<String, VlcPlayerController> _rtspControllers = {};

  // --- Master Controls ---
  bool showControls = true; 
  bool isRecording = false;
  bool showAds = true;
  bool splitScreenMode = false;
  
  String liveCameraId = "REPORTER_CAM";

  // --- 11 Cameras Setup (URLs తో సహా) ---
  final List<Map<String, dynamic>> cameraList = [
    {"id": "REPORTER_CAM", "name": "Reporter", "type": "PHONE", "active": true, "url": ""},
    {"id": "DRONE_1", "name": "DJI Drone", "type": "DRONE", "active": false, "url": "rtsp://192.168.1.1:554/live"}, // మీ డ్రోన్ IP మార్చుకోవచ్చు
    {"id": "HDMI_1", "name": "Sony Cam 1", "type": "USB", "active": false, "url": ""},
    {"id": "HDMI_2", "name": "Panasonic 2", "type": "USB", "active": false, "url": ""},
    {"id": "HDMI_3", "name": "PTZ Cam 3", "type": "USB", "active": false, "url": ""},
    {"id": "HDMI_4", "name": "Stage Cam 4", "type": "USB", "active": false, "url": ""},
    {"id": "HDMI_5", "name": "Wide Cam 5", "type": "USB", "active": false, "url": ""},
    {"id": "IP_1", "name": "CCTV Left", "type": "IP", "active": false, "url": "rtsp://wowzaec2demo.streamlock.net/vod/mp4:BigBuckBunny_115k.mp4"}, // టెస్టింగ్ డమ్మీ వీడియో
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

  // --- IP / డ్రోన్ కెమెరాలను నిజంగా ప్లే చేసే ఫంక్షన్ ---
  void _toggleRTSPCamera(String camId, String url, bool isActive) {
    if (isActive) {
      // కెమెరా ఆన్ చేయగానే నెట్‌వర్క్ నుండి విజువల్స్ తెస్తుంది
      _rtspControllers[camId] = VlcPlayerController.network(
        url,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(),
      );
    } else {
      // ఆఫ్ చేయగానే డేటా ఆగిపోతుంది (ఫోన్ హీట్ అవ్వకుండా)
      _rtspControllers[camId]?.stopRendererScanning();
      _rtspControllers[camId]?.dispose();
      _rtspControllers.remove(camId);
    }
  }

  void toggleRecord() {
    setState(() => isRecording = !isRecording);
    // (రికార్డింగ్ రియల్ కోడ్ స్టెప్-2 లో యాడ్ చేద్దాం)
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
              Positioned.fill(
                child: splitScreenMode ? _buildSplitScreenView() : _buildLiveFeed(liveCameraId),
              ),
              if (showAds) _buildAdsLayer(),
              AnimatedOpacity(
                opacity: showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !showControls,
                  child: Stack(
                    children: [
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
                                  title: splitScreenMode ? "SINGLE VIEW" : "SPLIT SCREEN",
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
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          height: 120,
                          color: Colors.black87.withOpacity(0.9),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: cameraList.length,
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                            itemBuilder: (context, index) => _buildCameraPreviewBox(cameraList[index]),
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
      ),
    );
  }

  Widget _buildSplitScreenView() {
    return Row(
      children: [
        Expanded(child: _buildLiveFeed("REPORTER_CAM")),
        Container(width: 2, color: Colors.white),
        Expanded(child: _buildLiveFeed(liveCameraId != "REPORTER_CAM" ? liveCameraId : "IP_1")),
      ],
    );
  }

  // --- అసలైన విజువల్స్ చూపించే బ్లాక్ (USB & RTSP) ---
  Widget _buildLiveFeed(String camId) {
    var camData = cameraList.firstWhere((cam) => cam['id'] == camId);
    
    // 1. HDMI/USB కెమెరా అయితే
    if (camData['type'] == "USB") {
      if (_usbTextureId != null) {
        return Texture(textureId: _usbTextureId!); 
      }
      return _buildNoSignal(camId, Icons.usb);
    } 
    // 2. IP లేదా డ్రోన్ కెమెరా అయితే (రియల్ వీడియో ప్లేయర్)
    else if (camData['type'] == "IP" || camData['type'] == "DRONE") {
      if (_rtspControllers.containsKey(camId)) {
        return VlcPlayer(
          controller: _rtspControllers[camId]!,
          aspectRatio: 16 / 9,
          placeholder: const Center(child: CircularProgressIndicator(color: Colors.red)),
        );
      }
      return _buildNoSignal(camId, Icons.wifi);
    }
    
    // 3. రిపోర్టర్ కెమెరా అయితే (తరువాత నేటివ్ ఫ్రంట్ కెమెరా పెడదాం)
    return Container(
      color: Colors.grey[900],
      child: const Center(child: Text("REPORTER CAM\n(Front Camera)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 30))),
    );
  }

  Widget _buildNoSignal(String name, IconData icon) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey, size: 50),
            const SizedBox(height: 10),
            Text("$name\nNO SIGNAL", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 20)),
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
        Positioned(
          bottom: showControls ? 140 : 60, left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: const Text("JANAMPALLY VINOD KUMAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18))),
              Container(color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), child: const Text("SPECIAL CORRESPONDENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
            ],
          ),
        ),
        Positioned(
          bottom: showControls ? 100 : 20, left: 10, right: 10,
          child: Container(
            height: 35, color: Colors.blue[900]?.withOpacity(0.9),
            child: Row(
              children: [
                Container(color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10), child: const Center(child: Text("BREAKING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                const Expanded(child: Center(child: Text("సత్యశోధక్ సమాజ్ ఫౌండేషన్ ఆధ్వర్యంలో ఉచిత శిక్షణ...", style: TextStyle(color: Colors.white, fontSize: 16)))),
              ],
            ),
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
    bool isLive = (liveCameraId == cam['id']);
    bool isActive = cam['active'];

    return Container(
      width: 130, margin: const EdgeInsets.only(right: 10),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isActive ? Colors.grey[800] : Colors.black,
                border: Border.all(color: isLive && !splitScreenMode ? Colors.red : (isActive ? Colors.green : Colors.grey[700]!), width: isLive ? 3 : 1),
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
                    // బ్యాకెండ్ కనెక్షన్స్ ట్రిగ్గర్ చేయడం
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
                  onTap: () => setState(() { liveCameraId = cam['id']; splitScreenMode = false; }),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: isLive ? Colors.red : Colors.grey, borderRadius: BorderRadius.circular(3)), child: const Text("CUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
                ),
            ],
          )
        ],
      ),
    );
  }
}
