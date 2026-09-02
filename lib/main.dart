import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:async';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

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

class _StudioScreenState extends State<StudioScreen> {
  CameraController? controller;
  VlcPlayerController? _vlcViewController;
  
  bool hideControls = false;
  int currentCameraIndex = 0;
  bool isLandscape = false;
  bool isIpCameraActive = false;
  bool isLiveBroadcasting = false;

  String ipCameraUrl = ""; 
  TextEditingController ipController = TextEditingController();

  // గ్రాఫిక్స్ టెక్స్ట్ వేరియబుల్స్
  String channelName = "SS\nYATRA\nTV";
  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA"; 
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String stateNews = "కొత్తకోటలో భారీ ర్యాలీ.. ప్రజలతో మంత్రి సమావేశం.. మరిన్ని అప్‌డేట్స్ కోసం చూస్తూనే ఉండండి...";
  String googleNews = "తాజా వార్తలు లోడ్ అవుతున్నాయి... దయచేసి వేచి ఉండండి...";
  
  // సోషల్ మీడియా & బ్రాడ్‌కాస్ట్ లింక్స్ (RTMP / Stream URLs)
  String ytUrl = "";
  String fbUrl = "";
  String instaUrl = "";
  String xUrl = "";
  String snapUrl = "";
  String threadsUrl = "";
  String iptvUrl = "";

  // సెలెక్షన్ ట్యాబ్స్ (Checkbox states)
  bool selectYt = false;
  bool selectFb = false;
  bool selectInsta = false;
  bool selectX = false;
  bool selectSnap = false;
  bool selectThreads = false;
  bool selectIptv = false;

  // ఎడిట్ కంట్రోలర్స్
  TextEditingController channelCtrl = TextEditingController();
  TextEditingController watermarkCtrl = TextEditingController();
  TextEditingController locCtrl = TextEditingController();
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController roleCtrl = TextEditingController();
  TextEditingController newsCtrl = TextEditingController();

  // సోషల్ కంట్రోలర్స్
  TextEditingController ytCtrl = TextEditingController();
  TextEditingController fbCtrl = TextEditingController();
  TextEditingController instaCtrl = TextEditingController();
  TextEditingController xCtrl = TextEditingController();
  TextEditingController snapCtrl = TextEditingController();
  TextEditingController threadsCtrl = TextEditingController();
  TextEditingController iptvCtrl = TextEditingController();

  double channelNameSize = 14.0;
  Timer? _newsTimer;

