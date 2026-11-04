// Copyright (c) 2026 Vinod Kumar Jannampally. All commercial and software rights reserved.
// Package: com.kingjvk.pocket_pcr

import 'package:flutter/material.dart';
import '../../models/news_item.dart';
import '../../database/news_database_helper.dart';
import 'virtual_anchor_service.dart';
import 'package:video_player/video_player.dart';

class VirtualAnchorScreen extends StatefulWidget {
  final NewsItem newsItem;

  const VirtualAnchorScreen({Key? key, required this.newsItem}) : super(key: key);

  @override
  _VirtualAnchorScreenState createState() => _VirtualAnchorScreenState();
}

class _VirtualAnchorScreenState extends State<VirtualAnchorScreen> {
  final NewsDatabaseHelper _dbHelper = NewsDatabaseHelper();
  String _selectedGender = 'Female';
  bool _isGenerating = false;
  String? _generatedVideoUrl;
  VideoPlayerController? _videoController;

  Future<void> _generateVideo() async {
    setState(() => _isGenerating = true);

    String? videoUrl = await VirtualAnchorService.generateAnchorVideo(
      widget.newsItem.content, 
      _selectedGender
    );

    setState(() {
      _isGenerating = false;
      _generatedVideoUrl = videoUrl;
    });

    if (videoUrl != null) {
      _videoController = VideoPlayerController.network(videoUrl)
        ..initialize().then((_) {
          setState(() {});
          _videoController!.play();
        });

      // డేటాబేస్‌లో వీడియో లింక్‌ను సేవ్ చేసి, స్టేటస్ మార్చడం
      widget.newsItem.mediaUrl = videoUrl;
      widget.newsItem.status = 'Ready for Broadcast';
      await _dbHelper.insertNewsItem(widget.newsItem);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('యాంకర్ వీడియో విజయవంతంగా తయారైంది!'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('వీడియో జనరేట్ కాలేదు. API కీని చెక్ చేయండి.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Virtual Anchor Creator'),
        backgroundColor: Colors.indigo[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.newsItem.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const Divider(),
            
            const Text("AI యాంకర్ మోడల్ (లింగం):", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Radio<String>(
                  value: 'Female',
                  groupValue: _selectedGender,
                  onChanged: (val) => setState(() => _selectedGender = val!),
                ),
                const Text('ఫీమేల్ యాంకర్ (Shruti)'),
                const SizedBox(width: 20),
                Radio<String>(
                  value: 'Male',
                  groupValue: _selectedGender,
                  onChanged: (val) => setState(() => _selectedGender = val!),
                ),
                const Text('మేల్ యాంకర్ (Mohan)'),
              ],
            ),
            const SizedBox(height: 10),

            Center(
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateVideo,
                icon: _isGenerating 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Icon(Icons.video_camera_front, color: Colors.white),
                label: const Text("యాంకర్ వీడియో జనరేట్ చేయి", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
              ),
            ),
            const SizedBox(height: 20),

            if (_isGenerating)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text("AI మీ వీడియోను తయారు చేస్తోంది... దయచేసి వేచి ఉండండి.", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

            if (_generatedVideoUrl != null && _videoController != null && _videoController!.value.isInitialized)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.indigo, width: 2)),
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
