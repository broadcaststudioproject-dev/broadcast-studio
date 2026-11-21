import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'editor_tool.dart';
import 'news_production/ui/news_desk_screen.dart';
import 'election_board.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'watermark_overlay.dart';

List<CameraDescription> cameras = [];

/// గ్యాలరీ / YouTube వీడియో ప్లే చేయగానే ఆటోమేటిక్‌గా లైవ్ మొదలవ్వాలంటే true చేయండి.
const bool kAutoGoLiveOnMedia = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Platform.isWindows) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  try {
    if (!Platform.isWindows) {
      cameras = await availableCameras();
    }
  } catch (e) {
    debugPrint("Camera Error: $e");
  }

  // Windows లో ఏదైనా రన్‌టైమ్ ఎర్రర్ వస్తే kingjvr_error.txt లో సేవ్ అవుతుంది
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (Platform.isWindows) {
      try {
        File('kingjvr_error.txt').writeAsStringSync(
          '${DateTime.now()}\n${details.exception}\n${details.stack}\n\n',
          mode: FileMode.append,
        );
      } catch (_) {}
    }
  };

  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
        color: Colors.red.shade900,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              details.exceptionAsString(),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      );
  runApp(const PocketPCRApp());
}

class PocketPCRApp extends StatelessWidget {
  const PocketPCRApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'KINGJVR',
      debugShowCheckedModeBanner: false,
      home: StudioScreen(),
    );
  }
}

OverlayEntry? _activeToast;

void showCustomToast(BuildContext context, String message,
    {Color bgColor = const Color(0xFF800000), bool isLive = false}) {
  if (!context.mounted) return;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  // ముందు toast ఉంటే తీసేస్తాం (అతివ్యాప్తి రాకుండా)
  try {
    _activeToast?.remove();
  } catch (_) {}
  _activeToast = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: isLive ? 0 : 55.0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: isLive
            ? const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                minHeight: 3.0,
              )
            : Container(
                color: bgColor.withOpacity(0.95),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.0,
                            letterSpacing: 1.0),
                      ),
                    ),
                    const LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                      minHeight: 2.0,
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 2500), () {
    try {
      entry.remove();
    } catch (_) {}
    if (identical(_activeToast, entry)) _activeToast = null;
  });
}

class StreamServiceManager {
  static const MethodChannel _streamChannel =
      MethodChannel('com.kingjvr.pocket_pcr/stream');

  static Process? _winFfmpegProcess;

  // Windows స్క్రీన్ క్యాప్చర్ crop విలువలు (టైటిల్ బార్ / టాస్క్ బార్ కోసం).
  // మీ స్క్రీన్‌కు తగ్గట్టు మార్చుకోండి.
  static const int winCropTop = 32;
  static const int winCropBottom = 40;

  static void initializeStreamListener(BuildContext context) {
    if (Platform.isWindows) return;
    _streamChannel.setMethodCallHandler((call) async {
      if (call.method == 'onStreamStatusUpdate') {
        debugPrint('Stream status: ${call.arguments}');
      }
      return null;
    });
  }

  static String _findWindowsFfmpeg() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final localFfmpeg = '$exeDir\\ffmpeg.exe';
    if (File(localFfmpeg).existsSync()) {
      return localFfmpeg;
    }
    return 'ffmpeg';
  }

  static Future<String?> _detectWindowsAudioDevice(String ffmpegPath) async {
    try {
      final result = await Process.run(
        ffmpegPath,
        ['-list_devices', 'true', '-f', 'dshow', '-i', 'dummy'],
      );
      final output = '${result.stderr}\n${result.stdout}';
      final matches = RegExp(r'"([^"]+)"\s*\(audio\)').allMatches(output);
      final devices = matches.map((m) => m.group(1)!).toList();
      if (devices.isEmpty) return null;

      for (final d in devices) {
        final lower = d.toLowerCase();
        if (lower.contains('stereo mix') ||
            lower.contains('virtual') ||
            lower.contains('cable')) {
          return d;
        }
      }
      return devices.first;
    } catch (e) {
      debugPrint('Audio device detect error: $e');
      return null;
    }
  }

  static String _outFormat(String url) =>
      url.toLowerCase().startsWith('srt://') ? 'mpegts' : 'flv';

  static Future<bool> startLiveStreamMulti(
      String cableUrl, String restreamUrl, String satUrl) async {
    final cable = cableUrl.trim();
    final restream = restreamUrl.trim();
    final satellite = satUrl.trim();

    if (cable.isEmpty && restream.isEmpty && satellite.isEmpty) return false;
    final primaryUrl =
        cable.isNotEmpty ? cable : (restream.isNotEmpty ? restream : satellite);

    if (Platform.isWindows) {
      await stopLiveStream();
      final ffmpegPath = _findWindowsFfmpeg();
      final audioDevice = await _detectWindowsAudioDevice(ffmpegPath);

      // ఇచ్చిన అన్ని లింకులకు ఒకేసారి పంపడానికి (tee muxer)
      final targets = <String>[
        if (cable.isNotEmpty) cable,
        if (restream.isNotEmpty) restream,
        if (satellite.isNotEmpty) satellite,
      ];

      final List<String> outputArgs = targets.length == 1
          ? ['-f', _outFormat(targets.first), targets.first]
          : [
              '-map', '0:v',
              '-map', '1:a',
              '-f', 'tee',
              targets
                  .map((u) => '[f=${_outFormat(u)}:onfail=ignore]$u')
                  .join('|'),
            ];

      final args = <String>[
        '-y',
        '-f', 'gdigrab',
        '-framerate', '25',
        '-draw_mouse', '0',
        '-i', 'desktop',
        if (audioDevice != null) ...[
          '-f', 'dshow',
          '-i', 'audio=$audioDevice',
        ] else ...[
          '-f', 'lavfi',
          '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
        ],
        '-vf',
        'crop=iw:ih-${winCropTop + winCropBottom}:0:$winCropTop,'
            'scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2',
        '-c:v', 'libx264',
        '-preset', 'ultrafast',
        '-tune', 'zerolatency',
        '-pix_fmt', 'yuv420p',
        '-b:v', '4500k',
        '-maxrate', '4500k',
        '-bufsize', '9000k',
        '-g', '50',
        '-c:a', 'aac',
        '-b:a', '128k',
        '-ar', '44100',
        ...outputArgs,
      ];

      try {
        final process = await Process.start(ffmpegPath, args);
        _winFfmpegProcess = process;

        bool exitedEarly = false;
        int? earlyCode;

        process.stdout.drain();
        process.stderr
            .transform(const Utf8Decoder(allowMalformed: true))
            .listen((line) => debugPrint('FFmpeg: $line'));

        process.exitCode.then((code) {
          exitedEarly = true;
          earlyCode = code;
          if (identical(_winFfmpegProcess, process)) {
            _winFfmpegProcess = null;
          }
        });

        await Future.delayed(const Duration(seconds: 2));
        if (exitedEarly) {
          throw Exception(
            'FFmpeg స్ట్రీమ్ ఆగిపోయింది (Code: $earlyCode). RTMP లింక్/ఇంటర్నెట్ చెక్ చేయండి.',
          );
        }
        return true;
      } on ProcessException {
        throw Exception(
          'పీసీలో FFmpeg లేదు. PowerShell లో winget install Gyan.FFmpeg రన్ చేయండి.',
        );
      } catch (e) {
        throw Exception('Windows స్ట్రీమ్ లోపం: $e');
      }
    }

    try {
      final result = await _streamChannel.invokeMethod<bool>(
        'startScreenCaptureStreaming',
        <String, dynamic>{
          'rtmpUrl': primaryUrl,
          'cableRtmp': cable,
          'restreamRtmp': restream,
          'satelliteSrt': satellite,
          'url': primaryUrl,
          'recordAudio': true,
          'captureInternalAudio': true,
          'videoBitrate': 3000 * 1024,
          'audioBitrate': 128 * 1024,
          'fps': 30,
          'resolution': '1080p',
        },
      );
      return result == true;
    } on PlatformException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception("స్ట్రీమ్ ప్రారంభించడంలో లోపం: $e");
    }
  }

  static Future<bool> stopLiveStream() async {
    if (Platform.isWindows) {
      final process = _winFfmpegProcess;
      _winFfmpegProcess = null;
      if (process != null) {
        // ముందు 'q' పంపి సరిగ్గా మూసివేయడానికి ప్రయత్నిస్తాం
        try {
          process.stdin.writeln('q');
          await process.stdin.flush();
        } catch (e) {
          debugPrint('FFmpeg stdin error: $e');
        }
        try {
          await process.exitCode.timeout(const Duration(seconds: 4));
        } on TimeoutException {
          process.kill();
        } catch (_) {
          process.kill();
        }
      }
      return true;
    }
    try {
      final result =
          await _streamChannel.invokeMethod<bool>('stopScreenCaptureStreaming');
      return result == true;
    } catch (e) {
      debugPrint('Stop stream error: $e');
      return false;
    }
  }

  static Future<int?> startUsbCamera() async {
    if (Platform.isWindows) return null;
    try {
      return await const MethodChannel('com.kingjvr.pocket_pcr/uvc')
          .invokeMethod<int>('startUsbCamera');
    } catch (e) {
      debugPrint('USB start error: $e');
      return null;
    }
  }

  static Future<void> stopUsbCamera() async {
    if (Platform.isWindows) return;
    try {
      await const MethodChannel('com.kingjvr.pocket_pcr/uvc')
          .invokeMethod<void>('stopUsbCamera');
    } catch (e) {
      debugPrint('USB stop error: $e');
    }
  }
}

