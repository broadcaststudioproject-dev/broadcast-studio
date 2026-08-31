import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:async';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  bool hideControls = false;
  int currentCameraIndex = 0;
  bool isLandscape = false;

  String locationText = "LIVE KOTHAKOTA";
  String channelName = "SS\nYATRA\nTV";
  String reporterName = "VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String stateNews = "కొత్తకోటలో భారీ ర్యాలీ.. ప్రజలతో మంత్రి సమావేశం.. మరిన్ని అప్‌డేట్స్ కోసం చూస్తూనే ఉండండి...";
  
  // గూగుల్ న్యూస్ కోసం
  String googleNews = "తాజా వార్తలు లోడ్ అవుతున్నాయి... దయచేసి వేచి ఉండండి...";
  Timer? _newsTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
    _requestPermissions();
    _fetchGoogleNews(); // యాప్ ఓపెన్ అవ్వగానే న్యూస్ లాగుతుంది
    
    // ప్రతి 10 నిమిషాలకు ఒకసారి ఆటోమేటిక్‌గా కొత్త వార్తలు అప్‌డేట్ అవుతాయి
    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _fetchGoogleNews();
    });
  }

  @override
  void dispose() {
    _newsTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  void _initCamera() {
    if (cameras.isEmpty) return;
    controller = CameraController(cameras[currentCameraIndex], ResolutionPreset.high);
    controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _switchCamera() async {
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    await controller?.dispose();
    controller = CameraController(cameras[currentCameraIndex], ResolutionPreset.high);
    await controller!.initialize();
    if (mounted) setState(() {});
  }

  void _toggleOrientation() {
    setState(() {
      isLandscape = !isLandscape;
    });
    if (isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  // గూగుల్ నుండి లైవ్ న్యూస్ తెచ్చే ఫంక్షన్ (తెలుగు)
  Future<void> _fetchGoogleNews() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = [];
        // టాప్ 15 వార్తలు తీసుకుంటున్నాం
        for (var item in items.take(15)) {
          titles.add(item.findElements('title').first.innerText);
        }
        if (titles.isNotEmpty && mounted) {
          setState(() {
            // వార్తల మధ్యలో గ్యాప్ మరియు బులెట్ పాయింట్ యాడ్ చేస్తున్నాం
            googleNews = titles.join("   ♦   ");
          });
        }
      }
    } catch (e) {
      debugPrint("News Error: $e");
    }
  }

  void _showEditDialog() {
    TextEditingController locCtrl = TextEditingController(text: locationText);
    TextEditingController chCtrl = TextEditingController(text: channelName);
    TextEditingController nameCtrl = TextEditingController(text: reporterName);
    TextEditingController roleCtrl = TextEditingController(text: reporterRole);
    TextEditingController newsCtrl = TextEditingController(text: stateNews);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("ఎడిట్ గ్రాఫిక్స్", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: locCtrl, decoration: const InputDecoration(labelText: "Live Location (లొకేషన్)")),
                TextField(controller: chCtrl, decoration: const InputDecoration(labelText: "Channel Logo Text (ఛానెల్ పేరు)"), maxLines: 3),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Reporter Name (రిపోర్టర్ పేరు)")),
                TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Designation (హోదా)")),
                TextField(controller: newsCtrl, decoration: const InputDecoration(labelText: "State News (మీరు టైప్ చేసే న్యూస్)"), maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  locationText = locCtrl.text;
                  channelName = chCtrl.text;
                  reporterName = nameCtrl.text;
                  reporterRole = roleCtrl.text;
                  stateNews = newsCtrl.text;
                  hideControls = true;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("SAVE", style: TextStyle(color: Colors.white)),
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.red)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (hideControls) {
            setState(() { hideControls = false; });
          }
        },
        child: Stack(
          children: [
            SizedBox.expand(child: CameraPreview(controller!)),
            
            SafeArea(
              child: Stack(
                children: [
                  // లొకేషన్ టాగ్
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      color: Colors.red,
                      child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  // ఛానెల్ లోగో
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.blue[900],
                      child: Text(channelName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ),
                  
                  // రిపోర్టర్ పేరు
                  Positioned(
                    bottom: 90, left: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                          child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                        ),
                        Container(
                          color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
                          child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                  
                  // డ్యూయల్ స్క్రోలింగ్ న్యూస్ బార్
                  Positioned(
                    bottom: 10, left: 0, right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // లైన్ 1: గూగుల్ లైవ్ న్యూస్ (బ్లూ కలర్)
                        Container(
                          height: 35,
                          color: Colors.blue[900],
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              const Text("LATEST NEWS: ", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 16)),
                              Expanded(
                                child: Marquee(
                                  text: googleNews,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                  scrollAxis: Axis.horizontal,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  blankSpace: 100.0,
                                  velocity: 35.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // లైన్ 2: మీరు రాసిన స్టేట్ న్యూస్ (రెడ్ కలర్)
                        Container(
                          height: 40,
                          color: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              const Text("STATE NEWS: ", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 18)),
                              Expanded(
                                child: Marquee(
                                  text: stateNews,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  scrollAxis: Axis.horizontal,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  blankSpace: 50.0,
                                  velocity: 45.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // యూట్యూబ్ స్టైల్ టచ్ కంట్రోల్స్
            if (!hideControls)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() { hideControls = true; });
                  },
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 35,
                        children: [
                          _buildControlButton(Icons.flip_camera_android, "Flip Cam", _switchCamera),
                          _buildControlButton(isLandscape ? Icons.screen_lock_portrait : Icons.screen_rotation, "Rotate", _toggleOrientation),
                          _buildControlButton(Icons.edit, "Edit", _showEditDialog),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white30,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
