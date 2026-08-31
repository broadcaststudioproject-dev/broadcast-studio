import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
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
  bool isRecording = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone, Permission.storage].request();
  }

  void _initCamera() {
    controller = CameraController(cameras[0], ResolutionPreset.high);
    controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _startRecording() async {
    setState(() => isRecording = true);
    bool started = await FlutterScreenRecording.startRecordScreenAndAudio("SS_YATRA_LIVE");
  }

  Future<void> _stopRecording() async {
    String path = await FlutterScreenRecording.stopRecordScreen;
    setState(() => isRecording = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('వీడియో సేవ్ అయింది: \$path')));
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SizedBox.expand(child: CameraPreview(controller!)),
          Positioned(
            top: 40, left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: Colors.red,
              child: const Text("LIVE KOTHAKOTA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          Positioned(
            top: 40, right: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.blue[900],
              child: const Text("SS\nYATRA\nTV", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          ),
          Positioned(
            bottom: 120, left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  child: const Text("VINOD KUMAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
                ),
                Container(
                  color: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
                  child: const Text("SPECIAL CORRESPONDENT", style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Container(
              color: Colors.red, padding: const EdgeInsets.all(10),
              child: const Row(
                children: [
                  Text("BREAKING NEWS: ", style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 18)),
                  Expanded(child: Text("కొత్తకోటలో భారీ ర్యాలీ.. ప్రజలతో మంత్రి సమావేశం", style: TextStyle(color: Colors.white, fontSize: 18), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
          if (!isRecording)
            Positioned(
              bottom: 10, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _startRecording,
                    icon: const Icon(Icons.circle, color: Colors.red),
                    label: const Text("REC"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
                  ),
                ],
              ),
            ),
          if (isRecording)
            Positioned(
              bottom: 10, left: 0, right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _stopRecording,
                  icon: const Icon(Icons.stop, color: Colors.white),
                  label: const Text("STOP RECORDING"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