class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen>
    with WidgetsBindingObserver {
  CameraController? controller;

  VlcPlayerController? _vlcBulletinCtrl;
  List<String> localVideoPlaylist = [];
  int currentLocalVideoIndex = 0;
  int _vlcFailCount = 0;

  YoutubePlayerController? _ytController;
  InAppWebViewController? _winYtWebViewCtrl;
  String? _windowsYoutubeVideoId;
  VideoPlayerController? _bulletinVideoController;
  VideoPlayerController? _bottomAdVideoController;
  VideoPlayerController? _leftAdVideoCtrl;
  VideoPlayerController? _rightAdVideoCtrl;
  VideoPlayerController? _bottomAdVideoCtrlForAds;
  VideoPlayerController? _logoVideoCtrl;
  VlcPlayerController? _vlcIpCamController;

  List<String> dualMediaList = [];
  int currentDualMediaIndex = 0;

  bool isLiveLocked = false;
  bool hideControls = false;
  bool isMenuOpen = false;
  bool showReporterDetails = true;

  int currentCameraIndex = 0;
  bool isLandscape = false;
  bool isLiveBroadcasting = false;
  bool isLivePaused = false;

  bool isDualScreenMode = false;
  int adDisplayMode = 0;
  bool isAdCurrentlyShowing = false;
  int adShapeMode = 0; // 0 = L-Band, 1 = U-Band, 2 = Bottom only
  bool isLBandRight = true;
  int logoPosition = 1;

  bool isNewsBulletinMode = false;
  bool isNetworkVideoMode = false;
  bool isYoutubeMode = false;
  bool isBulletinMuted = false;
  bool isCameraVisible = true;
  bool isYoutubeLoading = false;
  bool isNoiseCancellationEnabled = true;
  bool _isCameraInitialized = false;

  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  double _baseScale = 1.0;

  final ImagePicker _picker = ImagePicker();

  String channelLogoPath = "";
  String studioBgImagePath = "";
  double logoWidth = 95.0;
  double logoHeight = 95.0;

  String watermarkText = "SS YATRA TV";
  String locationText = "LIVE KOTHAKOTA";
  String reporterName = "JANAMPALLY VINOD KUMAR";
  String reporterRole = "SPECIAL CORRESPONDENT";
  String breakingNewsText =
      "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";

  String splitScreenMainHeadline = "తాజా వార్తలు";
  String splitScreenSubHeadline = "వార్తా అప్డేట్";

  TextEditingController restreamRtmpController = TextEditingController();
  TextEditingController cableRtmpController = TextEditingController();
  TextEditingController satelliteSrtController = TextEditingController();
  TextEditingController networkVideoUrlCtrl = TextEditingController();
  TextEditingController youtubeVideoUrlCtrl = TextEditingController();
  TextEditingController watermarkCtrl = TextEditingController();
  TextEditingController locCtrl = TextEditingController();
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController roleCtrl = TextEditingController();
  TextEditingController manualTickerCtrl = TextEditingController();
  TextEditingController mainHeadlineCtrl = TextEditingController();
  TextEditingController subHeadlineCtrl = TextEditingController();
  TextEditingController pcIpController =
      TextEditingController(text: "172.22.108.41");

  TextEditingController ipCamUrlCtrl = TextEditingController();
  TextEditingController usbCamUrlCtrl = TextEditingController();

  List<TextEditingController> extraIpCtrls =
      List.generate(4, (i) => TextEditingController());
  List<TextEditingController> extraUsbCtrls =
      List.generate(4, (i) => TextEditingController());
  List<TextEditingController> droneCtrls =
      List.generate(2, (i) => TextEditingController());

  TimerTimer? _remoteConfigTimer;
  String _lastRemoteConfigBody = "";
  static const String _remoteConfigUrl =
    'https://raw.githubusercontent.com/broadcaststudioproject-dev/broadcast-studio/main/config.json';? _newsTimer;
  Timer? _adCycleTimer;
  Timer? _saveLinksTimer;
  Timer? _ytLoadTimer;

  int _tickerBgColorIndex = 0;
  Timer? _tickerColorTimer;
  final List<Color> bgColors = [
    const Color(0xFF0D47A1),
    const Color(0xFF800000),
    Colors.purple.shade900,
    Colors.teal.shade900
  ];

  List<String> leftAdPaths = [];
  List<String> rightAdPaths = [];
  List<String> bottomAdPaths = [];
  int leftAdIndex = 0;
  int rightAdIndex = 0;
  int bottomAdIndex = 0;

  bool isExternalIpCamMode = false;
  bool isUsbCamMode = false;
  int? _usbTextureId;
  final WatermarkController _wmController = WatermarkController();

  // PC లోని Flask సర్వర్‌కి వార్తలు పంపే ఫంక్షన్
  Future<void> sendNewsToPC(String newsText) async {
    final String pcIpAddress = pcIpController.text.trim();
    if (pcIpAddress.isEmpty) {
      if (mounted) {
        showCustomToast(context, "PC IP అడ్రెస్ ఇవ్వండి.",
            isLive: isLiveBroadcasting);
      }
      return;
    }
    final url = Uri.parse('http://$pcIpAddress:5000/generate');

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"text": newsText}),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      if (response.statusCode == 200) {
        showCustomToast(context, "సక్సెస్: PC లో వీడియో తయారవుతోంది!",
            isLive: isLiveBroadcasting);
      } else {
        showCustomToast(context, "ఫెయిల్ అయింది: ${response.body}",
            isLive: isLiveBroadcasting);
      }
    } on TimeoutException {
      if (mounted) {
        showCustomToast(context, "PC స్పందించలేదు (టైమ్ అవుట్).",
            isLive: isLiveBroadcasting);
      }
    } catch (e) {
      if (mounted) {
        showCustomToast(context, "కనెక్షన్ ఎర్రర్: $e",
            isLive: isLiveBroadcasting);
      }
    }
  }

  void _showAutoNewsDialog(BuildContext context) {
    final TextEditingController newsInputCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            "PC ఆటోమేటిక్ న్యూస్ బ్రాడ్‌కాస్ట్",
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "ఇక్కడ మీ వార్త టైప్ చేసి పంపిస్తే PC సర్వర్ ఆటోమేటిక్‌గా వీడియో తయారు చేస్తుంది.",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: newsInputCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.yellow, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "వార్త ఇక్కడ టైప్ చేయండి...",
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("రద్దు చేయి",
                  style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                final String textToSend = newsInputCtrl.text.trim();
                if (textToSend.isNotEmpty) {
                  sendNewsToPC(textToSend);
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.send, color: Colors.white, size: 16),
              label: const Text("PC కి పంపు",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ).then((_) => newsInputCtrl.dispose());
  }

  Widget _buildStandbyScreen() {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.satellite_alt, color: Colors.white24, size: 60),
            SizedBox(height: 15),
            Text("STANDBY / NO SIGNAL",
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3.0)),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!Platform.isWindows) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight
      ]);
    }

    StreamServiceManager.initializeStreamListener(context);

    _loadSavedData();
    _wmController.load();
    _requestPermissionsAndInitCamera();
    _fetchBreakingNews();
    _fetchRemoteConfig();
    _remoteConfigTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchRemoteConfig(),
    );

    _newsTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _fetchBreakingNews();
    });
    _tickerColorTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) setState(() => _tickerBgColorIndex++);
    });
  }

  Future<void> _fetchBreakingNews() async {
    try {
      final response = await http
          .get(Uri.parse('https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        final List<String> titles = [];
        for (var item in items.take(20)) {
          final titleEls = item.findElements('title');
          if (titleEls.isEmpty) continue;
          final t = titleEls.first.innerText.trim();
          if (t.isNotEmpty) titles.add(t);
        }
        if (titles.isNotEmpty && mounted) {
          setState(() {
            breakingNewsText = titles.join("   ♦   ");
          });
        }
      }
    } catch (e) {
      debugPrint("Breaking news fetch error: $e");
    }
  }

  Future<void> _fetchRemoteConfig({bool manual = false}) async {
  try {
    final uri = Uri.parse(
        '$_remoteConfigUrl?t=${DateTime.now().millisecondsSinceEpoch}');
    final response = await http.get(
      uri,
      headers: {'Cache-Control': 'no-cache'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return;
    if (!manual && response.body == _lastRemoteConfigBody) return;
    _lastRemoteConfigBody = response.body;

    final Map<String, dynamic> data = jsonDecode(response.body);
    if (!mounted) return;

    setState(() {
      final news = (data['breakingNews'] ?? '').toString().trim();
      if (news.isNotEmpty) breakingNewsText = news;

      final loc = (data['location'] ?? '').toString().trim();
      if (loc.isNotEmpty) {
        locationText = loc;
        locCtrl.text = loc;
      }

      final rName = (data['reporterName'] ?? '').toString().trim();
      if (rName.isNotEmpty) {
        reporterName = rName;
        nameCtrl.text = rName;
      }

      final rRole = (data['reporterRole'] ?? '').toString().trim();
      if (rRole.isNotEmpty) {
        reporterRole = rRole;
        roleCtrl.text = rRole;
      }

      final wm = (data['watermarkText'] ?? '').toString().trim();
      if (wm.isNotEmpty) {
        watermarkText = wm;
        watermarkCtrl.text = wm;
      }

      final mHead = (data['mainHeadline'] ?? '').toString().trim();
      if (mHead.isNotEmpty) {
        splitScreenMainHeadline = mHead;
        mainHeadlineCtrl.text = mHead;
      }

      final sHead = (data['subHeadline'] ?? '').toString().trim();
      if (sHead.isNotEmpty) {
        splitScreenSubHeadline = sHead;
        subHeadlineCtrl.text = sHead;
      }

      final ytUrl = (data['youtubeUrl'] ?? '').toString().trim();
      if (ytUrl.isNotEmpty) youtubeVideoUrlCtrl.text = ytUrl;

      final cable = (data['cableRtmp'] ?? '').toString().trim();
      if (cable.isNotEmpty) cableRtmpController.text = cable;

      final restream = (data['restreamRtmp'] ?? '').toString().trim();
      if (restream.isNotEmpty) restreamRtmpController.text = restream;

      final adMode = data['adMode'];
      if (adMode is int && adMode >= 0 && adMode <= 2 && adMode != adDisplayMode) {
        adDisplayMode = adMode;
        _adCycleTimer?.cancel();
        if (adMode == 0) {
          isAdCurrentlyShowing = false;
        } else if (adMode == 1) {
          isAdCurrentlyShowing = true;
          _startPermanentCycle();
        } else if (adMode == 2) {
          isAdCurrentlyShowing = true;
          _startAutoCycle();
        }
      }
    });

    if (manual) {
      showCustomToast(context, "రిమోట్ సెట్టింగ్స్ అప్‌డేట్ అయ్యాయి!",
          isLive: isLiveBroadcasting);
    }
  } catch (e) {
    debugPrint("Remote config error: $e");
  }
}
  void _setLogo(String path) {
    channelLogoPath = path;
    final old = _logoVideoCtrl;
    _logoVideoCtrl = null;
    old?.dispose();

    if (path.toLowerCase().endsWith('.mp4')) {
      final ctrl = VideoPlayerController.file(File(path));
      _logoVideoCtrl = ctrl;
      ctrl.initialize().then((_) {
        if (mounted && identical(_logoVideoCtrl, ctrl)) {
          ctrl.setLooping(true);
          ctrl.setVolume(0);
          ctrl.play();
          setState(() {});
        }
      }).catchError((e) {
        debugPrint("Logo video error: $e");
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedData() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final String savedLogo = prefs.getString('channelLogoPath') ?? "";

      setState(() {
        watermarkText = prefs.getString('watermarkText') ?? "SS YATRA TV";
        locationText = prefs.getString('locationText') ?? "LIVE KOTHAKOTA";
        reporterName =
            prefs.getString('reporterName') ?? "JANAMPALLY VINOD KUMAR";
        reporterRole = prefs.getString('reporterRole') ?? "SPECIAL CORRESPONDENT";
        breakingNewsText = prefs.getString('breakingNewsText') ??
            "తెలంగాణ మరియు జాతీయ తాజా అత్యవసర వార్తలు లోడ్ అవుతున్నాయి...";
        splitScreenMainHeadline =
            prefs.getString('splitScreenMainHeadline') ?? "తాజా వార్తలు";
        splitScreenSubHeadline =
            prefs.getString('splitScreenSubHeadline') ?? "వార్తా అప్డేట్";
        isNoiseCancellationEnabled = prefs.getBool('noiseCancel') ?? true;
        adShapeMode = prefs.getInt('adShapeMode') ?? 0;
        logoPosition = prefs.getInt('logoPosition') ?? 1;

        cableRtmpController.text = prefs.getString('cableRtmp') ?? "";
        restreamRtmpController.text = prefs.getString('restreamRtmp') ?? "";
        satelliteSrtController.text = prefs.getString('satelliteSrt') ?? "";
        youtubeVideoUrlCtrl.text = prefs.getString('youtubeVideoUrl') ?? "";
        networkVideoUrlCtrl.text = prefs.getString('networkVideoUrl') ?? "";
        pcIpController.text = prefs.getString('pcIpAddress') ?? "172.22.108.41";

        watermarkCtrl.text = watermarkText;
        locCtrl.text = locationText;
        nameCtrl.text = reporterName;
        roleCtrl.text = reporterRole;
        mainHeadlineCtrl.text = splitScreenMainHeadline;
        subHeadlineCtrl.text = splitScreenSubHeadline;

        ipCamUrlCtrl.text =
            prefs.getString('ipCamUrl') ?? "http://192.168.1.100:8080/video";
        usbCamUrlCtrl.text = prefs.getString('usbCamUrl') ?? "/dev/video0";

        for (int i = 0; i < 4; i++) {
          extraIpCtrls[i].text = prefs.getString('extraIp_$i') ?? "";
          extraUsbCtrls[i].text = prefs.getString('extraUsb_$i') ?? "";
        }
        for (int i = 0; i < 2; i++) {
          droneCtrls[i].text = prefs.getString('drone_$i') ?? "";
        }

        studioBgImagePath = prefs.getString('studioBgImagePath') ?? "";

        leftAdPaths = (prefs.getStringList('leftAdPaths') ?? [])
            .where((p) => File(p).existsSync())
            .toList();
        rightAdPaths = (prefs.getStringList('rightAdPaths') ?? [])
            .where((p) => File(p).existsSync())
            .toList();
        bottomAdPaths = (prefs.getStringList('bottomAdPaths') ?? [])
            .where((p) => File(p).existsSync())
            .toList();
      });

      // setState బయట (nested setState రాకుండా)
      if (savedLogo.isNotEmpty && File(savedLogo).existsSync()) {
        _setLogo(savedLogo);
      } else {
        channelLogoPath = "";
      }

      if (leftAdPaths.isNotEmpty) _initAdVideo('left');
      if (rightAdPaths.isNotEmpty) _initAdVideo('right');
      if (bottomAdPaths.isNotEmpty) _initAdVideo('bottom');
    } catch (e) {
      debugPrint("Load saved data error: $e");
    }
  }

  bool _isVideoPath(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp4') || p.endsWith('.mov') || p.endsWith('.gif');
  }

  void _initAdVideo(String pos) {
    String path = "";
    if (pos == 'left' && leftAdPaths.isNotEmpty) {
      path = leftAdPaths[leftAdIndex % leftAdPaths.length];
    } else if (pos == 'right' && rightAdPaths.isNotEmpty) {
      path = rightAdPaths[rightAdIndex % rightAdPaths.length];
    } else if (pos == 'bottom' && bottomAdPaths.isNotEmpty) {
      path = bottomAdPaths[bottomAdIndex % bottomAdPaths.length];
    }
    if (path.isEmpty) return;

    final bool isVideo = _isVideoPath(path);

    VideoPlayerController? old;
    if (pos == 'left') {
      old = _leftAdVideoCtrl;
      _leftAdVideoCtrl = null;
    } else if (pos == 'right') {
      old = _rightAdVideoCtrl;
      _rightAdVideoCtrl = null;
    } else {
      old = _bottomAdVideoCtrlForAds;
      _bottomAdVideoCtrlForAds = null;
    }
    old?.dispose();

    if (!isVideo) return;

    final ctrl = VideoPlayerController.file(File(path));
    if (pos == 'left') {
      _leftAdVideoCtrl = ctrl;
    } else if (pos == 'right') {
      _rightAdVideoCtrl = ctrl;
    } else {
      _bottomAdVideoCtrlForAds = ctrl;
    }

    ctrl.initialize().then((_) {
      if (!mounted) return;
      final current = pos == 'left'
          ? _leftAdVideoCtrl
          : (pos == 'right' ? _rightAdVideoCtrl : _bottomAdVideoCtrlForAds);
      if (!identical(current, ctrl)) return;
      ctrl.setLooping(true);
      ctrl.setVolume(0.0);
      ctrl.play();
      setState(() {});
    }).catchError((e) {
      debugPrint("Ad video error ($pos): $e");
    });
  }

  Future<void> _saveTextSettings() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString('watermarkText', watermarkText);
      await prefs.setString('locationText', locationText);
      await prefs.setString('reporterName', reporterName);
      await prefs.setString('reporterRole', reporterRole);
      await prefs.setString('splitScreenMainHeadline', splitScreenMainHeadline);
      await prefs.setString('splitScreenSubHeadline', splitScreenSubHeadline);
      await prefs.setString('breakingNewsText', breakingNewsText);
      await prefs.setString('pcIpAddress', pcIpController.text.trim());
      await prefs.setBool('noiseCancel', isNoiseCancellationEnabled);
      await prefs.setInt('adShapeMode', adShapeMode);
      await prefs.setInt('logoPosition', logoPosition);
    } catch (e) {
      debugPrint("Save text settings error: $e");
    }
  }

  void _saveLinks() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cableRtmp', cableRtmpController.text.trim());
      prefs.setString('restreamRtmp', restreamRtmpController.text.trim());
      prefs.setString('satelliteSrt', satelliteSrtController.text.trim());
      prefs.setString('youtubeVideoUrl', youtubeVideoUrlCtrl.text.trim());
      prefs.setString('networkVideoUrl', networkVideoUrlCtrl.text.trim());
      prefs.setString('ipCamUrl', ipCamUrlCtrl.text.trim());
      prefs.setString('usbCamUrl', usbCamUrlCtrl.text.trim());

      for (int i = 0; i < 4; i++) {
        prefs.setString('extraIp_$i', extraIpCtrls[i].text.trim());
        prefs.setString('extraUsb_$i', extraUsbCtrls[i].text.trim());
      }
      for (int i = 0; i < 2; i++) {
        prefs.setString('drone_$i', droneCtrls[i].text.trim());
      }
    }).catchError((e) {
      debugPrint("Save links error: $e");
    });
  }

  // ప్రతి అక్షరానికి డిస్క్ రైట్ కాకుండా (debounce)
  void _saveLinksDebounced() {
    _saveLinksTimer?.cancel();
    _saveLinksTimer = Timer(const Duration(milliseconds: 600), _saveLinks);
  }

  Future<void> _saveAdPaths(String pos, List<String> paths) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (pos == 'left') await prefs.setStringList('leftAdPaths', paths);
      if (pos == 'right') await prefs.setStringList('rightAdPaths', paths);
      if (pos == 'bottom') await prefs.setStringList('bottomAdPaths', paths);
    } catch (e) {
      debugPrint("Save ad paths error: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!Platform.isWindows &&
          isCameraVisible &&
          !isExternalIpCamMode &&
          !isUsbCamMode &&
          (controller == null || !controller!.value.isInitialized)) {
        _initCamera();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _newsTimer?.cancel();
    _remoteConfigTimer?.cancel();
    _adCycleTimer?.cancel();
    _tickerColorTimer?.cancel();
    _saveLinksTimer?.cancel();
    _ytLoadTimer?.cancel();

    controller?.dispose();

    _vlcBulletinCtrl?.removeListener(_vlcListener);
    _vlcBulletinCtrl?.dispose();

    _bulletinVideoController?.removeListener(_videoListener);
    _bulletinVideoController?.dispose();

    _ytController?.dispose();
    _bottomAdVideoController?.dispose();
    _leftAdVideoCtrl?.dispose();
    _rightAdVideoCtrl?.dispose();
    _bottomAdVideoCtrlForAds?.dispose();
    _logoVideoCtrl?.dispose();
    _vlcIpCamController?.dispose();
    _wmController.dispose();

    restreamRtmpController.dispose();
    cableRtmpController.dispose();
    satelliteSrtController.dispose();
    networkVideoUrlCtrl.dispose();
    youtubeVideoUrlCtrl.dispose();
    ipCamUrlCtrl.dispose();
    usbCamUrlCtrl.dispose();
    watermarkCtrl.dispose();
    locCtrl.dispose();
    nameCtrl.dispose();
    roleCtrl.dispose();
    manualTickerCtrl.dispose();
    mainHeadlineCtrl.dispose();
    subHeadlineCtrl.dispose();
    pcIpController.dispose();

    for (var c in extraIpCtrls) {
      c.dispose();
    }
    for (var c in extraUsbCtrls) {
      c.dispose();
    }
    for (var c in droneCtrls) {
      c.dispose();
    }

    super.dispose();
  }

  Future<void> _requestPermissionsAndInitCamera() async {
    if (Platform.isWindows) {
      if (mounted) {
        setState(() {
          isCameraVisible = false;
        });
      }
      return;
    }

    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
      Permission.photos,
      Permission.videos,
      Permission.notification,
    ].request();

    if (!mounted) return;

    setState(() {
      isCameraVisible = true;
    });

    await _initCamera();
  }

  Future<void> _initCamera() async {
    if (Platform.isWindows) return;

    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
      } catch (e) {
        debugPrint("Camera Discovery Error: $e");
      }
    }

    if (cameras.isEmpty) return;

    try {
      if (currentCameraIndex >= cameras.length) {
        currentCameraIndex = 0;
      }

      if (controller != null) {
        await controller!.dispose();
      }

      final camController = CameraController(
        cameras[currentCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
      );

      controller = camController;

      await camController.initialize();

      if (!mounted) return;

      _minZoomLevel = await camController.getMinZoomLevel();
      _maxZoomLevel = await camController.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint("Camera Initialization Error: $e");
    }
  }

  void _switchCamera() async {
    if (isExternalIpCamMode || isUsbCamMode) {
      showCustomToast(
        context,
        "ఎక్స్‌టర్నల్ కెమెరా మోడ్‌లో ఫోన్ కెమెరా స్విచ్ పనిచేయదు.",
        isLive: isLiveBroadcasting,
      );
      return;
    }

    if (cameras.length < 2) return;

    currentCameraIndex = currentCameraIndex == 0 ? 1 : 0;

    if (isCameraVisible) {
      await _initCamera();
    }

    if (!mounted) return;

    setState(() {
      isMenuOpen = false;
    });
  }

  void _toggleCameraVisibility() async {
    setState(() {
      isMenuOpen = false;
    });

    if (isExternalIpCamMode || isUsbCamMode) {
      final oldVlc = _vlcIpCamController;
      _vlcIpCamController = null;

      setState(() {
        isExternalIpCamMode = false;
        isUsbCamMode = false;
        isCameraVisible = false;
        _usbTextureId = null;
      });

      try {
        await oldVlc?.dispose();
      } catch (e) {
        debugPrint("IP cam dispose error: $e");
      }

      try {
        await StreamServiceManager.stopUsbCamera();
      } catch (e) {
        debugPrint("USB Camera Stop Error: $e");
      }

      return;
    }

    if (isCameraVisible) {
      setState(() {
        isCameraVisible = false;
        _isCameraInitialized = false;
      });

      await controller?.dispose();
      controller = null;
    } else {
      setState(() {
        isCameraVisible = true;
      });

      await _initCamera();
    }
  }

  Future<void> _startIpCamera(String url) async {
    if (url.isEmpty) return;

    showCustomToast(
      context,
      "IP కెమెరాకు కనెక్ట్ అవుతోంది...",
      isLive: isLiveBroadcasting,
    );

    try {
      final old = _vlcIpCamController;
      _vlcIpCamController = null;
      if (old != null) {
        await old.dispose();
      }

      _vlcIpCamController = VlcPlayerController.network(
        url,
        hwAcc: HwAcc.full,
        autoPlay: true,
        options: VlcPlayerOptions(),
      );

      if (!mounted) return;

      setState(() {
        isExternalIpCamMode = true;
        isUsbCamMode = false;
        isCameraVisible = true;
        isNewsBulletinMode = false;
        isYoutubeMode = false;
        isNetworkVideoMode = false;
        isDualScreenMode = false;
      });
    } catch (e) {
      debugPrint("IP Camera Error: $e");

      if (mounted) {
        showCustomToast(
          context,
          "IP కెమెరా కనెక్ట్ కాలేదు. లింక్ చెక్ చేయండి.",
          isLive: isLiveBroadcasting,
        );
      }
    }
  }

  Future<void> _startUsbCamera(String url) async {
    try {
      final int? textureId = await StreamServiceManager.startUsbCamera();

      if (textureId != null) {
        if (!mounted) return;

        setState(() {
          isUsbCamMode = true;
          isExternalIpCamMode = false;
          isCameraVisible = true;
          isNewsBulletinMode = false;
          isYoutubeMode = false;
          isNetworkVideoMode = false;
          _usbTextureId = textureId;
        });

        showCustomToast(
          context,
          "USB Capture Card కనెక్ట్ అయ్యింది!",
          isLive: isLiveBroadcasting,
        );
      } else if (mounted) {
        showCustomToast(
          context,
          "USB క్యాప్చర్ కార్డ్ దొరకలేదు.",
          isLive: isLiveBroadcasting,
        );
      }
    } on PlatformException catch (e) {
      debugPrint("USB Camera Platform Error: $e");

      if (mounted) {
        showCustomToast(
          context,
          "USB క్యాప్చర్ కార్డ్ ఎర్రర్.",
          isLive: isLiveBroadcasting,
        );
      }
    } catch (e) {
      debugPrint("USB Camera Error: $e");
    }
  }

  Widget _camSectionTitle(String text, Color color) {
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
    );
  }

  Widget _camFilledField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.yellow, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _camUnderlineField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.yellow, fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
      ),
    );
  }

  void _showExternalCamsDialog() {
    setState(() {
      isMenuOpen = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: DefaultTabController(
            length: 3,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "External Cameras & PCR Setup",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const TabBar(
                    indicatorColor: Colors.amber,
                    labelColor: Colors.amber,
                    unselectedLabelColor: Colors.white54,
                    tabs: [
                      Tab(
                          icon: Icon(Icons.wifi_tethering, size: 20),
                          text: "IP Cams"),
                      Tab(icon: Icon(Icons.usb, size: 20), text: "USB Cams"),
                      Tab(icon: Icon(Icons.flight, size: 20), text: "Drones"),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // IP CAMERA TAB
                        ListView(
                          children: [
                            _camSectionTitle(
                                "1. Main IP Camera (Studio Connect)",
                                Colors.greenAccent),
                            const SizedBox(height: 5),
                            _camFilledField(ipCamUrlCtrl, "rtsp://..."),
                            const SizedBox(height: 5),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent),
                              onPressed: () {
                                _saveLinks();
                                Navigator.pop(dialogContext);
                                _startIpCamera(ipCamUrlCtrl.text.trim());
                              },
                              icon: const Icon(Icons.cast,
                                  color: Colors.white, size: 18),
                              label: const Text("Connect to Main Screen",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ),
                            const Divider(color: Colors.white24, height: 25),
                            _camSectionTitle("PCR Board IP Cameras (2 to 5)",
                                Colors.orangeAccent),
                            const SizedBox(height: 5),
                            for (int i = 0; i < 4; i++) ...[
                              Text("IP Cam ${i + 2}",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                              _camUnderlineField(extraIpCtrls[i], "rtsp://..."),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),

                        // USB CAMERA TAB
                        ListView(
                          children: [
                            _camSectionTitle(
                                "1. Main USB Camera (Studio Connect)",
                                Colors.greenAccent),
                            const SizedBox(height: 5),
                            _camFilledField(usbCamUrlCtrl, "/dev/video0"),
                            const SizedBox(height: 5),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purpleAccent),
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _startUsbCamera(usbCamUrlCtrl.text.trim());
                              },
                              icon: const Icon(Icons.usb,
                                  color: Colors.white, size: 18),
                              label: const Text("Start USB Camera",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ),
                            const Divider(color: Colors.white24, height: 25),
                            _camSectionTitle("PCR Board USB Cameras (2 to 5)",
                                Colors.orangeAccent),
                            const SizedBox(height: 5),
                            for (int i = 0; i < 4; i++) ...[
                              Text("USB Cam ${i + 2}",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11)),
                              _camUnderlineField(
                                  extraUsbCtrls[i], "Device Path or Link"),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),

                        // DRONE CAMERA TAB
                        ListView(
                          children: [
                            _camSectionTitle(
                                "PCR Board Drones (1 & 2)", Colors.orangeAccent),
                            const SizedBox(height: 10),
                            for (int i = 0; i < 2; i++) ...[
                              Text("Drone ${i + 1}",
                                  style: const TextStyle(
                                      color: Colors.cyanAccent, fontSize: 11)),
                              _camFilledField(droneCtrls[i], "rtsp://..."),
                              const SizedBox(height: 15),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text("Close",
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          _saveLinks();
                          if (mounted) {
                            showCustomToast(
                              context,
                              "కెమెరా లింక్స్ అన్నీ సేవ్ అయ్యాయి!",
                              isLive: isLiveBroadcasting,
                            );
                          }
                        },
                        icon: const Icon(Icons.save,
                            color: Colors.white, size: 18),
                        label: const Text("Save All Links",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLiveControlDialog() {
    setState(() {
      isMenuOpen = false;
    });
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return Dialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    const Text("Live Control Room",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildLinkEditor("1. Primary Live Stream (Cable / RTMP)",
                        cableRtmpController, dialogContext,
                        onPlay: null),
                    const Divider(color: Colors.white24, height: 25),
                    _buildLinkEditor(
                        "2. Secondary Live Stream (Restream / YT)",
                        restreamRtmpController,
                        dialogContext,
                        onPlay: null),
                    const Divider(color: Colors.white24, height: 25),
                    _buildLinkEditor("3. Backup Stream (Satellite SRT)",
                        satelliteSrtController, dialogContext,
                        onPlay: null),
                    const Divider(color: Colors.white24, height: 25),
                    _buildLinkEditor("4. YouTube Live Video Link",
                        youtubeVideoUrlCtrl, dialogContext, onPlay: () {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      _startYoutubeVideo(youtubeVideoUrlCtrl.text.trim());
                    }),
                    const Divider(color: Colors.white24, height: 25),
                    _buildLinkEditor("5. Direct Network Video (MP4/m3u8)",
                        networkVideoUrlCtrl, dialogContext, onPlay: () {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      _startNetworkVideoMp4(networkVideoUrlCtrl.text.trim());
                    }),
                    const Divider(color: Colors.white24, height: 25),
                    const Text("6. గ్యాలరీ వీడియో (MP4, HD, 4K)",
                        style:
                            TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                    const SizedBox(height: 10),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30))),
                            onPressed: () {
                              Navigator.of(dialogContext, rootNavigator: true)
                                  .pop();
                              _playLocalGalleryVideo();
                            },
                            icon: const Icon(Icons.video_library,
                                color: Colors.white, size: 20),
                            label: const Text(
                                "గ్యాలరీ వీడియో తీసుకోండి (Multiple)",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)))),
                    const SizedBox(height: 30),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.of(dialogContext, rootNavigator: true)
                                    .pop();
                              },
                              child: const Text("Close",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15))),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30))),
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                _saveLinks();
                                Navigator.of(dialogContext, rootNavigator: true)
                                    .pop();
                                Future.delayed(
                                    const Duration(milliseconds: 300), () {
                                  if (mounted) _startLiveAndLock();
                                });
                              },
                              child: const Text("START BROADCAST",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)))
                        ])
                  ])),
            ),
          );
        });
  }

  Widget _buildLinkEditor(
      String label, TextEditingController controller, BuildContext dialogContext,
      {VoidCallback? onPlay}) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: controller,
                    style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    onChanged: (val) {
                      _saveLinksDebounced();
                    },
                    decoration: const InputDecoration(
                        hintText: "Paste link here...",
                        hintStyle: TextStyle(
                            color: Colors.white24,
                            fontWeight: FontWeight.normal),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.cyanAccent))))),
            IconButton(
                icon: const Icon(Icons.save, color: Colors.blueAccent, size: 28),
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _saveLinks();
                  if (mounted) {
                    showCustomToast(context, "✔️ లింక్ సేవ్ అయ్యింది!",
                        isLive: isLiveBroadcasting);
                  }
                }),
            if (onPlay != null)
              IconButton(
                  icon: const Icon(Icons.play_circle_fill,
                      color: Colors.greenAccent, size: 34),
                  onPressed: onPlay)
          ])
        ]);
  }

  String? _youtubeVideoIdFromUrl(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null) return null;

    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    String? id;

    if (host == 'youtu.be') {
      if (uri.pathSegments.isNotEmpty) {
        id = uri.pathSegments.first;
      }
    } else if (host == 'youtube.com' ||
        host == 'm.youtube.com' ||
        host == 'music.youtube.com') {
      id = uri.queryParameters['v'];

      if (id == null || id.isEmpty) {
        final segments = uri.pathSegments;
        for (var i = 0; i < segments.length - 1; i++) {
          if (segments[i] == 'live' ||
              segments[i] == 'shorts' ||
              segments[i] == 'embed') {
            id = segments[i + 1];
            break;
          }
        }
      }
    } else {
      try {
        id = YoutubePlayer.convertUrlToId(input.trim());
      } catch (_) {
        id = null;
      }
    }

    if (id == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
      return null;
    }
    return id;
  }

  void _failYoutubeLoad(String message) {
    _ytLoadTimer?.cancel();
    final old = _ytController;
    _ytController = null;
    old?.dispose();

    if (!mounted) return;
    setState(() {
      isYoutubeLoading = false;
      isYoutubeMode = false;
      isNewsBulletinMode = false;
      isCameraVisible = !Platform.isWindows;
      hideControls = false;
    });
    showCustomToast(context, message, isLive: isLiveBroadcasting);
  }

  Future<void> _startYoutubeVideo(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty || !mounted) return;

    final videoId = _youtubeVideoIdFromUrl(cleanUrl);
    if (videoId == null) {
      showCustomToast(
        context,
        "సరైన YouTube వీడియో లేదా Live లింక్ ఇవ్వండి.",
        isLive: isLiveBroadcasting,
      );
      return;
    }

    // Windows లో WebView2 ద్వారా నేరుగా లోడ్
    if (Platform.isWindows) {
      setState(() {
        _windowsYoutubeVideoId = videoId;
        isYoutubeLoading = false;
        isCameraVisible = false;
        isNewsBulletinMode = false;
        isNetworkVideoMode = false;
        isYoutubeMode = true;
        isDualScreenMode = false;
        hideControls = false;
      });

      if (_winYtWebViewCtrl != null) {
        try {
          await _winYtWebViewCtrl!.loadUrl(
            urlRequest: URLRequest(
              url: WebUri('https://www.youtube.com/watch?v=$videoId'),
            ),
          );
        } catch (e) {
          debugPrint("Windows YT load error: $e");
        }
      }
      return;
    }

    setState(() {
      isYoutubeLoading = true;
      isCameraVisible = false;
      isNewsBulletinMode = false;
      isNetworkVideoMode = false;
      isYoutubeMode = true;
      isDualScreenMode = false;
    });

    showCustomToast(
      context,
      "YouTube వీడియో లోడ్ అవుతోంది...",
      isLive: isLiveBroadcasting,
    );

    try {
      _ytController?.dispose();

      final playerController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: false,
        ),
      );

      _ytController = playerController;

      // 20 సెకన్లలో ready కాకపోతే spinner ఆపి కెమెరాకు తిరిగి వెళ్తాం
      _ytLoadTimer?.cancel();
      _ytLoadTimer = Timer(const Duration(seconds: 20), () {
        if (isYoutubeLoading && identical(_ytController, playerController)) {
          _failYoutubeLoad(
              "YouTube లోడ్ అవ్వడానికి ఎక్కువ సమయం పట్టింది. లింక్ తనిఖీ చేయండి.");
        }
      });

      var playerReady = false;
      var liveStartRequested = false;

      playerController.addListener(() {
        if (!mounted || !identical(_ytController, playerController)) return;

        if (playerController.value.hasError && !playerReady) {
          _failYoutubeLoad("ఈ YouTube వీడియో ప్లే చేయడం సాధ్యం కాదు.");
          return;
        }

        if (playerController.value.isReady && !playerReady) {
          playerReady = true;
          _ytLoadTimer?.cancel();

          setState(() {
            isYoutubeLoading = false;
            isYoutubeMode = true;
            isNewsBulletinMode = false;
            isNetworkVideoMode = false;
            isCameraVisible = false;
            hideControls = false;
          });

          if (kAutoGoLiveOnMedia &&
              !Platform.isWindows &&
              !isLiveBroadcasting &&
              !liveStartRequested) {
            liveStartRequested = true;
            _startLiveAndLock();
          }
        }
      });

      setState(() {});
    } catch (e, stackTrace) {
      debugPrint("YouTube Player Error: $e\n$stackTrace");
      _failYoutubeLoad(
          "YouTube వీడియో ప్లే కాలేదు. లింక్ లేదా ఇంటర్నెట్‌ను తనిఖీ చేయండి.");
    }
  }

  Future<void> _playNetworkBulletin(String playUrl) async {
    final uri = Uri.tryParse(playUrl.trim());
    if (uri == null || !uri.hasScheme) {
      if (mounted) {
        showCustomToast(context, "సరైన వీడియో లింక్ ఇవ్వండి.",
            isLive: isLiveBroadcasting);
      }
      return;
    }

    try {
      final previous = _bulletinVideoController;
      _bulletinVideoController = null;
      if (previous != null) {
        previous.removeListener(_videoListener);
        await previous.dispose();
      }

      final ctrl = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Referer': 'https://www.youtube.com/',
          'Origin': 'https://www.youtube.com',
        },
      );

      _bulletinVideoController = ctrl;

      await ctrl.initialize();

      if (!mounted || !identical(_bulletinVideoController, ctrl)) {
        await ctrl.dispose();
        return;
      }

      ctrl.addListener(_videoListener);
      await ctrl.setVolume(isBulletinMuted ? 0.0 : 1.0);
      await ctrl.play();

      if (!mounted) return;

      setState(() {
        isNewsBulletinMode = true;
        isNetworkVideoMode = true;
        isYoutubeMode = false;
        isCameraVisible = false;
        hideControls = false;
      });
    } catch (e, stackTrace) {
      debugPrint("Network bulletin playback error: $e\n$stackTrace");
      final failed = _bulletinVideoController;
      _bulletinVideoController = null;
      if (failed != null) {
        failed.removeListener(_videoListener);
        await failed.dispose();
      }

      if (!mounted) return;

      setState(() {
        isNewsBulletinMode = false;
        isNetworkVideoMode = false;
        isCameraVisible = !Platform.isWindows;
      });

      showCustomToast(
        context,
        "వీడియో ప్లే కాలేదు. లింక్/ఫార్మాట్‌ను తనిఖీ చేయండి.",
        isLive: isLiveBroadcasting,
      );
    }
  }

  void _videoListener() {
    final ctrl = _bulletinVideoController;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    final duration = ctrl.value.duration;
    if (duration == Duration.zero) return;

    if (ctrl.value.position >= duration) {
      ctrl.removeListener(_videoListener);
      if (mounted) {
        setState(() {
          isNewsBulletinMode = false;
          isNetworkVideoMode = false;
          isCameraVisible = !Platform.isWindows;
        });
      }
    }
  }

  Future<void> _startNetworkVideoMp4(String url) async {
    if (url.isEmpty) return;
    await _playNetworkBulletin(url.trim());
  }

  Future<void> _resetOrientationToAuto() async {
    if (!Platform.isWindows) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight
      ]);
    }
  }

  Future<void> _startLiveAndLock() async {
    _saveLinks();
    final String cableUrl = cableRtmpController.text.trim();
    final String restreamUrl = restreamRtmpController.text.trim();
    final String satUrl = satelliteSrtController.text.trim();

    if (cableUrl.isEmpty && restreamUrl.isEmpty && satUrl.isEmpty) {
      if (mounted) {
        showCustomToast(context, "దయచేసి కనీసం ఒక లైవ్ లింక్ ఇవ్వండి.",
            isLive: isLiveBroadcasting);
      }
      return;
    }

    try {
      if (!Platform.isWindows) {
        try {
          final micStatus = await Permission.microphone.status;
          if (!micStatus.isGranted) {
            await Permission.microphone.request();
          }
        } catch (e) {
          debugPrint("Mic permission error: $e");
        }
      }

      if (!mounted) return;
      setState(() {
        hideControls = true;
        isMenuOpen = false;
        isLandscape = true;
      });

      if (!Platform.isWindows) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeRight,
          DeviceOrientation.landscapeLeft
        ]);
      }

      if (!mounted) return;
      showCustomToast(context, "లైవ్ కనెక్ట్ అవుతోంది... దయచేసి వేచి ఉండండి",
          isLive: false);

      await Future.delayed(const Duration(milliseconds: 3000));
      if (!mounted) return;

      final bool success = await StreamServiceManager.startLiveStreamMulti(
              cableUrl, restreamUrl, satUrl)
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (success) {
        setState(() {
          isLiveBroadcasting = true;
          isLivePaused = false;
          isLiveLocked = false;
        });
      } else {
        setState(() {
          hideControls = false;
        });
        showCustomToast(
            context, "బ్రాడ్ కాస్ట్ ఫెయిల్. సిస్టమ్ ఫాల్స్ ఇచ్చింది.",
            isLive: false);
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        hideControls = false;
      });
      showCustomToast(context, "టైమ్ అవుట్: కనెక్ట్ అవ్వడానికి సమయం పట్టింది.",
          isLive: false);
      await _resetOrientationToAuto();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        hideControls = false;
      });
      showCustomToast(context, "ఎర్రర్: $e", isLive: false);
      await _resetOrientationToAuto();
    }
  }

  Future<void> _playLocalGalleryVideo() async {
    try {
      final List<XFile> mediaFiles = await _picker.pickMultipleMedia();
      if (mediaFiles.isNotEmpty) {
        final List<String> videoPaths = mediaFiles.map((e) => e.path).where((path) {
          final String lower = path.toLowerCase();
          return lower.endsWith('.mp4') ||
              lower.endsWith('.mov') ||
              lower.endsWith('.mkv') ||
              lower.endsWith('.avi');
        }).toList();

        if (videoPaths.isEmpty) {
          if (mounted) {
            showCustomToast(
              context,
              "వీడియోలను మాత్రమే సెలెక్ట్ చేయండి.",
              isLive: isLiveBroadcasting,
            );
          }
          return;
        }

        localVideoPlaylist = videoPaths;
        currentLocalVideoIndex = 0;
        _vlcFailCount = 0;
        await _playNextVlcVideo();
      }
    } catch (e) {
      debugPrint("Gallery Video Selection Error: $e");
    }
  }

  Future<void> _playNextVlcVideo() async {
    if (!mounted) return;

    if (currentLocalVideoIndex >= localVideoPlaylist.length) {
      setState(() {
        isNewsBulletinMode = false;
        isCameraVisible = !Platform.isWindows;
      });
      return;
    }

    showCustomToast(
      context,
      "వీడియో ${currentLocalVideoIndex + 1}/${localVideoPlaylist.length} ప్లే అవుతోంది...",
      isLive: isLiveBroadcasting,
    );

    final old = _vlcBulletinCtrl;
    _vlcBulletinCtrl = null;
    if (old != null) {
      old.removeListener(_vlcListener);
      try {
        await old.dispose();
      } catch (e) {
        debugPrint("VLC dispose error: $e");
      }
    }
    if (!mounted) return;

    final ctrl = VlcPlayerController.file(
      File(localVideoPlaylist[currentLocalVideoIndex]),
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(),
    );
    _vlcBulletinCtrl = ctrl;

    ctrl.initialize().then((_) {
      if (!mounted || !identical(_vlcBulletinCtrl, ctrl)) return;

      _vlcFailCount = 0;
      ctrl.setVolume(isBulletinMuted ? 0 : 100);

      setState(() {
        isNewsBulletinMode = true;
        isYoutubeMode = false;
        isNetworkVideoMode = false;
        isDualScreenMode = false;
        hideControls = false;
        isCameraVisible = false;
      });

      ctrl.play();
      ctrl.addListener(_vlcListener);

      if (kAutoGoLiveOnMedia && !isLiveBroadcasting) {
        _startLiveAndLock();
      }
    }).catchError((e) {
      if (!mounted || !identical(_vlcBulletinCtrl, ctrl)) return;
      debugPrint("VLC init error: $e");
      showCustomToast(
        context,
        "వీడియో ప్లే కాలేదు. ఫార్మాట్ ఎర్రర్.",
        isLive: isLiveBroadcasting,
      );
      _vlcFailCount++;
      currentLocalVideoIndex++;
      // అన్నీ వరుసగా fail అయితే ఆపేస్తాం (అనంత recursion రాకుండా)
      if (_vlcFailCount > localVideoPlaylist.length) {
        setState(() {
          isNewsBulletinMode = false;
          isCameraVisible = !Platform.isWindows;
        });
        return;
      }
      _playNextVlcVideo();
    });
  }

  void _vlcListener() {
    final ctrl = _vlcBulletinCtrl;
    if (ctrl == null) return;

    if (ctrl.value.isEnded) {
      ctrl.removeListener(_vlcListener);
      currentLocalVideoIndex++;
      _playNextVlcVideo();
    }
  }

  void _toggleMute() {
    HapticFeedback.mediumImpact();

    setState(() {
      isBulletinMuted = !isBulletinMuted;

      if (isNewsBulletinMode && _vlcBulletinCtrl != null) {
        _vlcBulletinCtrl?.setVolume(isBulletinMuted ? 0 : 100);
      }

      if (isNetworkVideoMode && _bulletinVideoController != null) {
        _bulletinVideoController?.setVolume(isBulletinMuted ? 0.0 : 1.0);
      }

      if (isYoutubeMode && _ytController != null) {
        isBulletinMuted ? _ytController!.mute() : _ytController!.unMute();
      }
    });
  }

  Future<void> _stopLiveStream() async {
    try {
      final bool success = await StreamServiceManager.stopLiveStream();

      if (success) {
        await _resetOrientationToAuto();
        if (!mounted) return;

        setState(() {
          isLiveBroadcasting = false;
          isLiveLocked = false;
          isLivePaused = false;
        });

        showCustomToast(context, "లైవ్ ఆగిపోయింది ❌", isLive: false);
      } else if (mounted) {
        showCustomToast(context, "లైవ్ ఆపడం విఫలమైంది.", isLive: false);
      }
    } catch (e) {
      debugPrint("Stop live error: $e");
    }
  }

  // PAUSE: స్ట్రీమ్ ఆపకుండా "LIVE PAUSED" స్క్రీన్ చూపిస్తుంది. కనెక్షన్ తెగదు.
  void _togglePauseLive() {
    setState(() {
      isLivePaused = !isLivePaused;
    });
    showCustomToast(
      context,
      isLivePaused ? "లైవ్ పాజ్ చేయబడింది." : "లైవ్ మళ్లీ మొదలైంది!",
      isLive: true,
    );
  }

  Future<void> _pickAds(String pos) async {
    try {
      final List<XFile> medias = await _picker.pickMultipleMedia();

      if (medias.isNotEmpty && mounted) {
        setState(() {
          if (pos == 'left') {
            leftAdPaths.addAll(medias.map((e) => e.path));
            leftAdIndex = leftAdPaths.length - 1;
            _saveAdPaths(pos, leftAdPaths);
          }

          if (pos == 'right') {
            rightAdPaths.addAll(medias.map((e) => e.path));
            rightAdIndex = rightAdPaths.length - 1;
            _saveAdPaths(pos, rightAdPaths);
          }

          if (pos == 'bottom') {
            bottomAdPaths.addAll(medias.map((e) => e.path));
            bottomAdIndex = bottomAdPaths.length - 1;
            _saveAdPaths(pos, bottomAdPaths);
          }
        });
        _initAdVideo(pos);
      }
    } catch (e) {
      debugPrint("Pick ads error: $e");
    }
  }

  void _manageAdsDialog(String pos) {
    List<String> getPaths() {
      if (pos == 'left') return leftAdPaths;
      if (pos == 'right') return rightAdPaths;
      return bottomAdPaths;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final currentPaths = getPaths();
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(
                "Manage ${pos.toUpperCase()} Ads",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: currentPaths.isEmpty
                    ? const Text("యాడ్స్ ఏమీ లేవు.",
                        style: TextStyle(color: Colors.white54))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: currentPaths.length,
                        itemBuilder: (ctx, idx) {
                          final String path = currentPaths[idx];
                          final bool isVideo = _isVideoPath(path);

                          return ListTile(
                            leading: isVideo
                                ? const Icon(Icons.video_file,
                                    color: Colors.blueAccent, size: 40)
                                : Image.file(
                                    File(path),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        color: Colors.white54),
                                  ),
                            title: Text("Ad ${idx + 1}",
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  currentPaths.removeAt(idx);
                                  _saveAdPaths(pos, currentPaths);

                                  if (pos == 'left' &&
                                      leftAdIndex >= leftAdPaths.length) {
                                    leftAdIndex = 0;
                                  }
                                  if (pos == 'right' &&
                                      rightAdIndex >= rightAdPaths.length) {
                                    rightAdIndex = 0;
                                  }
                                  if (pos == 'bottom' &&
                                      bottomAdIndex >= bottomAdPaths.length) {
                                    bottomAdIndex = 0;
                                  }
                                });
                                _initAdVideo(pos);
                                setDialogState(() {});
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  child: const Text("Clear All",
                      style: TextStyle(color: Colors.redAccent)),
                  onPressed: () {
                    setState(() {
                      currentPaths.clear();
                      _saveAdPaths(pos, currentPaths);

                      if (pos == 'left') {
                        leftAdIndex = 0;
                        _leftAdVideoCtrl?.dispose();
                        _leftAdVideoCtrl = null;
                      }
                      if (pos == 'right') {
                        rightAdIndex = 0;
                        _rightAdVideoCtrl?.dispose();
                        _rightAdVideoCtrl = null;
                      }
                      if (pos == 'bottom') {
                        bottomAdIndex = 0;
                        _bottomAdVideoCtrlForAds?.dispose();
                        _bottomAdVideoCtrlForAds = null;
                      }
                    });

                    Navigator.pop(ctx);
                  },
                ),
                TextButton(
                  child: const Text("Close",
                      style: TextStyle(color: Colors.white)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog() {
    setState(() {
      isMenuOpen = false;
    });
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
                backgroundColor: Colors.grey[900],
                title: const Text("స్టూడియో సెట్టింగ్స్",
                    style: TextStyle(color: Colors.white, fontSize: 13)),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final XFile? media = await _picker.pickMedia();
                          if (media != null) {
                            final SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setString('channelLogoPath', media.path);
                            _setLogo(media.path);
                            setDialogState(() {});
                          }
                        } catch (e) {
                          debugPrint("Logo pick error: $e");
                        }
                      },
                      icon: const Icon(Icons.upload),
                      label: const Text("ఛానల్ లోగో అప్లోడ్ (MP4/GIF/JPEG)")),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final XFile? img = await _picker.pickImage(
                              source: ImageSource.gallery);
                          if (img != null) {
                            final SharedPreferences prefs =
                                await SharedPreferences.getInstance();
                            await prefs.setString('studioBgImagePath', img.path);
                            if (mounted) {
                              setState(() => studioBgImagePath = img.path);
                            }
                            setDialogState(() {});
                            if (mounted) {
                              showCustomToast(
                                  this.context,
                                  "స్టూడియో బ్యాక్‌గ్రౌండ్ ఇమేజ్ సెట్ అయ్యింది!",
                                  isLive: isLiveBroadcasting);
                            }
                          }
                        } catch (e) {
                          debugPrint("Background pick error: $e");
                        }
                      },
                      icon: const Icon(Icons.wallpaper),
                      label: const Text("స్టూడియో బ్యాక్‌గ్రౌండ్ ఇమేజ్ సెట్ చేయండి",
                          style: TextStyle(fontSize: 12))),
                  const Divider(color: Colors.white24, height: 20),
                  TextField(
                      controller: mainHeadlineCtrl,
                      style: const TextStyle(color: Colors.yellow),
                      decoration: const InputDecoration(
                          labelText: "మెయిన్ హెడ్‌లైన్ (Yellow Box)")),
                  TextField(
                      controller: subHeadlineCtrl,
                      style: const TextStyle(color: Colors.cyanAccent),
                      decoration: const InputDecoration(
                          labelText: "సబ్ హెడ్‌‌లైన్ (Blue Box)")),
                  const Divider(color: Colors.white24, height: 20),
                  TextField(
                    controller: pcIpController,
                    style: const TextStyle(
                        color: Colors.yellow, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      labelText: "PC IP Address (ఉదా: 172.22.108.41)",
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: manualTickerCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: "మాన్యువల్ బ్రేకింగ్ టిక్కర్")),
                  ElevatedButton(
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      onPressed: () async {
                        if (manualTickerCtrl.text.trim().isNotEmpty) {
                          setState(() {
                            breakingNewsText = manualTickerCtrl.text.trim();
                          });
                          await _saveTextSettings();
                          manualTickerCtrl.clear();
                          setDialogState(() {});
                        }
                      },
                      child: const Text("టిక్కర్ అప్‌డేట్ చేయి",
                          style: TextStyle(color: Colors.black))),
                  TextField(
                      controller: watermarkCtrl,
                      style: const TextStyle(color: Colors.yellow),
                      decoration: const InputDecoration(labelText: "వాటర్ మార్క్")),
                  TextField(
                      controller: locCtrl,
                      style: const TextStyle(color: Colors.yellow),
                      decoration: const InputDecoration(labelText: "లొకేషన్")),
                  TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.yellow),
                      decoration:
                          const InputDecoration(labelText: "రిపోర్టర్ పేరు")),
                  TextField(
                      controller: roleCtrl,
                      style: const TextStyle(color: Colors.yellow),
                      decoration: const InputDecoration(labelText: "హోదా")),
                  const Divider(color: Colors.white24, height: 20),
                  SwitchListTile(
                    title: const Text(
                        "Noise Cancellation\n(ఆడియో నాయిస్ క్యాన్సిలేషన్)",
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                    value: isNoiseCancellationEnabled,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) {
                      setState(() => isNoiseCancellationEnabled = val);
                      setDialogState(() {});
                    },
                  ),
                ])),
                actions: [
                  ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          splitScreenMainHeadline = mainHeadlineCtrl.text;
                          splitScreenSubHeadline = subHeadlineCtrl.text;
                          watermarkText = watermarkCtrl.text;
                          locationText = locCtrl.text;
                          reporterName = nameCtrl.text;
                          reporterRole = roleCtrl.text;
                        });
                        await _saveTextSettings();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text("Save & Close"))
                ]);
          });
        });
  }

  void _changeLogoPosition() async {
    setState(() {
      logoPosition = (logoPosition + 1) % 4;
      isMenuOpen = false;
    });
    await _saveTextSettings();
  }

  void _toggleRotation() {
    if (Platform.isWindows) return;
    setState(() {
      isMenuOpen = false;
      isLandscape = !isLandscape;
      if (isLandscape) {
        SystemChrome.setPreferredOrientations(
            [DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    });
  }

  Future<void> _toggleDualScreenAndPickMedia() async {
    setState(() {
      isMenuOpen = false;
    });
    if (isDualScreenMode) {
      setState(() {
        isDualScreenMode = false;
        dualMediaList.clear();
        _bottomAdVideoController?.dispose();
        _bottomAdVideoController = null;
      });
      return;
    }
    try {
      final List<XFile> medias = await _picker.pickMultipleMedia();
      if (medias.isNotEmpty && mounted) {
        dualMediaList = medias.map((e) => e.path).toList();
        currentDualMediaIndex = 0;
        setState(() {
          isDualScreenMode = true;
          isNewsBulletinMode = false;
          isNetworkVideoMode = false;
          isYoutubeMode = false;
        });
        _playDualMedia(dualMediaList[currentDualMediaIndex]);
      }
    } catch (e) {
      debugPrint("Dual screen pick error: $e");
    }
  }

  void _playDualMedia(String path) {
    final old = _bottomAdVideoController;
    _bottomAdVideoController = null;
    old?.dispose();

    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) {
      final ctrl = VideoPlayerController.file(File(path));
      _bottomAdVideoController = ctrl;
      ctrl.initialize().then((_) {
        if (mounted && identical(_bottomAdVideoController, ctrl)) {
          ctrl.setLooping(true);
          ctrl.setVolume(1.0);
          ctrl.play();
          setState(() {});
        }
      }).catchError((e) {
        debugPrint("Dual media error: $e");
      });
    } else {
      setState(() {});
    }
  }

  void _prevDualMedia() {
    if (dualMediaList.isEmpty) return;
    currentDualMediaIndex = (currentDualMediaIndex - 1) < 0
        ? dualMediaList.length - 1
        : currentDualMediaIndex - 1;
    _playDualMedia(dualMediaList[currentDualMediaIndex]);
  }

  void _nextDualMedia() {
    if (dualMediaList.isEmpty) return;
    currentDualMediaIndex = (currentDualMediaIndex + 1) % dualMediaList.length;
    _playDualMedia(dualMediaList[currentDualMediaIndex]);
  }

  void _toggleDualMediaPause() {
    final c = _bottomAdVideoController;
    if (c != null) {
      c.value.isPlaying ? c.pause() : c.play();
      setState(() {});
    }
  }

  void _advanceAdIndexes() {
    if (leftAdPaths.isNotEmpty) {
      leftAdIndex = (leftAdIndex + 1) % leftAdPaths.length;
    }
    if (rightAdPaths.isNotEmpty) {
      rightAdIndex = (rightAdIndex + 1) % rightAdPaths.length;
    }
    if (bottomAdPaths.isNotEmpty) {
      bottomAdIndex = (bottomAdIndex + 1) % bottomAdPaths.length;
    }
    _initAdVideo('left');
    _initAdVideo('right');
    _initAdVideo('bottom');
  }

  void _toggleAdMode() {
    setState(() {
      adDisplayMode = (adDisplayMode + 1) % 3;
      isMenuOpen = false;
      _adCycleTimer?.cancel();

      if (adDisplayMode == 0) {
        isAdCurrentlyShowing = false;
        showCustomToast(context, "Ads OFF", isLive: isLiveBroadcasting);
      } else if (adDisplayMode == 1) {
        isAdCurrentlyShowing = true;
        _startPermanentCycle();
        showCustomToast(context, "Ads ON", isLive: isLiveBroadcasting);
      } else if (adDisplayMode == 2) {
        isAdCurrentlyShowing = true;
        _startAutoCycle();
        showCustomToast(context, "Auto Ads", isLive: isLiveBroadcasting);
      }
    });
  }

  void _startPermanentCycle() {
    _adCycleTimer?.cancel();
    _adCycleTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted && adDisplayMode == 1) {
        setState(_advanceAdIndexes);
      }
    });
  }

  void _startAutoCycle() {
    _adCycleTimer?.cancel();
    if (isAdCurrentlyShowing) {
      _adCycleTimer = Timer(const Duration(seconds: 20), () {
        if (mounted && adDisplayMode == 2) {
          setState(() => isAdCurrentlyShowing = false);
          _startAutoCycle();
        }
      });
    } else {
      _adCycleTimer = Timer(const Duration(seconds: 40), () {
        if (mounted && adDisplayMode == 2) {
          setState(() {
            isAdCurrentlyShowing = true;
            _advanceAdIndexes();
          });
          _startAutoCycle();
        }
      });
    }
  }

  void _toggleAdShapeMode() async {
    setState(() {
      adShapeMode = (adShapeMode + 1) % 3;
      isMenuOpen = false;
    });
    await _saveTextSettings();
  }

  void _toggleLBandDirection() {
    setState(() {
      isLBandRight = !isLBandRight;
      isMenuOpen = false;
    });
  }

  void _toggleReporterDetails() {
    setState(() {
      showReporterDetails = !showReporterDetails;
      isMenuOpen = false;
    });
    showCustomToast(
        context,
        showReporterDetails
            ? "రిపోర్టర్ డీటెయిల్స్ ఆన్ చేయబడ్డాయి"
            : "రిపోర్టర్ డీటెయిల్స్ ఆఫ్ చేయబడ్డాయి",
        isLive: isLiveBroadcasting);
  }

  // యాడ్ స్లాట్ (left / right / bottom కోసం ఒకే ఫంక్షన్)
  Widget _buildAdSlot(String pos, String label, List<String> paths, int index,
      VideoPlayerController? vc) {
    Widget content;
    if (paths.isEmpty) {
      content = Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    } else if (vc != null && vc.value.isInitialized) {
      content = FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: vc.value.size.width,
          height: vc.value.size.height,
          child: VideoPlayer(vc),
        ),
      );
    } else {
      content = SizedBox.expand(
        child: Image.file(
          File(paths[index % paths.length]),
          fit: BoxFit.fill,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    return GestureDetector(
      onTap: paths.isEmpty ? () => _pickAds(pos) : null,
      onLongPress: paths.isNotEmpty ? () => _manageAdsDialog(pos) : null,
      child: Container(color: Colors.transparent, child: content),
    );
  }

  // డ్యూయల్ స్క్రీన్ లో మీడియా భాగం (పోర్ట్రెయిట్ / ల్యాండ్‌స్కేప్ రెండింటికీ)
  Widget _buildDualMediaPane() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final double dx = details.localPosition.dx;
            if (dx < constraints.maxWidth / 3) {
              _prevDualMedia();
            } else if (dx > constraints.maxWidth * 2 / 3) {
              _nextDualMedia();
            } else {
              _toggleDualMediaPause();
            }
          },
          child: _bottomAdVideoController != null &&
                  _bottomAdVideoController!.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _bottomAdVideoController!.value.size.width,
                    height: _bottomAdVideoController!.value.size.height,
                    child: VideoPlayer(_bottomAdVideoController!),
                  ),
                )
              : Image.file(
                  File(dualMediaList[currentDualMediaIndex]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
        );
      },
    );
  }

  Widget _buildMainDisplay(
    bool isScreenLandscape,
    double screenWidth,
    double screenHeight,
    Widget phoneCameraWidget,
  ) {
    Widget actualCameraWidget;

    if (isLivePaused) {
      actualCameraWidget = Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            "LIVE PAUSED",
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else if (isExternalIpCamMode && _vlcIpCamController != null) {
      actualCameraWidget = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 1920,
            height: 1080,
            child: VlcPlayer(
              controller: _vlcIpCamController!,
              aspectRatio: 16 / 9,
              placeholder: const Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            ),
          ),
        ),
      );
    } else if (isUsbCamMode && _usbTextureId != null) {
      actualCameraWidget = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 1920,
            height: 1080,
            child: Texture(textureId: _usbTextureId!),
          ),
        ),
      );
    } else if (phoneCameraWidget is Container &&
        phoneCameraWidget.color == Colors.transparent) {
      actualCameraWidget = _buildStandbyScreen();
    } else {
      actualCameraWidget = phoneCameraWidget;
    }

    if (isDualScreenMode && dualMediaList.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: const Color(0xFF800000), width: 3.5),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
        ),
        child: isScreenLandscape
            ? Row(
                children: [
                  Expanded(child: actualCameraWidget),
                  Container(width: 3, color: const Color(0xFF800000)),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _buildDualMediaPane()),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          color: Colors.amber,
                          child: Text(
                            splitScreenMainHeadline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.blueAccent,
                          child: Text(
                            splitScreenSubHeadline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(flex: 4, child: actualCameraWidget),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    color: Colors.amber,
                    child: Text(
                      splitScreenMainHeadline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    color: Colors.blueAccent,
                    child: Text(
                      splitScreenSubHeadline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(flex: 4, child: _buildDualMediaPane()),
                ],
              ),
      );
    }

    // ---- యాడ్ లేఅవుట్: 0 = L-Band, 1 = U-Band, 2 = Bottom only ----
    final double safeW = screenWidth.clamp(0.0, double.infinity);
    final double availableHeight = screenHeight.clamp(0.0, double.infinity);
    final int sideCount = adShapeMode == 0 ? 1 : (adShapeMode == 1 ? 2 : 0);

    double sideAdWidth = safeW * 0.20;
    double videoWidth = (safeW - sideAdWidth * sideCount).clamp(0.0, safeW);
    double videoHeight = videoWidth * (9 / 16);
    double bottomAdHeight =
        (availableHeight - videoHeight).clamp(0.0, availableHeight);

    if (bottomAdHeight < availableHeight * 0.18) {
      bottomAdHeight = availableHeight * 0.18;
      videoHeight =
          (availableHeight - bottomAdHeight).clamp(0.0, availableHeight);
      videoWidth = (videoHeight * (16 / 9)).clamp(0.0, safeW);
      sideAdWidth = sideCount > 0
          ? ((safeW - videoWidth) / sideCount).clamp(0.0, safeW)
          : 0.0;
    }

    double videoLeft;
    if (adShapeMode == 0) {
      videoLeft = isLBandRight ? 0 : sideAdWidth;
    } else if (adShapeMode == 1) {
      videoLeft = sideAdWidth;
    } else {
      videoLeft = ((safeW - videoWidth) / 2).clamp(0.0, safeW);
    }

    if (isNewsBulletinMode ||
        isNetworkVideoMode ||
        isAdCurrentlyShowing ||
        isYoutubeMode) {
      Widget mainPlayer;

      if (Platform.isWindows && isYoutubeMode && _windowsYoutubeVideoId != null) {
        mainPlayer = InAppWebView(
          key: ValueKey(_windowsYoutubeVideoId),
          initialUrlRequest: URLRequest(
            url: WebUri(
              'https://www.youtube.com/watch?v=$_windowsYoutubeVideoId',
            ),
          ),
          initialSettings: InAppWebViewSettings(
            mediaPlaybackRequiresUserGesture: false,
            javaScriptEnabled: true,
            allowsInlineMediaPlayback: true,
          ),
          onWebViewCreated: (ctrl) {
            _winYtWebViewCtrl = ctrl;
          },
          onLoadStop: (ctrl, url) async {
            await ctrl.evaluateJavascript(source: r'''
              (function() {
                var css = `
                  html, body {
                    margin: 0 !important;
                    padding: 0 !important;
                    overflow: hidden !important;
                    background: #000 !important;
                  }
                  ytd-masthead, #masthead-container, #secondary, #below,
                  #related, #comments, #guide, tp-yt-app-drawer,
                  ytd-mini-guide-renderer {
                    display: none !important;
                  }
                  #movie_player {
                    position: fixed !important;
                    top: 0 !important;
                    left: 0 !important;
                    width: 100vw !important;
                    height: 100vh !important;
                    z-index: 999999 !important;
                    background: #000 !important;
                  }
                  .html5-video-container, video.html5-main-video {
                    width: 100vw !important;
                    height: 100vh !important;
                    top: 0 !important;
                    left: 0 !important;
                    object-fit: cover !important;
                  }
                  .ytp-chrome-top, .ytp-gradient-top,
                  .ytp-chrome-bottom, .ytp-gradient-bottom,
                  .ytp-progress-bar-container, .ytp-watermark,
                  .ytp-paid-content-overlay, .ytp-ce-element,
                  .ytp-bezel {
                    display: none !important;
                    opacity: 0 !important;
                  }
                `;
                var style = document.getElementById('kingjvr-clean-style');
                if (!style) {
                  style = document.createElement('style');
                  style.id = 'kingjvr-clean-style';
                  document.head.appendChild(style);
                }
                style.innerHTML = css;
                setTimeout(function() {
                  window.dispatchEvent(new Event('resize'));
                  var v = document.querySelector('video');
                  if (v && v.paused) { v.play().catch(function(){}); }
                }, 1000);
              })();
            ''');
          },
        );
      } else if (isYoutubeMode && _ytController != null) {
        mainPlayer = YoutubePlayer(
          controller: _ytController!,
          showVideoProgressIndicator: false,
        );
      } else if (isNewsBulletinMode && _vlcBulletinCtrl != null) {
        mainPlayer = SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 1920,
              height: 1080,
              child: VlcPlayer(
                controller: _vlcBulletinCtrl!,
                aspectRatio: 16 / 9,
                placeholder: const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                ),
              ),
            ),
          ),
        );
      } else if (isNewsBulletinMode &&
          _bulletinVideoController != null &&
          _bulletinVideoController!.value.isInitialized) {
        mainPlayer = SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _bulletinVideoController!.value.size.width,
              height: _bulletinVideoController!.value.size.height,
              child: VideoPlayer(_bulletinVideoController!),
            ),
          ),
        );
      } else {
        mainPlayer = actualCameraWidget;
      }

      return Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              left: isAdCurrentlyShowing ? videoLeft : 0,
              top: 0,
              width: isAdCurrentlyShowing ? videoWidth : safeW,
              height: isAdCurrentlyShowing ? videoHeight : availableHeight,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF800000),
                      width: 3.0,
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: mainPlayer,
                  ),
                ),
              ),
            ),

            // ఎడమ యాడ్ (L-Band లో isLBandRight ప్రకారం కుడి/ఎడమ, U-Band లో ఎడమ)
            if (isAdCurrentlyShowing && sideCount >= 1)
              Positioned(
                left: adShapeMode == 0
                    ? (isLBandRight ? videoWidth : 0)
                    : 0,
                top: 0,
                width: sideAdWidth,
                height: availableHeight,
                child: _buildAdSlot('left', "LEFT ADS", leftAdPaths,
                    leftAdIndex, _leftAdVideoCtrl),
              ),

            // కుడి యాడ్ (U-Band లో మాత్రమే)
            if (isAdCurrentlyShowing && sideCount == 2)
              Positioned(
                left: sideAdWidth + videoWidth,
                top: 0,
                width: sideAdWidth,
                height: availableHeight,
                child: _buildAdSlot('right', "RIGHT ADS", rightAdPaths,
                    rightAdIndex, _rightAdVideoCtrl),
              ),

            // కింద యాడ్
            if (isAdCurrentlyShowing)
              Positioned(
                left: videoLeft,
                top: videoHeight,
                width: videoWidth,
                height: bottomAdHeight,
                child: _buildAdSlot('bottom', "BOTTOM ADS", bottomAdPaths,
                    bottomAdIndex, _bottomAdVideoCtrlForAds),
              ),
          ],
        ),
      );
    }

    if (isYoutubeLoading) {
      return Stack(
        children: [
          Positioned.fill(child: actualCameraWidget),
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),
          ),
        ],
      );
    }

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF800000), width: 3.0),
        ),
        child: actualCameraWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isScreenLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    double camW = 1080;
    double camH = 1920;

    if (_isCameraInitialized &&
        controller != null &&
        controller!.value.isInitialized) {
      final previewSize = controller!.value.previewSize;

      if (previewSize != null) {
        camW = previewSize.width;
        camH = previewSize.height;

        if (camW < camH) {
          final double temp = camW;
          camW = camH;
          camH = temp;
        }
      }
    }

    final double finalCamW = isScreenLandscape ? camW : camH;
    final double finalCamH = isScreenLandscape ? camH : camW;

    final Widget phoneCameraWidget = (!isCameraVisible || Platform.isWindows)
        ? Container(color: Colors.transparent)
        : (_isCameraInitialized &&
                controller != null &&
                controller!.value.isInitialized)
            ? GestureDetector(
                onScaleStart: (details) {
                  _baseScale = _currentZoomLevel;
                },
                onScaleUpdate: (details) async {
                  if (controller == null || !controller!.value.isInitialized) {
                    return;
                  }

                  double zoom = _baseScale * details.scale;
                  if (zoom < _minZoomLevel) zoom = _minZoomLevel;
                  if (zoom > _maxZoomLevel) zoom = _maxZoomLevel;

                  setState(() {
                    _currentZoomLevel = zoom;
                  });

                  try {
                    await controller?.setZoomLevel(zoom);
                  } catch (e) {
                    debugPrint("Zoom error: $e");
                  }
                },
                child: ClipRect(
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: finalCamW,
                        height: finalCamH,
                        child: CameraPreview(controller!),
                      ),
                    ),
                  ),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              );

    final Widget reporterBadgeWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (watermarkText.isNotEmpty)
          Text(
            watermarkText,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 11.0,
            ),
          ),
        Container(
          color: Colors.red.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            locationText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11.0,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            reporterName,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 12.0,
            ),
          ),
        ),
        Container(
          color: Colors.red.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            reporterRole,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11.0,
            ),
          ),
        ),
      ],
    );

    final Widget visualScreenLogoWidget = GestureDetector(
      onTap: () {
        setState(() {
          logoPosition = (logoPosition + 1) % 4;
        });
      },
      child: channelLogoPath.isNotEmpty
          ? SizedBox(
              width: logoWidth,
              height: logoHeight,
              child: channelLogoPath.toLowerCase().endsWith('.mp4')
                  ? (_logoVideoCtrl != null &&
                          _logoVideoCtrl!.value.isInitialized
                      ? VideoPlayer(_logoVideoCtrl!)
                      : const SizedBox())
                  : Image.file(
                      File(channelLogoPath),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[900]?.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "SS YATRA TV",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF800000), width: 4.0),
          image: studioBgImagePath.isNotEmpty &&
                  File(studioBgImagePath).existsSync()
              ? DecorationImage(
                  image: FileImage(File(studioBgImagePath)),
                  fit: BoxFit.cover,
                )
              : null,
          gradient: studioBgImagePath.isEmpty
              ? const LinearGradient(
                  colors: [
                    Color(0xFF000428),
                    Color(0xFF900000),
                    Color(0xFF004e92),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        padding: const EdgeInsets.all(2.0),
        child: SafeArea(
          top: false,
          bottom: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!isLiveLocked) {
                setState(() {
                  isMenuOpen ? isMenuOpen = false : hideControls = !hideControls;
                });
              }
            },
            onLongPress: () {
              if (isLiveLocked) {
                setState(() {
                  isLiveLocked = false;
                  hideControls = false;
                });

                showCustomToast(
                  context,
                  "స్క్రీన్ అన్‌లాక్ చేయబడింది.",
                  isLive: isLiveBroadcasting,
                );
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double screenW = constraints.maxWidth;
                final double screenH = constraints.maxHeight;
                const double tickerH = 55.0;
                final double topAreaH =
                    (screenH - tickerH).clamp(0.0, double.infinity);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: topAreaH,
                      child: _buildMainDisplay(
                        isScreenLandscape,
                        screenW,
                        topAreaH,
                        phoneCameraWidget,
                      ),
                    ),
                    Positioned(
                      top: (logoPosition == 0 || logoPosition == 1) ? 5.0 : null,
                      bottom:
                          (logoPosition == 2 || logoPosition == 3) ? 75.0 : null,
                      left:
                          (logoPosition == 0 || logoPosition == 3) ? 10.0 : null,
                      right:
                          (logoPosition == 1 || logoPosition == 2) ? 10.0 : null,
                      child: visualScreenLogoWidget,
                    ),
                    Positioned.fill(
                      child: ScrollingWatermarkOverlay(controller: _wmController),
                    ),
                    if (!isDualScreenMode && showReporterDetails)
                      Positioned(
                        bottom: 65,
                        left: 15,
                        child: reporterBadgeWidget,
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: tickerH,
                      child: Container(
                        height: tickerH,
                        decoration: BoxDecoration(
                          color: bgColors[_tickerBgColorIndex % bgColors.length],
                          border: Border.all(
                            color: Colors.amber.shade400,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 120,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red.shade900,
                                    Colors.redAccent.shade700,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 6,
                                    offset: Offset(2, 0),
                                  ),
                                ],
                              ),
                              child: const Text(
                                "BREAKING\nNEWS",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 2,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                color: const Color(0xFF1A1A2E),
                                child: Marquee(
                                  key: ValueKey(breakingNewsText),
                                  text: breakingNewsText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  blankSpace: 100.0,
                                  velocity: 45.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!hideControls && !isLiveLocked)
                      Positioned(
                        bottom: 75,
                        right: 20,
                        child: Row(
                          children: [
                            if (isLiveBroadcasting) ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                onPressed: _stopLiveStream,
                                icon: const Icon(Icons.stop, color: Colors.white),
                                label: const Text(
                                  "STOP",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                onPressed: _togglePauseLive,
                                icon: Icon(
                                  isLivePaused ? Icons.play_arrow : Icons.pause,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  isLivePaused ? "RESUME" : "PAUSE",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ] else ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                onPressed: _showLiveControlDialog,
                                icon:
                                    const Icon(Icons.sensors, color: Colors.white),
                                label: const Text(
                                  "GO LIVE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 10),
                            FloatingActionButton(
                              backgroundColor: Colors.blue.shade800,
                              onPressed: () {
                                setState(() {
                                  isMenuOpen = !isMenuOpen;
                                });
                              },
                              child: Icon(
                                isMenuOpen ? Icons.close : Icons.menu,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!hideControls && isMenuOpen && !isLiveLocked)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black87,
                          child: Center(
                            child: SingleChildScrollView(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 30,
                                runSpacing: 35,
                                children: [
                                  _buildControlButton(
                                    Icons.newspaper_rounded,
                                    "Auto News",
                                    () {
                                      setState(() => isMenuOpen = false);
                                      _showAutoNewsDialog(context);
                                    },
                                    Colors.greenAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.dashboard_customize,
                                    "PCR Board",
                                    () {
                                      setState(() => isMenuOpen = false);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const MasterPCRBoard(),
                                        ),
                                      );
                                    },
                                    Colors.yellowAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.newspaper,
                                    "News Desk",
                                    () {
                                      setState(() => isMenuOpen = false);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const NewsDeskScreen(),
                                        ),
                                      );
                                    },
                                    Colors.redAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.auto_awesome,
                                    "Pro Editor",
                                    () {
                                      setState(() => isMenuOpen = false);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const EditorToolScreen(),
                                        ),
                                      );
                                    },
                                    Colors.pinkAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.bar_chart,
                                    "Election Results",
                                    () {
                                      setState(() => isMenuOpen = false);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ElectionBoardScreen(),
                                        ),
                                      );
                                    },
                                    Colors.blueAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.flip_camera_android,
                                    "Phone Cam",
                                    _switchCamera,
                                    Colors.white,
                                  ),
                                  _buildControlButton(
                                    isCameraVisible
                                        ? Icons.videocam
                                        : Icons.videocam_off,
                                    isCameraVisible ? "Cam ON" : "Cam OFF",
                                    _toggleCameraVisibility,
                                    isCameraVisible
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.video_call,
                                    "Ext. Cams",
                                    _showExternalCamsDialog,
                                    Colors.cyanAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.grid_on,
                                    "Dual Screen",
                                    _toggleDualScreenAndPickMedia,
                                    Colors.orangeAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.visibility,
                                    adDisplayMode == 0
                                        ? "Ads OFF"
                                        : (adDisplayMode == 1
                                            ? "Ads ON"
                                            : "Auto Ads"),
                                    _toggleAdMode,
                                    Colors.redAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.dashboard,
                                    adShapeMode == 0
                                        ? "Shape: L-Band"
                                        : (adShapeMode == 1
                                            ? "Shape: U-Band"
                                            : "Shape: Bottom"),
                                    _toggleAdShapeMode,
                                    Colors.orangeAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.picture_in_picture_alt,
                                    "Logo Pos",
                                    _changeLogoPosition,
                                    Colors.lightGreenAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.swap_horiz,
                                    "L-Band L/R",
                                    _toggleLBandDirection,
                                    Colors.orange,
                                  ),
                                  _buildControlButton(
                                    isBulletinMuted
                                        ? Icons.volume_off
                                        : Icons.volume_up,
                                    isBulletinMuted ? "Muted" : "Sound",
                                    _toggleMute,
                                    isBulletinMuted
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.screen_rotation,
                                    "Rotate",
                                    _toggleRotation,
                                    Colors.purpleAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.settings,
                                    "Settings",
                                    _showEditDialog,
                                    Colors.blue,
                                  ),
                                  _buildControlButton(
                                    showReporterDetails
                                        ? Icons.badge
                                        : Icons.badge_outlined,
                                    showReporterDetails
                                        ? "Reporter ON"
                                        : "Reporter OFF",
                                    _toggleReporterDetails,
                                    showReporterDetails
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                  _buildControlButton(
                                    Icons.branding_watermark,
                                    "Watermark",
                                    () {
                                      setState(() => isMenuOpen = false);
                                      showWatermarkDialog(context, _wmController);
                                    },
                                    Colors.amber,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String label,
    VoidCallback onTap,
    Color iconColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade800,
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MASTER PCR BOARD SCREEN
// ============================================================================
class MasterPCRBoard extends StatefulWidget {
  const MasterPCRBoard({Key? key}) : super(key: key);

  @override
  State<MasterPCRBoard> createState() => _MasterPCRBoardState();
}

class _MasterPCRBoardState extends State<MasterPCRBoard> {
  CameraController? _phoneCamCtrl;
  List<CameraDescription> _cameras = [];

  bool isLiveBroadcasting = false;
  String mainCameraId = "REPORTER_CAM";
  List<String> hexCams = ["IP_1", "IP_2", "DRONE_1", "IP_3", "IP_4", "HDMI_1"];

  TextEditingController cableRtmpController = TextEditingController();
  TextEditingController restreamRtmpController = TextEditingController();
  TextEditingController satelliteSrtController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initPhoneCamera();
    _loadSavedLinks();
  }

  Future<void> _initPhoneCamera() async {
    if (Platform.isWindows) return;
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        final CameraDescription cam = _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );
        final ctrl =
            CameraController(cam, ResolutionPreset.high, enableAudio: false);
        _phoneCamCtrl = ctrl;
        await ctrl.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("PCR Phone Cam Error: $e");
    }
  }

  Future<void> _loadSavedLinks() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      cableRtmpController.text = prefs.getString('cableRtmp') ?? "";
      restreamRtmpController.text = prefs.getString('restreamRtmp') ?? "";
      satelliteSrtController.text = prefs.getString('satelliteSrt') ?? "";
    });
  }

  void _saveLinks() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cableRtmp', cableRtmpController.text.trim());
      prefs.setString('restreamRtmp', restreamRtmpController.text.trim());
      prefs.setString('satelliteSrt', satelliteSrtController.text.trim());
    });
  }

  void _showLiveControlDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Live Control Room (PCR)",
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: cableRtmpController,
                  style: const TextStyle(color: Colors.yellow),
                  decoration:
                      const InputDecoration(labelText: "Primary RTMP Link"),
                ),
                TextField(
                  controller: restreamRtmpController,
                  style: const TextStyle(color: Colors.yellow),
                  decoration:
                      const InputDecoration(labelText: "Secondary RTMP Link"),
                ),
                TextField(
                  controller: satelliteSrtController,
                  style: const TextStyle(color: Colors.yellow),
                  decoration:
                      const InputDecoration(labelText: "Satellite SRT Link"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                _saveLinks();
                Navigator.pop(dialogContext);
                _startLiveBroadcast();
              },
              child: const Text("START BROADCAST"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startLiveBroadcast() async {
    final String cableUrl = cableRtmpController.text.trim();
    final String restreamUrl = restreamRtmpController.text.trim();
    final String satUrl = satelliteSrtController.text.trim();

    if (cableUrl.isEmpty && restreamUrl.isEmpty && satUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("దయచేసి కనీసం ఒక లైవ్ లింక్ ఇవ్వండి.")),
      );
      return;
    }

    try {
      final bool success = await StreamServiceManager.startLiveStreamMulti(
              cableUrl, restreamUrl, satUrl)
          .timeout(const Duration(seconds: 60));
      if (!mounted) return;
      if (success) {
        setState(() => isLiveBroadcasting = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("లైవ్ స్ట్రీమింగ్ విజయవంతంగా ప్రారంభమైంది!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("లైవ్ ప్రారంభం కాలేదు.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ఎర్రర్: $e")),
      );
    }
  }

  Future<void> _stopLiveBroadcast() async {
    await StreamServiceManager.stopLiveStream();
    if (!mounted) return;
    setState(() => isLiveBroadcasting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("లైవ్ స్ట్రీమింగ్ ఆగిపోయింది.")),
    );
  }

  @override
  void dispose() {
    _phoneCamCtrl?.dispose();
    cableRtmpController.dispose();
    restreamRtmpController.dispose();
    satelliteSrtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Master PCR Board & Multi-Camera"),
        backgroundColor: Colors.grey.shade900,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          IconButton(
            icon: Icon(isLiveBroadcasting ? Icons.stop : Icons.sensors,
                color: isLiveBroadcasting ? Colors.red : Colors.greenAccent),
            onPressed:
                isLiveBroadcasting ? _stopLiveBroadcast : _showLiveControlDialog,
            tooltip: isLiveBroadcasting ? "Stop Live" : "Go Live",
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.redAccent, width: 2),
                color: Colors.black54,
              ),
              child: (_phoneCamCtrl != null && _phoneCamCtrl!.value.isInitialized)
                  ? CameraPreview(_phoneCamCtrl!)
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.amber)),
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "PCR Switcher Grid (Tap to Switch)",
                    style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 16 / 9,
                      ),
                      itemCount: hexCams.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              final String temp = mainCameraId;
                              mainCameraId = hexCams[index];
                              hexCams[index] = temp;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[850],
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: Colors.blueAccent, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                "Cam: ${hexCams[index]}",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

