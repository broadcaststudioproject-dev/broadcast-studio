import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io'; 
import 'package:image_picker/image_picker.dart';

class PCRCustomPlayer extends StatefulWidget {
  const PCRCustomPlayer({Key? key}) : super(key: key);

  @override
  State<PCRCustomPlayer> createState() => _PCRCustomPlayerState();
}

class _PCRCustomPlayerState extends State<PCRCustomPlayer> {
  VideoPlayerController? _previewController;
  VideoPlayerController? _programController;
  
  bool _isPreviewPlaying = false;
  bool _isMuted = false;
  bool _isLooping = false;
  
  Duration _currentPreviewPos = Duration.zero;
  String _currentVideoPath = "";

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _previewController?.removeListener(_previewListener);
    _previewController?.dispose();
    _programController?.dispose();
    super.dispose();
  }

  void _previewListener() {
    if (_previewController != null && _previewController!.value.isInitialized) {
      setState(() {
        _currentPreviewPos = _previewController!.value.position;
        _isPreviewPlaying = _previewController!.value.isPlaying;
      });
    }
  }

  // గ్యాలరీ నుండి వీడియో లోడ్ చేయడానికి (ప్రివ్యూ లోకి)
  Future<void> _loadPreviewVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        _currentVideoPath = video.path;
        if (_previewController != null) {
          _previewController!.removeListener(_previewListener);
          await _previewController!.dispose();
        }
        
        _previewController = VideoPlayerController.file(File(_currentVideoPath))
          ..initialize().then((_) {
            setState(() {
              _previewController!.setVolume(_isMuted ? 0.0 : 1.0);
              _previewController!.setLooping(_isLooping);
            });
            _previewController!.addListener(_previewListener);
          });
      }
    } catch (e) {
      debugPrint("Video Load Error: $e");
    }
  }

  // PREVIEW నుండి PROGRAM (LIVE) కి పంపే అద్భుతమైన TAKE బటన్ లాజిక్
  Future<void> _sendToLiveProgram() async {
    if (_previewController == null || !_previewController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ముందుగా ప్రివ్యూలో వీడియో లోడ్ చేయండి!'), backgroundColor: Colors.red),
      );
      return;
    }

    // పాత ప్రోగ్రామ్ వీడియో ఆపేస్తున్నాం
    if (_programController != null) {
      await _programController!.dispose();
    }

    // ప్రివ్యూ వీడియోనే ప్రోగ్రామ్‌కి లోడ్ చేస్తున్నాం
    _programController = VideoPlayerController.file(File(_currentVideoPath))
      ..initialize().then((_) async {
        // ప్రివ్యూ ఏ సెకనులో ఉందో, కరెక్ట్‌గా ఆ సెకనుకే లైవ్ వీడియో వెళ్తుంది!
        await _programController!.seekTo(_currentPreviewPos);
        await _programController!.play();
        setState(() {});
      });
  }

  // కస్టమ్ టైమ్‌కోడ్ ఫార్మాట్ (00:00:00:00 - Hours:Minutes:Seconds:Frames)
  String _formatTimecode(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    // 30 fps అనుకుందాం (మిల్లీసెకన్లను ఫ్రేమ్స్‌గా మారుస్తున్నాం)
    int frames = ((duration.inMilliseconds.remainder(1000)) * 30 / 1000).floor();
    String twoDigitFrames = twoDigits(frames);
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds:$twoDigitFrames";
  }

  // ఫ్రేమ్ బై ఫ్రేమ్ సీక్ (స్కిప్)
  void _seekPreview(int milliseconds) {
    if (_previewController != null && _previewController!.value.isInitialized) {
      Duration newPos = _currentPreviewPos + Duration(milliseconds: milliseconds);
      if (newPos < Duration.zero) newPos = Duration.zero;
      if (newPos > _previewController!.value.duration) newPos = _previewController!.value.duration;
      _previewController!.seekTo(newPos);
    }
  }

  // NO SIGNAL ప్లేస్ హోల్డర్
  Widget _buildNoSignal(String title) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white24, size: 50),
            const SizedBox(height: 10),
            Text(
              "NO SIGNAL\n$title",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2.0),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ఫోన్ అడ్డంగా (Landscape) ఉంటే అద్భుతంగా పని చేస్తుంది
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark Studio Theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF800000), // Maroon accent
        title: const Text("PCR STUDIO MODE (Preview ➔ Live)", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // ==========================================
            // 1. PREVIEW SCREEN (LEFT)
            // ==========================================
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amber, width: 2), // Yellow Accent for Preview
                  color: Colors.black,
                ),
                child: Column(
                  children: [
                    // హెడర్
                    Container(
                      width: double.infinity,
                      color: Colors.amber.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Text("PREVIEW", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    
                    // వీడియో లేదా కాలి (No Signal)
                    Expanded(
                      child: Stack(
                        children: [
                          if (_previewController != null && _previewController!.value.isInitialized)
                            Center(
                              child: AspectRatio(
                                aspectRatio: _previewController!.value.aspectRatio,
                                child: VideoPlayer(_previewController!),
                              ),
                            )
                          else
                            _buildNoSignal("LOAD VIDEO TO PREVIEW"),
                            
                          // టైమ్‌కోడ్ డిస్‌ప్లే
                          Positioned(
                            top: 10, left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              color: Colors.black87,
                              child: Text(
                                _formatTimecode(_currentPreviewPos),
                                style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),

                    // ప్రివ్యూ కంట్రోల్స్ (ప్లే, సీక్, లూప్)
                    Container(
                      color: Colors.grey.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.upload_file, color: Colors.blueAccent),
                            onPressed: _loadPreviewVideo,
                            tooltip: "Load Video",
                          ),
                          IconButton(
                            icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: _isMuted ? Colors.red : Colors.white),
                            onPressed: () {
                              setState(() {
                                _isMuted = !_isMuted;
                                _previewController?.setVolume(_isMuted ? 0.0 : 1.0);
                              });
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous, color: Colors.white70),
                            onPressed: () => _seekPreview(-1000), // -1 second
                          ),
                          CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            child: IconButton(
                              icon: Icon(_isPreviewPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                              onPressed: () {
                                if (_previewController != null) {
                                  _isPreviewPlaying ? _previewController!.pause() : _previewController!.play();
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next, color: Colors.white70),
                            onPressed: () => _seekPreview(1000), // +1 second
                          ),
                          IconButton(
                            icon: Icon(Icons.loop, color: _isLooping ? Colors.greenAccent : Colors.white70),
                            onPressed: () {
                              setState(() {
                                _isLooping = !_isLooping;
                                _previewController?.setLooping(_isLooping);
                              });
                            },
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            // ==========================================
            // 2. TAKE ACTION (CENTER)
            // ==========================================
            Container(
              width: 80,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 20),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _sendToLiveProgram,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade900, Colors.redAccent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(2, 2))],
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: const Center(
                        child: Text("TAKE\nLIVE", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 20),
                ],
              ),
            ),

            // ==========================================
            // 3. PROGRAM SCREEN (RIGHT / LIVE)
            // ==========================================
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent, width: 3), // Red Accent for Live Output
                  color: Colors.black,
                  boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)]
                ),
                child: Column(
                  children: [
                    // హెడర్
                    Container(
                      width: double.infinity,
                      color: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sensors, color: Colors.white, size: 14),
                          SizedBox(width: 5),
                          Text("PROGRAM (LIVE OUTPUT)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    
                    // లైవ్ వీడియో
                    Expanded(
                      child: Stack(
                        children: [
                          if (_programController != null && _programController!.value.isInitialized)
                            Center(
                              child: AspectRatio(
                                aspectRatio: _programController!.value.aspectRatio,
                                child: VideoPlayer(_programController!),
                              ),
                            )
                          else
                            _buildNoSignal("WAITING FOR FEED"),
                            
                          // LIVE బ్రాండింగ్
                          if (_programController != null && _programController!.value.isInitialized)
                            Positioned(
                              top: 15, right: 15,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                child: const Text("LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
