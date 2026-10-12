import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class ElectionBoardScreen extends StatefulWidget {
  const ElectionBoardScreen({Key? key}) : super(key: key);

  @override
  State<ElectionBoardScreen> createState() => _ElectionBoardScreenState();
}

class _ElectionBoardScreenState extends State<ElectionBoardScreen> {
  // ఎలక్షన్ ట్రెండ్స్ డేటా సిమ్యులేషన్
  int bjpSeats = 150;
  int tmcSeats = 103;
  int congSeats = 5;
  int leftSeats = 2;
  int othSeats = 2;

  // కెమెరా మరియు లైవ్ వేరియబుల్స్
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false;
  bool _showControls = false;

  // నేటివ్ ఆండ్రాయిడ్ కమ్యూనికేషన్ ఛానల్
  static const MethodChannel _channel = MethodChannel('com.kingjvk.pocket_pcr/stream');

  @override
  void initState() {
    super.initState();
    _initReporterCamera();
  }

  // ఫ్రంట్ కెమెరాను (రిపోర్టర్ కోసం) ఆన్ చేసే ఫంక్షన్
  Future<void> _initReporterCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        CameraDescription? frontCam;
        for (var cam in _cameras) {
          if (cam.lensDirection == CameraLensDirection.front) {
            frontCam = cam;
            break;
          }
        }
        _cameraController = CameraController(
          frontCam ?? _cameras.first, 
          ResolutionPreset.high, 
          enableAudio: true // రిపోర్టర్ వాయిస్ కోసం
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint("Camera Init Error: $e");
    }
  }

  // లైవ్ ప్రారంభించే / ఆపే ఫంక్షన్
  Future<void> _toggleElectionLive() async {
    if (_isRecording) {
      try {
        await _channel.invokeMethod('stopScreenCaptureStreaming');
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ఎలక్షన్ లైవ్ ఆగిపోయింది."), backgroundColor: Colors.blue)
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Stop Error: $e"), backgroundColor: Colors.red)
        );
      }
    } else {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ఎలక్షన్ లైవ్ ప్రారంభమవుతోంది..."), backgroundColor: Colors.orange)
        );
        
        // మెయిన్ స్క్రీన్ లో సేవ్ చేసిన లింక్స్ ఆటోమేటిక్ గా తీసుకుంటుంది
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String rtmp = prefs.getString('cableRtmp') ?? "";
        String rtmps = prefs.getString('cableRtmps') ?? "";
        String srt = prefs.getString('satelliteSrt') ?? "";
        bool noiseCancel = prefs.getBool('enableNoiseCancellation') ?? false;

        await _channel.invokeMethod('startScreenCaptureStreaming', {
          'cableRtmp': rtmp,
          'cableRtmps': rtmps,
          'satelliteSrt': srt,
          'noiseCancellation': noiseCancel
        });
        setState(() => _isRecording = true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Live Error: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // స్క్రీన్ పై డబుల్ ట్యాప్ చేస్తే "GO LIVE" బటన్ కనిపిస్తుంది/మాయమవుతుంది
        onDoubleTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // 1. TOP HEADER - WEST BENGAL & LEADING PARTIES BAR
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: Colors.black,
                    child: Row(
                      children: [
                        // State Box
                        Container(
                          padding: const EdgeInsets.all(6),
                          color: Colors.red.shade900,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("WEST BENGAL", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text("262/294", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Parties Trends
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildPartyHeaderItem("BJP+", "▲ +78", "$bjpSeats", Colors.orange.shade800),
                              _buildPartyHeaderItem("TMC+", "▼ -87", "$tmcSeats", Colors.green.shade800),
                              _buildPartyHeaderItem("CONG", "▲ +5", "$congSeats", Colors.blue.shade800),
                              _buildPartyHeaderItem("LEFT+", "▲ +2", "$leftSeats", Colors.red.shade800),
                              _buildPartyHeaderItem("OTH", "▲ +2", "$othSeats", Colors.grey.shade700),
                            ],
                          ),
                        ),
                        // Live Logo Widget
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Column(
                            children: [
                              Text("SS YATRA", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              Row(
                                children: [
                                  Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                                  SizedBox(width: 3),
                                  Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  // 2. CENTER SECTION (Left: Puducherry, Center: Breaking News / Anchor, Right: Assam)
                  Expanded(
                    child: Row(
                      children: [
                        // LEFT SIDE PANEL (Puducherry Results)
                        Container(
                          width: 170,
                          color: Colors.grey.shade900,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("PUDUCHERRY", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              const Text("17/30", style: TextStyle(color: Colors.amber, fontSize: 11)),
                              const Divider(color: Colors.white24),
                              _buildStateResultRow("NRC+", "▲ +1", "11", Colors.red.shade800),
                              _buildStateResultRow("TVK+", "▲ +4", "4", Colors.red.shade800),
                              _buildStateResultRow("CONG+", "▼ -2", "2", Colors.red.shade800),
                              _buildStateResultRow("OTH", "▼ -3", "0", Colors.red.shade800),
                            ],
                          ),
                        ),

                        // CENTER MAIN SCREEN (Anchor Box & Big Breaking Box)
                        Expanded(
                          child: Container(
                            color: Colors.black,
                            child: Stack(
                              children: [
                                // యాంకర్/రిపోర్టర్ లైవ్ కెమెరా బాక్స్
                                Positioned(
                                  left: 10,
                                  top: 10,
                                  bottom: 10,
                                  width: 140,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.amber, width: 2),
                                      color: Colors.grey[850],
                                    ),
                                    child: _cameraController != null && _cameraController!.value.isInitialized
                                        ? ClipRect(
                                            child: FittedBox(
                                              fit: BoxFit.cover,
                                              child: SizedBox(
                                                width: _cameraController!.value.previewSize!.height,
                                                height: _cameraController!.value.previewSize!.width,
                                                child: CameraPreview(_cameraController!),
                                              ),
                                            ),
                                          )
                                        : const Center(child: CircularProgressIndicator(color: Colors.amber)),
                                  ),
                                ),

                                // Center Big Breaking News Banner
                                Positioned(
                                  left: 160,
                                  right: 10,
                                  top: 20,
                                  bottom: 20,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade800,
                                      border: Border.all(color: Colors.amber, width: 3),
                                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text("BREAKING NEWS", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                                        SizedBox(height: 15),
                                        Text(
                                          "EARLY TRENDS: MAMATA TRAILING FROM BHABANIPUR",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // RIGHT SIDE PANEL (Assam Results)
                        Container(
                          width: 170,
                          color: Colors.grey.shade900,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("ASSAM", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              const Text("96/126", style: TextStyle(color: Colors.amber, fontSize: 11)),
                              const Divider(color: Colors.white24),
                              _buildStateResultRow("BJP+", "▲ +18", "71", Colors.red.shade800),
                              _buildStateResultRow("CONG", "▼ -2", "23", Colors.red.shade800),
                              _buildStateResultRow("AIUDF+", "▼ -11", "1", Colors.red.shade800),
                              _buildStateResultRow("OTH", "▼ -5", "1", Colors.red.shade800),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. BOTTOM SECTION - TAMIL NADU RESULTS BAR
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: Colors.black,
                    child: Row(
                      children: [
                        Container(
                          width: 130,
                          padding: const EdgeInsets.all(4),
                          color: Colors.red.shade900,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("TAMIL NADU", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text("142/234", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildBottomPartyItem("DMK+", "▼ -38", "63", Colors.amber),
                              _buildBottomPartyItem("TVK", "▲ +41", "41", Colors.brown.shade700),
                              _buildBottomPartyItem("ADMK+", "▼ -4", "37", Colors.teal.shade800),
                              _buildBottomPartyItem("OTH", "▲ +1", "1", Colors.grey.shade700),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. FOOTER TICKER (Social Media & Brand)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: Colors.red.shade900,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("#ResultsWithSSYatra  |  ELECTION RESULTS LIVE", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text("@SSYatraTV  |  f Facebook", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              
              // LIVE బటన్ (డబుల్ ట్యాప్ చేసినప్పుడు కనిపిస్తుంది)
              if (_showControls)
                Positioned(
                  top: 60,
                  right: 180,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.orange : Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _showControls = false; // బటన్ నొక్కగానే మాయం అవ్వడానికి
                      });
                      _toggleElectionLive();
                    },
                    icon: Icon(_isRecording ? Icons.stop : Icons.sensors, color: Colors.white),
                    label: Text(
                      _isRecording ? "STOP ELECTION LIVE" : "GO LIVE (ELECTION)",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
              // వెనక్కి వెళ్లే బటన్
              if (_showControls)
                Positioned(
                  top: 60,
                  left: 20,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.blueGrey,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartyHeaderItem(String party, String change, String seats, Color bgColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: bgColor,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(party, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(width: 2),
                Text(change, style: const TextStyle(color: Colors.white70, fontSize: 8)),
              ],
            ),
            Text(seats, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildStateResultRow(String party, String change, String seats, Color bgColor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(party, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(change, style: const TextStyle(color: Colors.white70, fontSize: 9)),
            ],
          ),
          Text(seats, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildBottomPartyItem(String party, String change, String seats, Color bgColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: bgColor,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(party, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(width: 2),
                Text(change, style: const TextStyle(color: Colors.white70, fontSize: 9)),
              ],
            ),
            Text(seats, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
