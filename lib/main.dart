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
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
  String stateNews = "కొత్తకోటలో భారీ ర్యాలీ.. ప్రజలతో మంత్రి సమావేశం.. మరిన్ని అప్‌డేట్స్ కోసం చూస్తూనే ఉండండి...";
  String watermarkText = "SS YATRA TV";
  
  double channelNameSize = 14.0;

  String googleNews = "తాజా వార్తలు లోడ్ అవుతున్నాయి... దయచేసి వేచి ఉండండి...";
  Timer? _newsTimer;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  void _initCamera() {
    if (cameras.isEmpty) return;
    controller = CameraController(cameras[currentCameraIndex], ResolutionPreset.high);
    controller!.initialize().then((_) async {
      if (!mounted) return;
      // 🔥 కెమెరా ఓరియంటేషన్‌ను అన్‌లాక్ చేస్తున్నాం (దీనివల్లే తలక్రిందులు కాదు) 🔥
      await controller!.unlockCaptureOrientation();
      setState(() {});
    });
  }

  void _switchCamera() async {
    if (cameras.length < 2) return;
    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;
    await controller?.dispose();
    controller = CameraController(cameras[currentCameraIndex], ResolutionPreset.high);
    await controller!.initialize();
    await controller!.unlockCaptureOrientation();
    if (mounted) setState(() {});
  }

  void _toggleOrientation() async {
    setState(() {
      isLandscape = !isLandscape;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (isLandscape) {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
    } else {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    // 🔥 స్క్రీన్ తిప్పిన ప్రతిసారీ కెమెరా యాంగిల్ ఆటోమేటిక్ గా సెట్ అవ్వడానికి అన్‌లాక్ 🔥
    await controller?.unlockCaptureOrientation();
    setState(() {});
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
          title: const Text("వివరాలు మార్చుకోండి", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("కుడివైపు పైన ఉండే ఛానెల్ పేరు", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                TextField(controller: chCtrl, decoration: const InputDecoration(labelText: "ఛానెల్ పేరు"), maxLines: 2),
                TextField(controller: chSizeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "సైజ్ (ఉదా: 14)")),
                const Divider(thickness: 2),

                const Text("కింద ఎడమవైపు వివరాలు (Fixed Size)", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                TextField(controller: watermarkCtrl, decoration: const InputDecoration(labelText: "1. వాటర్‌మార్క్")),
                TextField(controller: locCtrl, decoration: const InputDecoration(labelText: "2. లైవ్ లొకేషన్")),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "3. రిపోర్టర్ పేరు")),
                TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "4. హోదా")),
                const Divider(thickness: 2),

                const Text("స్క్రోలింగ్ న్యూస్", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                TextField(controller: newsCtrl, decoration: const InputDecoration(labelText: "వార్తను టైప్ చేయండి"), maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                Navigator.pop(context);
              }, 
              child: const Text("CANCEL")
            ),
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
                  hideControls = true; 
                });
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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

    // 🔥 కెమెరా పొడవు, వెడల్పులను రొటేషన్ కి తగ్గట్లు ఆటోమేటిక్ గా మార్చే లాజిక్ 🔥
    double previewWidth = controller!.value.previewSize?.width ?? 1920;
    double previewHeight = controller!.value.previewSize?.height ?? 1080;
    
    double boxWidth = isLandscape ? previewWidth : previewHeight;
    double boxHeight = isLandscape ? previewHeight : previewWidth;

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
            // 1. కెమెరా ఫీడ్ (ఇకపై సాగిపోదు, రొటేట్ చేస్తే కరెక్ట్ గా వస్తుంది)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: boxWidth,
                  height: boxHeight,
                  child: CameraPreview(controller!),
                ),
              ),
            ),
            
            // 2. ప్రొఫెషనల్ బ్రాడ్‌కాస్ట్ బోర్డర్ 
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.red.withOpacity(0.9), 
                      width: 2.0, 
                    ),
                  ),
                ),
              ),
            ),
            
            // 3. గ్రాఫిక్స్ 
            Stack(
              children: [
                // పైన కుడి వైపు బాక్స్ 
                Positioned(
                  top: 30, right: 30, 
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.blue[900]?.withOpacity(0.8),
                    child: Text(channelName, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: channelNameSize)),
                  ),
                ),

                // ఎడమ వైపు కింద ఒకే వరుసలో
                Positioned(
                  bottom: 95, left: 15, 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Opacity(
                        opacity: 0.8, 
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.satellite_alt, color: Colors.white, size: 16), 
                            const SizedBox(width: 4),
                            Text(
                              watermarkText,
                              style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.0, 
                                shadows: [Shadow(blurRadius: 2.0, color: Colors.black, offset: Offset(1.0, 1.0))]
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6), 
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        color: Colors.red,
                        child: Text(locationText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.0)),
                      ),
                      const SizedBox(height: 4), 
                      
                      Container(
                        color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text(reporterName, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14.0)),
                      ),
                      
                      Container(
                        color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: Text(reporterRole, style: const TextStyle(color: Colors.white, fontSize: 12.0)),
                      ),
                    ],
                  ),
                ),
                
                // కింద స్క్రోలింగ్ న్యూస్ 
                Positioned(
                  bottom: 3, left: 3, right: 3, 
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 35,
                        color: Colors.blue[900],
                        padding: const EdgeInsets.only(left: 10, right: 10), 
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
                        padding: const EdgeInsets.only(left: 10, right: 10), 
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
