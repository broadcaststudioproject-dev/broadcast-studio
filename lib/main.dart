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

  // టెక్స్ట్ మరియు వాటర్‌మార్క్ వేరియబుల్స్
  String locationText = "LIVE KOTHAKOTA"; 
  String channelName = "SS\nYATRA\nTV";
  String reporterName = "VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String stateNews = "కొత్తకోటలో భారీ ర్యాలీ.. ప్రజలతో మంత్రి సమావేశం.. మరిన్ని అప్‌డేట్స్ కోసం చూస్తూనే ఉండండి...";
  
  // కొత్త వాటర్‌మార్క్ వేరియబుల్స్
  String watermarkText = "SS YATRA TV";
  double watermarkSize = 24.0; // డీఫాల్ట్ సైజ్

  String googleNews = "తాజా వార్తలు లోడ్ అవుతున్నాయి... దయచేసి వేచి ఉండండి...";
  Timer? _newsTimer;

  @override
  void initState() {
    super.initState();
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
        if (titles.isNotEmpty && mounted) {
          setState(() {
            googleNews = titles.join("   ♦   ");
          });
        }
      }
    } catch (e) {
      debugPrint("News Error: \$e");
    }
  }

  // ఎడిట్ పాప్-అప్
  void _showEditDialog() {
    TextEditingController locCtrl = TextEditingController(text: locationText);
    TextEditingController chCtrl = TextEditingController(text: channelName);
    TextEditingController nameCtrl = TextEditingController(text: reporterName);
    TextEditingController roleCtrl = TextEditingController(text: reporterRole);
    TextEditingController newsCtrl = TextEditingController(text: stateNews);
    
    // వాటర్‌మార్క్ కోసం కొత్త కంట్రోలర్స్
    TextEditingController watermarkCtrl = TextEditingController(text: watermarkText);
    TextEditingController watermarkSizeCtrl = TextEditingController(text: watermarkSize.toString());

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
                TextField(controller: chCtrl, decoration: const InputDecoration(labelText: "Top Edit Text (కుడివైపు టెక్స్ట్)"), maxLines: 2),
                
                // వాటర్‌మార్క్ సెట్టింగ్స్
                const Divider(thickness: 2, height: 30),
                const Text("Watermark Settings", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                TextField(controller: watermarkCtrl, decoration: const InputDecoration(labelText: "Watermark Name (వాటర్‌మార్క్ పేరు)")),
                TextField(
                  controller: watermarkSizeCtrl, 
                  keyboardType: TextInputType.number, 
                  decoration: const InputDecoration(labelText: "Watermark Size (సైజ్: ఉదా|| 20, 30, 40)")
                ),
                const Divider(thickness: 2, height: 30),

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
                  
                  // వాటర్‌మార్క్ అప్‌డేట్
                  watermarkText = watermarkCtrl.text;
                  watermarkSize = double.tryParse(watermarkSizeCtrl.text) ?? 24.0;
                  
                  hideControls = true; // సేవ్ చేయగానే బటన్స్ ఆటోమేటిక్ గా హైడ్ అవుతాయి
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
                  // పైన ఎడమ వైపు లొకేషన్ 
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      color: Colors.red,
                      child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // పైన కుడి వైపు చిన్న టెక్స్ట్
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.blue[900]?.withOpacity(0.8),
                      child: Text(channelName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),

                  // 🔥 కొత్త ఫీచర్: స్క్రీన్ మధ్యభాగంలో ఎడమవైపు పర్మినెంట్ వాటర్‌మార్క్ 🔥
                  Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Opacity(
                        opacity: 0.5, // 50% ట్రాన్స్‌పరెంట్ (గ్రీన్ మ్యాట్ ఫీల్)
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(Icons.satellite_alt, color: Colors.white, size: watermarkSize * 1.2), // సైజ్‌ని బట్టి ఐకాన్ మారుతుంది
                            const SizedBox(width: 8),
                            Text(
                              watermarkText,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: watermarkSize, // మీరు ఇచ్చిన సైజ్ ప్రకారం
                                shadows: const [
                                  Shadow(blurRadius: 3.0, color: Colors.black, offset: Offset(1.5, 1.5))
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // కింద రిపోర్టర్ పేరు మరియు హోదా
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
                  
                  // కింద స్క్రోలింగ్ న్యూస్
                  Positioned(
                    bottom: 10, left: 0, right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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

            // టచ్ కంట్రోల్స్ (హైడ్ బటన్స్)
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
                        spacing: 30,
                        runSpacing: 20,
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
