import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  bool showControls = true; 
  bool isRecording = false;
  bool showAds = true;
  
  bool isStudioMultiView = true;
  int selectedHexIndex = 0; 
  List<String> hexCams = ["IP_1", "IP_2", "DRONE_1", "IP_3", "IP_4", "HDMI_1"];
  
  String liveCameraId = "REPORTER_CAM";

  String breakingNewsText = "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";
  Timer? _newsTimer;

  String channelLogoPath = "";
  int logoPosition = 0; 
  int adShapeMode = 0;

  final ImagePicker _picker = ImagePicker();

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

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _fetchBreakingNews();
    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _fetchBreakingNews();
    });
  }

  Future<void> _loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      logoPosition = prefs.getInt('logoPosition') ?? 0;
      adShapeMode = prefs.getInt('adShapeMode') ?? 0;
      String savedLogo = prefs.getString('channelLogoPath') ?? "";
      if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) {
        channelLogoPath = savedLogo;
      }
    });
  }

  Future<void> _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('logoPosition', logoPosition);
    await prefs.setInt('adShapeMode', adShapeMode);
    if (channelLogoPath.isNotEmpty) {
      await prefs.setString('channelLogoPath', channelLogoPath);
    }
  }

  Future<void> _fetchBreakingNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = [];
        for (var item in items.take(15)) {
          titles.add(item.findElements('title').first.innerText);
        }
        if (titles.isNotEmpty && mounted) {
          setState(() {
            breakingNewsText = titles.join("   ♦   ");
          });
        }
      }
    } catch (e) {
      debugPrint("News Fetch Error: $e");
    }
  }

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

  void _changeLogoPosition() {
    setState(() {
      logoPosition = (logoPosition + 1) % 4;
    });
    _saveSettings();
    String posName = ["Top Left", "Top Right", "Bottom Left", "Bottom Right"][logoPosition];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("లోగో స్థానం: $posName"), backgroundColor: Colors.amber));
  }

  Future<void> _uploadLogo() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          channelLogoPath = image.path;
        });
        await _saveSettings();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("లోగో విజయవంతంగా అప్‌లోడ్ అయ్యింది!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("Logo Upload Error: $e");
    }
  }

  @override
  void dispose() {
    _stopUsbCamera();
    _newsTimer?.cancel();
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
                child: Padding(
                  padding: EdgeInsets.only(bottom: showControls ? 145.0 : 40.0),
                  child: isStudioMultiView ? _buildStudioLayout() : _buildLiveFeed(liveCameraId),
                ),
              ),

              Positioned(
                top: (logoPosition == 0 || logoPosition == 1) ? 15.0 : null,
                bottom: (logoPosition == 2 || logoPosition == 3) ? 55.0 : null,
                left: (logoPosition == 0 || logoPosition == 2) ? 15.0 : null,
                right: (logoPosition == 1 || logoPosition == 3) ? 15.0 : null,
                child: channelLogoPath.isNotEmpty
                    ? SizedBox(
                        width: 60, height: 60,
                        child: Image.file(File(channelLogoPath), fit: BoxFit.contain),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        color: Colors.red[900]?.withOpacity(0.9),
                        child: const Text("SS YATRA TV", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
              ),

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
                          _buildRecordButton(),
                          const SizedBox(width: 6),
                          _buildControlButton(
                            title: isStudioMultiView ? "FULL SCREEN" : "STUDIO VIEW",
                            color: isStudioMultiView ? Colors.blue.shade800 : Colors.purple.shade800,
                            onTap: () => setState(() => isStudioMultiView = !isStudioMultiView),
                          ),
                          const SizedBox(width: 6),
                          _buildControlButton(title: "Logo Pos", color: Colors.blueAccent, onTap: _changeLogoPosition),
                          const SizedBox(width: 6),
                          _buildControlButton(title: "Upload Logo", color: Colors.teal, onTap: _uploadLogo),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                bottom: showControls ? 40 : -100,
                left: 0, right: 0,
                child: Container(
                  height: 100,
                  color: Colors.black87.withOpacity(0.95),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: cameraList.length,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    itemBuilder: (context, index) => _buildCompactCameraBox(cameraList[index]),
                  ),
                ),
              ),

              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 40,
                  color: Colors.blue[900],
                  child: Row(
                    children: [
                      Container(
                        color: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: const Text("BREAKING NEWS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11))
                      ),
                      Expanded(
                        child: Marquee(
                          text: breakingNewsText,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          blankSpace: 100.0,
                          velocity: 45.0,
                          startPadding: 10.0,
                        ),
                      )
                    ]
                  )
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudioLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: _buildLiveFeed("REPORTER_CAM")),
                const Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.red,
                    child: Text("REPORTER (MAIN)", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
        Container(width: 2, color: Colors.white24),
        Expanded(
          flex: 6,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildHexBox(0)),
                    Expanded(child: _buildHexBox(1)),
                    Expanded(child: _buildHexBox(2)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildHexBox(3)),
                    Expanded(child: _buildHexBox(4)),
                    Expanded(child: _buildHexBox(5)),
                  ],
                ),
              ),
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
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: isSelected ? Colors.red : Colors.grey.shade800, width: isSelected ? 2.5 : 1),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: _buildLiveFeed(hexCams[index])),
            Positioned(
              top: 3, left: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: isSelected ? Colors.red : Colors.black54, borderRadius: BorderRadius.circular(2)),
                child: Text("B${index + 1}: ${hexCams[index]}", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
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
      child: const Center(child: Text("REPORTER CAM\n(Front Camera)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 14))),
    );
  }

  Widget _buildNoSignal(String name, IconData icon) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey, size: 24),
            const SizedBox(height: 3),
            Text("$name\nNO SIGNAL", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: toggleRecord,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: isRecording ? Colors.red : Colors.grey[800], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white, width: 1)),
        child: Row(
          children: [
            Icon(Icons.circle, color: isRecording ? Colors.white : Colors.red, size: 10),
            const SizedBox(width: 5),
            Text(isRecording ? "REC 4K" : "STANDBY", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({required String title, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
      ),
    );
  }

  Widget _buildCompactCameraBox(Map<String, dynamic> cam) {
    bool isLive = isStudioMultiView ? hexCams.contains(cam['id']) : (liveCameraId == cam['id']);
    bool isActive = cam['active'];

    return Container(
      width: 100, margin: const EdgeInsets.only(right: 6),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: isLive ? Colors.red : (isActive ? Colors.green : Colors.grey.shade800), width: isLive ? 2.5 : 1),
              ),
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
          const SizedBox(height: 2),
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
                child: Icon(isActive ? Icons.power_settings_new : Icons.power_off, color: isActive ? Colors.green : Colors.red, size: 16),
              ),
              const SizedBox(width: 8),
              if (isActive)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isStudioMultiView) {
                        hexCams[selectedHexIndex] = cam['id']; 
                      } else {
                        liveCameraId = cam['id']; 
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), 
                    decoration: BoxDecoration(color: isLive ? Colors.red : Colors.grey.shade700, borderRadius: BorderRadius.circular(2)), 
                    child: const Text("CUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8)),
                  ),
                ),
            ],
          )
        ],
      ),
    );
  }
}
