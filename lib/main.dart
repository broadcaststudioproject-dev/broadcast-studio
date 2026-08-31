import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // ఇక్కడ ఎడిట్ చేసుకోవడానికి వీలుగా వేరియబుల్స్ సెట్ చేశాం
  String locationText = "LIVE KOTHAKOTA";
  String channelName = "SS\nYATRA\nTV";
  String reporterName = "VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String breakingNews = "కొత్తకోటలో భారీ ర్యాలీ.. ప్రజలతో మంత్రి సమావేశం";

  @override
  void initState() {
    super.initState();
    _initCamera();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  void _initCamera() {
    if (cameras.isEmpty) return;
    controller = CameraController(cameras[0], ResolutionPreset.high);
    controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  // ఎడిట్ బటన్ నొక్కినప్పుడు ఓపెన్ అయ్యే పాప్-అప్ బాక్స్
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
                TextField(controller: chCtrl, decoration: const InputDecoration(labelText: "Channel Name (ఛానెల్ పేరు)"), maxLines: 3),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Reporter Name (రిపోర్టర్ పేరు)")),
                TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: "Designation (హోదా)")),
                TextField(controller: newsCtrl, decoration: const InputDecoration(labelText: "Breaking News (బ్రేకింగ్ న్యూస్)"), maxLines: 2),
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
          setState(() {
            hideControls = !hideControls;
          });
        },
        child: Stack(
          children: [
            SizedBox.expand(child: CameraPreview(controller!)),
            
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
                      color: Colors.red, padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          const Text("BREAKING NEWS: ", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 18)),
                          Expanded(child: Text(breakingNews, style: const TextStyle(color: Colors.white, fontSize: 18), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  ),
                  
                  // ఎడిట్ మరియు క్లీన్ వ్యూ బటన్స్
                  if (!hideControls)
                    Positioned(
                      bottom: 150, left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _showEditDialog,
                            icon: const Icon(Icons.edit, color: Colors.white),
                            label: const Text("EDIT GRAPHICS"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                hideControls = true;
                              });
                            },
                            icon: const Icon(Icons.fullscreen, color: Colors.white),
                            label: const Text("CLEAN VIEW"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
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
    );
  }
}
