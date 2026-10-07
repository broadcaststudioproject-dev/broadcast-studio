import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:async';

class ElectionBoardScreen extends StatefulWidget {
  const ElectionBoardScreen({Key? key}) : super(key: key);

  @override
  State<ElectionBoardScreen> createState() => _ElectionBoardScreenState();
}

class _ElectionBoardScreenState extends State<ElectionBoardScreen> {
  String breakingNewsText = "ఎలక్షన్ అప్‌డేట్స్: స్థానిక సంస్థలు, మున్సిపల్ మరియు అసెంబ్లీ ఎన్నికల తాజా ఫలితాలు లోడ్ అవుతున్నాయి...";
  Timer? _newsTimer;

  // Mock Election Data (You can update this dynamically later via API)
  final String electionTitle = "INDIA ELECTIONS 2026 - LIVE RESULTS & TRENDS";
  final List<Map<String, dynamic>> electionResults = [
    {"party": "INC", "seats": "64", "trend": "LEAD (+15)", "color": Colors.orange},
    {"party": "BRS", "seats": "39", "trend": "TRAIL (-24)", "color": Colors.pink},
    {"party": "BJP", "seats": "8", "trend": "LEAD (+7)", "color": Colors.deepOrange},
    {"party": "AIMIM", "seats": "7", "trend": "HOLD (0)", "color": Colors.green},
    {"party": "OTH", "seats": "1", "trend": "LEAD (+2)", "color": Colors.blueGrey},
  ];

  @override
  void initState() {
    super.initState();
    _fetchElectionFeed();
    _newsTimer = Timer.periodic(const Duration(minutes: 5), (timer) => _fetchElectionFeed());
  }

  Future<void> _fetchElectionFeed() async {
    try {
      final response = await http.get(Uri.parse('https://news.google.com/rss/search?q=election+results+india&hl=te&gl=IN&ceid=IN:te'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        List<String> titles = items.take(15).map((e) => e.findElements('title').first.innerText).toList();
        if (titles.isNotEmpty && mounted) {
          setState(() {
            breakingNewsText = "🗳️ BREAKING ELECTION UPDATES: " + titles.join("   ♦   ");
          });
        }
      }
    } catch (e) {
      debugPrint("Election Feed Error: $e");
    }
  }

  @override
  void dispose() {
    _newsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900, // Studio background color
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("ELECTION RESULTS HUB", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // --- 1. ELECTION SCOREBOARD HEADER ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            color: Colors.red.shade900,
            child: Column(
              children: [
                Text(
                  electionTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white54, thickness: 1),
              ],
            ),
          ),

          // --- 2. PARTY RESULTS GRID ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.builder(
                itemCount: electionResults.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 columns
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 2.5,
                ),
                itemBuilder: (context, index) {
                  var res = electionResults[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: res['color'],
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(2, 2))],
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(res['party'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                              Text(res['seats'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              res['trend'], 
                              style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // --- 3. BOTTOM GOOGLE NEWS / ELECTION RSS TICKER ---
          Container(
            height: 45,
            color: Colors.blue[900],
            child: Row(
              children: [
                Container(
                  color: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  alignment: Alignment.center,
                  child: const Text(
                    "ELECTION ALERTS",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                  ),
                ),
                Expanded(
                  child: Marquee(
                    text: breakingNewsText,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    blankSpace: 100.0,
                    velocity: 50.0,
                    startPadding: 10.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
