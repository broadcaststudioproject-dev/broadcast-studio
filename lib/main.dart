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

  // టెక్స్ట్ వేరియబుల్స్ (ఎడిట్ చేసుకోవడానికి)
  String locationText = "LIVE KOTHAKOTA"; 
  String channelName = "SS\nYATRA\nTV";
  String reporterName = "VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String stateNews = "కొత్తకోటలో భారీ ర్యాలీ.. ప్రజలతో మంత్రి సమావేశం.. మరిన్ని అప్‌డేట్స్ కోసం చూస్తూనే ఉండండి...";
  String watermarkText = "SS YATRA TV";
  
  // టాప్ ఛానెల్ పేరు సైజ్ (ఇది మాత్రమే రీసైజ్ అవుతుంది)
  double channelNameSize = 14.0;

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

  // సందర్భాన్ని బట్టి డీటెయిల్స్ మార్చుకునే ఎడిట్ బాక్స్
  void _showEditDialog() {
    TextEditingController chCtrl = TextEditingController(text: channelName);
    TextEditingController chSizeCtrl = TextEditingController(text: channelNameSize.toString());

    TextEditingController watermarkCtrl = TextEditingController(text: watermarkText);
    TextEditingController locCtrl = TextEditingController(text: locationText);
    TextEditingController nameCtrl = TextEditingController(text: reporterName);
    TextEditingController roleCtrl = TextEditingController(text: reporterRole);
    TextEditingController newsCtrl = TextEditingController(text: stateNews);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("వివరాలు మార్చుకోండి (Edit)", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // టాప్ ఛానెల్ బాక్స్ 
                const Text("కుడివైపు పైన ఉండే ఛానెల్ పేరు", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                TextField(controller: chCtrl, decoration: const InputDecoration(labelText: "ఛానెల్ పేరు టైప్ చేయండి"), maxLines: 2),
                TextField(controller: chSizeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "దాని సైజ్ (ఉదా: 14)")),
                const Divider(thickness: 2),

                // కింద వరుసగా ఉండే పర్మినెంట్ సైజ్ బ్లాక్స్ (వీటి సైజులు ఆటోమేటిక్ గా ఫిక్స్ ఉంటాయి)
                const Text("కింద ఎడమవైపు వివరాలు (సందర్భాన్ని బట్టి)", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                TextField(controller: watermarkCtrl, decoration: const InputDecoration(labelText: "1. వాటర్‌మార్క్ పేరు")),
                TextField(controller: locCtrl, decoration: const InputDecoration(labelText: "2. లైవ్ లొకేషన్ (ఊరి పేరు)")),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "3. రిపోర్టర్ పేరు")),
                TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "4. రిపోర్టర్ హోదా")),
                const Divider(thickness: 2),

                // న్యూస్
                const Text("కింద స్క్రోల్ అయ్యే బ్రేకింగ్ న్యూస్", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                TextField(controller: newsCtrl, decoration: const InputDecoration(labelText: "ఇక్కడ వార్తను టైప్ చేయండి..."), maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  channelName = chCtrl.text;
                  channelNameSize = double.tryParse(chSizeCtrl.text) ?? 14.0;

                  watermarkText = watermarkCtrl.text;
                  locationText = locCtrl.text;
                  reporterName = nameCtrl.text;
                  reporterRole = roleCtrl.text;
                  stateNews = newsCtrl.text;
                  
                  hideControls = true; // సేవ్ చేయగానే క్లీన్ స్క్రీన్ వస్తుంది
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
                  // పైన కుడి వైపు టెక్స్ట్ బాక్స్ (దీనికి మాత్రమే సైజ్ ఎడిట్ ఆప్షన్ ఉంది)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.blue[900]?.withOpacity(0.8),
                      child: Text(channelName, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: channelNameSize)),
                    ),
                  ),

                  // ఎడమ వైపు కింద ఒకే వరుసలో వాటర్‌మార్క్, లొకేషన్, పేరు, హోదా (Fixed Sizes)
                  Positioned(
                    bottom: 90, left: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. వాటర్‌మార్క్ (ఫిక్స్‌డ్ సైజ్: 8)
                        Opacity(
                          opacity: 0.7, 
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.satellite_alt, color: Colors.white, size: 12), 
                              const SizedBox(width: 4),
                              Text(
                                watermarkText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8.0, // Fixed Size 8
                                  shadows: [Shadow(blurRadius: 2.0, color: Colors.black, offset: Offset(1.0, 1.0))]
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6), 
                        
                        // 2. లైవ్ లొకేషన్ (ఫిక్స్‌డ్ సైజ్: 8)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: Colors.red,
                          child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8.0)), // Fixed Size 8
                        ),
                        const SizedBox(height: 4), 
                        
                        // 3. రిపోర్టర్ పేరు (ఫిక్స్‌డ్ సైజ్: 9)
                        Container(
                          color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9.0)), // Fixed Size 9
                        ),
                        
                        // 4. రిపోర్టర్ హోదా (ఫిక్స్‌డ్ సైజ్: 8)
                        Container(
                          color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontSize: 8.0)), // Fixed Size 8
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

            // టచ్ కంట్రోల్స్ (హైడ్/ఎడిట్ బటన్స్)
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