  @override
  void initState() {
    super.initState();
    channelCtrl.text = channelName;
    watermarkCtrl.text = watermarkText;
    locCtrl.text = locationText;
    nameCtrl.text = reporterName;
    roleCtrl.text = reporterRole;
    newsCtrl.text = stateNews;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    _initCamera();
    _requestPermissions();
    _fetchGoogleNews(); 
    
    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _fetchGoogleNews();
    });
  }

  @override
  void dispose() {
    _newsTimer?.cancel();
    controller?.dispose();
    _vlcViewController?.dispose();
    ipController.dispose();
    channelCtrl.dispose();
    watermarkCtrl.dispose();
    locCtrl.dispose();
    nameCtrl.dispose();
    roleCtrl.dispose();
    newsCtrl.dispose();
    ytCtrl.dispose();
    fbCtrl.dispose();
    instaCtrl.dispose();
    xCtrl.dispose();
    snapCtrl.dispose();
    threadsCtrl.dispose();
    iptvCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone, Permission.storage].request();
  }

  void _initCamera() {
    if (cameras.isEmpty) return;
    controller = CameraController(cameras[currentCameraIndex], ResolutionPreset.high);
    controller!.initialize().then((_) async {
      if (!mounted) return;
      await controller!.unlockCaptureOrientation();
      setState(() {});
    });
  }

  void _switchCamera() async {
    if (isIpCameraActive) return; 
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    await controller?.dispose();
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

  void _showIpInputDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("IP / Stream Link సెట్టింగ్స్", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipController,
                style: const TextStyle(color: Colors.yellow),
                decoration: const InputDecoration(labelText: "RTSP / HTTP / Direct Stream లింక్", labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("QR కోడ్ స్కానర్ యాక్టివేట్ అయింది!"), backgroundColor: Colors.green));
                },
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                label: const Text("Scan QR Code", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() { ipCameraUrl = ipController.text; });
                Navigator.pop(context);
                if (isIpCameraActive) {
                  _toggleIpCamera();
                  Future.delayed(const Duration(milliseconds: 500), () => _toggleIpCamera());
                } else {
                  _toggleIpCamera();
                }
              },
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
          title: const Text("గ్రాఫిక్స్ ఎడిట్ చేయండి", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: channelCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "ఛానల్ పేరు", labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: watermarkCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "వాటర్ మార్క్", labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: locCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "లొకేషన్", labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: nameCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "రిపోర్టర్ పేరు", labelStyle: TextStyle(color: Colors.white54))),
                TextField(controller: roleCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(labelText: "రిపోర్టర్ హోదా", labelStyle: TextStyle(color: Colors.white54))),
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
                  channelName = channelCtrl.text;
                  watermarkText = watermarkCtrl.text;
                  locationText = locCtrl.text;
                  reporterName = nameCtrl.text;
                  reporterRole = roleCtrl.text;
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

  // 🔥 మల్టీ-ప్లాట్‌ఫార్మ్ సోషల్ మీడియా & శాటిలైట్/IPTV లైవ్ మేనేజ్‌మెంట్ డైలాగ్ 🔥
  void _showMultiStreamDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("మల్టీ-ప్లాట్‌ఫార్మ్ లైవ్ స్ట్రీమింగ్ సెటప్", style: TextStyle(color: Colors.white, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("ప్రసారం చేయాల్సిన ప్లాట్‌ఫార్మ్‌లను సెలెక్ట్ చేసి అడ్రస్ ఇవ్వండి:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      title: const Text("YouTube Live", style: TextStyle(color: Colors.white)),
                      value: selectYt,
                      activeColor: Colors.red,
                      onChanged: (val) => setDialogState(() => selectYt = val!),
                    ),
                    if (selectYt) TextField(controller: ytCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "YouTube RTMP URL / Key", hintStyle: TextStyle(color: Colors.white38))),
                    
                    CheckboxListTile(
                      title: const Text("Facebook Live", style: TextStyle(color: Colors.white)),
                      value: selectFb,
                      activeColor: Colors.blue,
                      onChanged: (val) => setDialogState(() => selectFb = val!),
                    ),
                    if (selectFb) TextField(controller: fbCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "Facebook Stream URL", hintStyle: TextStyle(color: Colors.white38))),

                    CheckboxListTile(
                      title: const Text("Instagram Live", style: TextStyle(color: Colors.white)),
                      value: selectInsta,
                      activeColor: Colors.purple,
                      onChanged: (val) => setDialogState(() => selectInsta = val!),
                    ),
                    if (selectInsta) TextField(controller: instaCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "Instagram RTMP URL", hintStyle: TextStyle(color: Colors.white38))),

                    CheckboxListTile(
                      title: const Text("X (Twitter) Live", style: TextStyle(color: Colors.white)),
                      value: selectX,
                      activeColor: Colors.lightBlue,
                      onChanged: (val) => setDialogState(() => selectX = val!),
                    ),
                    if (selectX) TextField(controller: xCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "X Stream URL", hintStyle: TextStyle(color: Colors.white38))),

                    CheckboxListTile(
                      title: const Text("Snapchat / Threads", style: TextStyle(color: Colors.white)),
                      value: selectSnap,
                      activeColor: Colors.amber,
                      onChanged: (val) => setDialogState(() => selectSnap = val!),
                    ),
                    if (selectSnap) TextField(controller: snapCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "Snapchat/Threads URL", hintStyle: TextStyle(color: Colors.white38))),

                    CheckboxListTile(
                      title: const Text("IPTV / Cable / Satellite Server", style: TextStyle(color: Colors.white)),
                      value: selectIptv,
                      activeColor: Colors.green,
                      onChanged: (val) => setDialogState(() => selectIptv = val!),
                    ),
                    if (selectIptv) TextField(controller: iptvCtrl, style: const TextStyle(color: Colors.yellow), decoration: const InputDecoration(hintText: "IPTV / Cable Encoder URL", hintStyle: TextStyle(color: Colors.white38))),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    setState(() {
                      ytUrl = ytCtrl.text;
                      fbUrl = fbCtrl.text;
                      instaUrl = instaCtrl.text;
                      xUrl = xCtrl.text;
                      snapUrl = snapCtrl.text;
                      iptvUrl = iptvCtrl.text;
                      isLiveBroadcasting = true;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("సెలెక్ట్ చేసిన అన్ని ప్లాట్‌ఫార్మ్‌లకు లైవ్ ప్రసారం ప్రారంభించబడింది!"), backgroundColor: Colors.green),
                    );
                  },
                  child: const Text("Start Multi-Live", style: TextStyle(color: Colors.white)),
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

  Future<void> _fetchGoogleNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = [];
        for (var item in items.take(15)) {
          titles.add(item.findElements('title').first.innerText);
        }
        if (titles.isNotEmpty && mounted) setState(() { googleNews = titles.join("   ♦   "); });
      }
    } catch (e) {
      debugPrint("News Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCamReady = isIpCameraActive ? (_vlcViewController != null) : (controller != null && controller!.value.isInitialized);

    if (!isCamReady) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.red)));
    }

    double previewWidth = 1920;
    double previewHeight = 1080;
    if (!isIpCameraActive && controller != null) {
      previewWidth = controller!.value.previewSize?.width ?? 1920;
      previewHeight = controller!.value.previewSize?.height ?? 1080;
    }
    double boxWidth = isLandscape ? previewWidth : previewHeight;
    double boxHeight = isLandscape ? previewHeight : previewWidth;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () { 
          setState(() { hideControls = !hideControls; }); 
        },
        child: Stack(
          children: [
            Container(
              width: double.infinity, height: double.infinity, color: Colors.black,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: boxWidth, height: boxHeight,
                  child: isIpCameraActive && _vlcViewController != null
                      ? VlcPlayer(controller: _vlcViewController!, aspectRatio: 16 / 9, placeholder: const Center(child: CircularProgressIndicator(color: Colors.red)))
                      : CameraPreview(controller!),
                ),
              ),
            ),
            
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.redAccent.withOpacity(0.8), width: 4.0)),
                ),
              ),
            ),
            
            // లైవ్ బ్రాడ్‌కాస్ట్ ఇండికేటర్ (LIVE ON AIR)
            if (isLiveBroadcasting)
              Positioned(
                top: 30, left: 30,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: Colors.red,
                  child: const Row(
                    children: [
                      Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                      SizedBox(width: 5),
                      Text("MULTI-LIVE ON", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),

            Positioned(top: 30, right: 30, child: Container(padding: const EdgeInsets.all(8), color: Colors.blue[900]?.withOpacity(0.8), child: Text(channelName, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: channelNameSize)))),
            Positioned(
              bottom: 95, left: 15, 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (watermarkText.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 5, left: 2), child: Text(watermarkText, style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 13.0, shadows: const [Shadow(blurRadius: 2.0, color: Colors.black)])),),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), color: Colors.red, child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.0))),
                  const SizedBox(height: 4), 
                  Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14.0))),
                  Container(color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontSize: 12.0))),
                ],
              ),
            ),
            Positioned(
              bottom: 3, left: 3, right: 3, 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 35, color: Colors.blue[900], padding: const EdgeInsets.symmetric(horizontal: 10), 
                    child: Row(children: [const Text("LATEST NEWS: ", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)), Expanded(child: Marquee(text: googleNews, style: const TextStyle(color: Colors.white), blankSpace: 100.0, velocity: 35.0))]),
                  ),
                  Container(
                    height: 40, color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10), 
                    child: Row(children: [const Text("STATE NEWS: ", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 18)), Expanded(child: Marquee(text: stateNews, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), blankSpace: 50.0, velocity: 45.0))]),
                  ),
                ],
              ),
            ),

            if (!hideControls)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center, spacing: 20, runSpacing: 20,
                      children: [
                        _buildControlButton(Icons.flip_camera_android, "Phone Cam", _switchCamera, Colors.white),
                        _buildControlButton(Icons.wifi_tethering, "IP Cam", _toggleIpCamera, isIpCameraActive ? Colors.green : Colors.orange),
                        _buildControlButton(Icons.edit, "Edit Text", _showEditDialog, Colors.blue),
                        _buildControlButton(Icons.settings_ethernet, "Set IP", _showIpInputDialog, Colors.tealAccent),
                        _buildControlButton(Icons.live_tv, "Multi-Live", _showMultiStreamDialog, Colors.redAccent), // 🔥 కొత్త మల్టీ-స్ట్రీమ్ బటన్
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
          CircleAvatar(radius: 30, backgroundColor: Colors.white30, child: Icon(icon, color: iconColor, size: 30)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
