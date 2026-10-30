import 'package:flutter/material.dart';  
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class EditorToolScreen extends StatefulWidget {
  const EditorToolScreen({Key? key}) : super(key: key);

  @override
  State<EditorToolScreen> createState() => _EditorToolScreenState();
}

class _EditorToolScreenState extends State<EditorToolScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ===================== PRO PCR TOOLS (లైవ్ టూల్స్) =====================
  double bgmVolume = 0.5;
  double reporterVolume = 0.8;
  double guestVolume = 0.6;
  
  bool isChromaKeyEnabled = false;
  bool isLiveCallerEnabled = false;
  bool isLowerThirdsAnimated = false;
  bool isSimultaneousRecording = false;

  // టెలీప్రాంప్టర్ రియల్-టైమ్ లాజిక్
  final ScrollController _prompterController = ScrollController();
  bool isPrompterPlaying = false;
  double prompterSpeed = 30.0; 
  Timer? _prompterTimer;
  final TextEditingController _prompterTextCtrl = TextEditingController(
      text: "నమస్కారం, SS YATRA TV కి స్వాగతం.\n\nఈనాటి ముఖ్య వార్తలు...\n\nబంగాళాఖాతంలో ఏర్పడిన వాయుగుండం తీవ్ర తుఫానుగా మారింది. విశాఖకు 610 కిలోమీటర్ల దూరంలో కేంద్రీకృతమైంది. తెలంగాణపై తుఫాన్ ప్రభావం పెద్దగా లేదని వాతావరణ శాఖ తెలిపింది.\n\nమరిన్ని వివరాలకు చూస్తూనే ఉండండి SS YATRA TV.");

  // ===================== MEDIA EDITOR (ఎడిటింగ్ టూల్స్) =====================
  final ImagePicker _picker = ImagePicker();
  VideoPlayerController? _editorVideoCtrl;
  bool isEditorVideoPlaying = false;

  final List<String> proFeatures = [
    "Video transition", "Merge videos", "Speed Ramping (Curve)", 
    "Change video background ratio", "Edit Music", "Adjust audio volume", 
    "Extract audio from video", "PIP Chroma", "Photo Cutout", "Keyframe"
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _prompterTimer?.cancel();
    _prompterController.dispose();
    _prompterTextCtrl.dispose();
    _editorVideoCtrl?.dispose();
    super.dispose();
  }

  // 🔴 టెలీప్రాంప్టర్ ఆటో-స్క్రోల్ ఫంక్షన్
  void _togglePrompter() {
    setState(() {
      isPrompterPlaying = !isPrompterPlaying;
    });
    if (isPrompterPlaying) {
      _prompterTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (_prompterController.hasClients) {
          double maxScroll = _prompterController.position.maxScrollExtent;
          double currentScroll = _prompterController.offset;
          if (currentScroll < maxScroll) {
            _prompterController.jumpTo(currentScroll + (prompterSpeed / 10));
          } else {
            _prompterTimer?.cancel();
            setState(() => isPrompterPlaying = false);
          }
        }
      });
    } else {
      _prompterTimer?.cancel();
    }
  }

  // 🔴 ఎడిటర్ కోసం గ్యాలరీ నుండి వీడియో తీసుకునే ఫంక్షన్
  Future<void> _pickVideoForEditor() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        _editorVideoCtrl?.dispose();
        _editorVideoCtrl = VideoPlayerController.file(File(video.path))
          ..initialize().then((_) {
            if (!mounted) return; // 🔴 ఈ సేఫ్టీ చెక్ యాడ్ చేశాను
            setState(() {});
            _editorVideoCtrl!.play();
            isEditorVideoPlaying = true;
          });
      }
    } catch (e) {
      debugPrint("Video Pick Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Master Editor & PCR Tools", style: TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.live_tv), text: "PRO PCR TOOLS"),
            Tab(icon: Icon(Icons.video_settings), text: "MEDIA EDITOR"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProPcrToolsTab(),
          _buildMediaEditorTab(),
        ],
      ),
    );
  }

  // =====================================================================
  // TAB 1: PRO PCR TOOLS (Live Broadcasting Tools)
  // =====================================================================
  Widget _buildProPcrToolsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. టెలీప్రాంప్టర్ 
          _buildSectionTitle("1. Teleprompter (టెలీప్రాంప్టర్)"),
          Container(
            height: 180,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.amber, width: 2), borderRadius: BorderRadius.circular(8)),
            child: TextField(
              controller: _prompterTextCtrl,
              scrollController: _prompterController,
              maxLines: null,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.5),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text("Speed: ", style: TextStyle(color: Colors.white70)),
                  Slider(value: prompterSpeed, min: 10, max: 100, activeColor: Colors.amber, onChanged: (v) => setState(() => prompterSpeed = v)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: isPrompterPlaying ? Colors.red : Colors.green),
                onPressed: _togglePrompter,
                icon: Icon(isPrompterPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                label: Text(isPrompterPlaying ? "PAUSE" : "START", style: const TextStyle(color: Colors.white)),
              )
            ],
          ),
          const Divider(color: Colors.white24, height: 30),

          // 2. ఆడియో మిక్సర్ 
          _buildSectionTitle("2. Advanced Audio Mixer"),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                _buildAudioSlider("Reporter Mic", reporterVolume, (v) => setState(() => reporterVolume = v), Colors.blueAccent),
                _buildAudioSlider("Live Caller / Guest", guestVolume, (v) => setState(() => guestVolume = v), Colors.greenAccent),
                _buildAudioSlider("BGM (Music)", bgmVolume, (v) => setState(() => bgmVolume = v), Colors.purpleAccent),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 30),

          // 3. లైవ్ ఫీచర్స్ 
          _buildSectionTitle("3. Live Broadcasting Features"),
          SwitchListTile(
            title: const Text("Virtual Studio (Green Screen)", style: TextStyle(color: Colors.white)),
            subtitle: const Text("రిపోర్టర్ వెనుక బ్యాక్‌గ్రౌండ్ రిమూవ్ చేస్తుంది", style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: isChromaKeyEnabled, activeColor: Colors.tealAccent, onChanged: (v) => setState(() => isChromaKeyEnabled = v),
          ),
          SwitchListTile(
            title: const Text("Live Caller Integration", style: TextStyle(color: Colors.white)),
            subtitle: const Text("ప్రేక్షకుల కాల్స్ లైవ్ లోకి తీసుకుంటుంది", style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: isLiveCallerEnabled, activeColor: Colors.tealAccent, onChanged: (v) => setState(() => isLiveCallerEnabled = v),
          ),
          SwitchListTile(
            title: const Text("Animated Lower Thirds", style: TextStyle(color: Colors.white)),
            subtitle: const Text("పేర్లు, స్క్రోలింగ్ యానిమేషన్ తో వస్తాయి", style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: isLowerThirdsAnimated, activeColor: Colors.tealAccent, onChanged: (v) => setState(() => isLowerThirdsAnimated = v),
          ),
          SwitchListTile(
            title: const Text("Simultaneous Recording (Backup)", style: TextStyle(color: Colors.white)),
            subtitle: const Text("లైవ్ వెళ్తూనే గ్యాలరీలో క్వాలిటీ MP4 సేవ్ అవుతుంది", style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: isSimultaneousRecording, activeColor: Colors.redAccent, onChanged: (v) => setState(() => isSimultaneousRecording = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(title, style: const TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.bold)));
  }

  Widget _buildAudioSlider(String label, double value, Function(double) onChanged, Color color) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(child: Slider(value: value, min: 0.0, max: 1.0, activeColor: color, onChanged: onChanged)),
        Text("${(value * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // =====================================================================
  // TAB 2: MEDIA EDITOR (Post Production Tools)
  // =====================================================================
  Widget _buildMediaEditorTab() {
    return Column(
      children: [
        // 1. వీడియో ప్రివ్యూ ఏరియా (రియల్ వీడియో ప్లేయర్)
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.grey.shade800, width: 2), borderRadius: BorderRadius.circular(10)),
            child: _editorVideoCtrl != null && _editorVideoCtrl!.value.isInitialized
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(aspectRatio: _editorVideoCtrl!.value.aspectRatio, child: VideoPlayer(_editorVideoCtrl!)),
                      IconButton(
                        icon: Icon(isEditorVideoPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white54, size: 50),
                        onPressed: () {
                          setState(() {
                            isEditorVideoPlaying ? _editorVideoCtrl!.pause() : _editorVideoCtrl!.play();
                            isEditorVideoPlaying = !isEditorVideoPlaying;
                          });
                        },
                      )
                    ],
                  )
                : Center(
                    child: ElevatedButton.icon(
                      onPressed: _pickVideoForEditor,
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text("గ్యాలరీ నుండి వీడియో ఎంచుకోండి"),
                    ),
                  ),
          ),
        ),

        // 2. టైమ్‌లైన్ ఏరియా
        Expanded(
          flex: 2,
          child: Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Timeline (కట్ & స్ప్లిట్)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    if (_editorVideoCtrl != null) 
                      TextButton(onPressed: _pickVideoForEditor, child: const Text("Change Video", style: TextStyle(color: Colors.tealAccent, fontSize: 11)))
                  ],
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(8)),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 10,
                      itemBuilder: (context, index) => Container(
                        width: 50,
                        margin: const EdgeInsets.all(2),
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.movie, color: Colors.white24, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. ఎడిటింగ్ టూల్స్ (Bottom Toolbars)
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildToolIcon(Icons.aspect_ratio, "CANVAS"),
                    _buildToolIcon(Icons.filter_b_and_w, "FILTER"),
                    _buildToolIcon(Icons.tune, "ADJUST"),
                    _buildToolIcon(Icons.star_border, "EFFECT"),
                    _buildToolIcon(Icons.texture, "BACKGROUND"),
                    _buildToolIcon(Icons.emoji_emotions_outlined, "STICKER"),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildToolIcon(Icons.title, "TEXT"),
                    _buildToolIcon(Icons.gesture, "DOODLE"),
                    _buildToolIcon(Icons.person_remove, "CUTOUT"),
                    _buildToolIcon(Icons.picture_in_picture_alt, "PIP"),
                    _buildToolIcon(Icons.crop, "CROP"),
                    _buildToolIcon(Icons.rotate_right, "ROTATE"),
                    _buildToolIcon(Icons.flash_on, "PRO", isPro: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolIcon(IconData icon, String label, {bool isPro = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      child: GestureDetector(
        onTap: () {
          if (isPro) {
            _showProFeaturesBottomSheet(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$label Tool Selected"), duration: const Duration(milliseconds: 800)));
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isPro ? Colors.amber : Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: isPro ? Colors.amber : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showProFeaturesBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          children: [
            const Padding(padding: EdgeInsets.all(15.0), child: Text("PRO FEATURES", style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold))),
            Expanded(
              child: ListView.builder(
                itemCount: proFeatures.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.workspace_premium, color: Colors.amber),
                    title: Text(proFeatures[index], style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => Navigator.pop(context),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
