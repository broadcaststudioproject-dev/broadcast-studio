import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera Error: \$e");
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
  String breakingNews = "కొత్తకోటలో భారీ ర్యాలీ.. ప్రజలతో మంత్రి సమావేశం.. మరిన్ని అప్‌డేట్స్ కోసం చూస్తూనే ఉండండి...";

  @override
  void initState() {
    super.initState();
    // యాప్ ఓపెన్ చేయగానే నిలువుగా (Portrait) ఉండేలా సెట్ చేస్తున్నాం
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
    _requestPermissions();
  }

  @override
  void dispose() {
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

  // ఫ్రంట్ / బ్యాక్ కెమెరా మార్చే కోడ్
  void _switchCamera() async {
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    await controller?.dispose();
    controller = CameraController(cameras[currentCameraIndex], ResolutionPreset.high);
    await controller!.initialize();
    if (mounted) setState(() {});
  }

  // స్క్రీన్ రొటేట్ చేసే కోడ్
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

  // వివరాలు మార్చుకునే ఎడిట్ బాక్స్
  void _showEditDialog() {
    TextEditingController locCtrl = TextEditingController(text: locationText);
    TextEditingController chCtrl = TextEditingController(text: channelName);
    TextEditingController nameCtrl = TextEditingController(text: reporterName);
    TextEditingController roleCtrl = TextEditingController(text: reporterRole);
    TextEditingController newsCtrl = TextEditingController(text: breakingNews);

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
                TextField(controller: newsCtrl, decoration: const InputDecoration(labelText: "Breaking News (బ్రేకింగ్ న్యూస్)"), maxLines: 3),
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
                  breakingNews = newsCtrl.text;
                  hideControls = true; // సేవ్ చేయగానే బటన్స్ మాయం అవుతాయి
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
          // స్క్రీన్ మీద టచ్ చేసినప్పుడు కంట్రోల్స్ తెప్పించడం
          if (hideControls) {
            setState(() { hideControls = false; });
          }
        },
        child: Stack(
          children: [
            // 1. కెమెరా వ్యూ
            SizedBox.expand(child: CameraPreview(controller!)),
            
            // 2. న్యూస్ గ్రాఫిక్స్
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      color: Colors.red,
                      child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: Colors.blue[900],
                      child: Text(channelName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ),
                  ),
                  
                  Positioned(
                    bottom: 70, left: 10,
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
                  
                  Positioned(
                    bottom: 10, left: 0, right: 0,
                    child: Container(
                      height: 40,
                      color: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          const Text("BREAKING NEWS: ", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 18)),
                          Expanded(
                            child: Marquee(
                              text: breakingNews,
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                              scrollAxis: Axis.horizontal,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              blankSpace: 50.0,
                              velocity: 40.0,
                              startPadding: 10.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. యూట్యూబ్ స్టైల్ టచ్ కంట్రోల్స్ (హైడ్ బటన్స్)
            if (!hideControls)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    // నల్లటి బ్యాక్‌గ్రౌండ్ మీద టచ్ చేస్తే మాయం అవ్వడం
                    setState(() { hideControls = true; });
                  },
                  child: Container(
                    color: Colors.black54, // యూట్యూబ్ లాగా లైట్ బ్లాక్ షేడ్
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

  // బటన్స్ డిజైన్ కోసం చిన్న ఫంక్షన్
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
