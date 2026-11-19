import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class WatermarkController extends ChangeNotifier {
  bool show = false;
  String? filePath;
  bool isVideo = false;
  double opacity = 0.5;
  double topPos = 0.12; // 0.12 = Top, 0.42 = Center, 0.72 = Bottom
  int speedSec = 12;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString('wm_path');
      show = prefs.getBool('wm_show') ?? false;
      filePath =
          (savedPath != null && File(savedPath).existsSync()) ? savedPath : null;
      isVideo = prefs.getBool('wm_is_video') ?? false;
      opacity = prefs.getDouble('wm_opacity') ?? 0.5;
      topPos = prefs.getDouble('wm_top_pos') ?? 0.12;
      speedSec = prefs.getInt('wm_speed') ?? 12;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('wm_show', show);
      if (filePath != null) {
        await prefs.setString('wm_path', filePath!);
      }
      await prefs.setBool('wm_is_video', isVideo);
      await prefs.setDouble('wm_opacity', opacity);
      await prefs.setDouble('wm_top_pos', topPos);
      await prefs.setInt('wm_speed', speedSec);
    } catch (_) {}
  }

  void update({
    bool? show,
    String? filePath,
    bool? isVideo,
    double? opacity,
    double? topPos,
    int? speedSec,
  }) {
    if (show != null) this.show = show;
    if (filePath != null) this.filePath = filePath;
    if (isVideo != null) this.isVideo = isVideo;
    if (opacity != null) this.opacity = opacity;
    if (topPos != null) this.topPos = topPos;
    if (speedSec != null) this.speedSec = speedSec;
    notifyListeners();
    save();
  }
}

void showWatermarkDialog(BuildContext context, WatermarkController wm) {
  final picker = ImagePicker();
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'ఛానెల్ వాటర్ మార్క్ (JPEG / GIF / MP4)',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text(
                    'వాటర్ మార్క్ ఆన్ / ఆఫ్',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: wm.show,
                  activeColor: Colors.amber,
                  onChanged: (val) {
                    wm.update(show: val);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.image, size: 18),
                        label: const Text('JPEG / GIF'),
                        onPressed: () async {
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (picked != null) {
                            wm.update(
                              filePath: picked.path,
                              isVideo: false,
                              show: true,
                            );
                            setDialogState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.movie, size: 18),
                        label: const Text('MP4 వీడియో'),
                        onPressed: () async {
                          final picked = await picker.pickVideo(
                            source: ImageSource.gallery,
                          );
                          if (picked != null) {
                            wm.update(
                              filePath: picked.path,
                              isVideo: true,
                              show: true,
                            );
                            setDialogState(() {});
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'పారదర్శకత (Opacity): ${(wm.opacity * 100).round()}%',
                  style: const TextStyle(color: Colors.white70),
                ),
                Slider(
                  value: wm.opacity,
                  min: 0.1,
                  max: 1.0,
                  activeColor: Colors.amber,
                  onChanged: (v) {
                    wm.update(opacity: v);
                    setDialogState(() {});
                  },
                ),
                Text(
                  'స్క్రోల్ స్పీడ్: ${wm.speedSec} సెకన్లు',
                  style: const TextStyle(color: Colors.white70),
                ),
                Slider(
                  value: wm.speedSec.toDouble(),
                  min: 5,
                  max: 30,
                  divisions: 25,
                  activeColor: Colors.amber,
                  onChanged: (v) {
                    wm.update(speedSec: v.round());
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ChoiceChip(
                      label: const Text('Top'),
                      selected: wm.topPos == 0.12,
                      onSelected: (_) {
                        wm.update(topPos: 0.12);
                        setDialogState(() {});
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Center'),
                      selected: wm.topPos == 0.42,
                      onSelected: (_) {
                        wm.update(topPos: 0.42);
                        setDialogState(() {});
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Bottom'),
                      selected: wm.topPos == 0.72,
                      onSelected: (_) {
                        wm.update(topPos: 0.72);
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('మూసివేయి', style: TextStyle(color: Colors.amber)),
            ),
          ],
        );
      },
    ),
  );
}

class ScrollingWatermarkOverlay extends StatelessWidget {
  final WatermarkController controller;

  const ScrollingWatermarkOverlay({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.show || controller.filePath == null) {
          return const SizedBox.shrink();
        }
        return _ScrollingWatermarkPlayer(
          filePath: controller.filePath!,
          isVideo: controller.isVideo,
          opacity: controller.opacity,
          topFraction: controller.topPos,
          durationSeconds: controller.speedSec,
        );
      },
    );
  }
}

class _ScrollingWatermarkPlayer extends StatefulWidget {
  final String filePath;
  final bool isVideo;
  final double opacity;
  final double topFraction;
  final int durationSeconds;

  const _ScrollingWatermarkPlayer({
    Key? key,
    required this.filePath,
    required this.isVideo,
    required this.opacity,
    required this.topFraction,
    required this.durationSeconds,
  }) : super(key: key);

  @override
  State<_ScrollingWatermarkPlayer> createState() =>
      _ScrollingWatermarkPlayerState();
}

class _ScrollingWatermarkPlayerState extends State<_ScrollingWatermarkPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    )..repeat();

    if (widget.isVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      final ctrl = VideoPlayerController.file(File(widget.filePath));
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0.0);
      await ctrl.play();
      if (mounted) {
        setState(() {
          _videoCtrl = ctrl;
          _videoReady = true;
        });
      } else {
        ctrl.dispose();
      }
    } catch (e) {
      debugPrint('Watermark video error: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _ScrollingWatermarkPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.durationSeconds != widget.durationSeconds) {
      _animController.duration = Duration(seconds: widget.durationSeconds);
      _animController.repeat();
    }
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.isVideo != widget.isVideo) {
      _videoCtrl?.dispose();
      _videoCtrl = null;
      _videoReady = false;
      if (widget.isVideo) {
        _initVideo();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const double boxHeight = 90.0;

    Widget mediaChild;
    if (widget.isVideo) {
      if (_videoReady && _videoCtrl != null) {
        mediaChild = AspectRatio(
          aspectRatio: _videoCtrl!.value.aspectRatio,
          child: VideoPlayer(_videoCtrl!),
        );
      } else {
        return const SizedBox.shrink();
      }
    } else {
      final file = File(widget.filePath);
      if (!file.existsSync()) return const SizedBox.shrink();
      mediaChild = Image.file(
        file,
        height: boxHeight,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }

    return IgnorePointer(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final double startX = screenSize.width + 20;
            const double endX = -320;
            final double currentX =
                startX + (endX - startX) * _animController.value;

            return Align(
              alignment: Alignment.topLeft,
              child: Transform.translate(
                offset:
                    Offset(currentX, screenSize.height * widget.topFraction),
                child: Opacity(
                  opacity: widget.opacity.clamp(0.1, 1.0),
                  child: SizedBox(
                    height: boxHeight,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: mediaChild,
        ),
      ),
    );
  }
}
