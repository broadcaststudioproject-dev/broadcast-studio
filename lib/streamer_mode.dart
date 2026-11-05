import 'package:flutter/material.dart';

class StreamerModeScreen extends StatelessWidget {
  const StreamerModeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket PCR Studio - Dual Architecture'),
        backgroundColor: const Color(0xFF800000),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ఆపరేటింగ్ మోడ్‌ను ఎంచుకోండి',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.blue[800],
              ),
              icon: const Icon(Icons.dashboard, size: 28),
              label: const Text(
                'మాస్టర్ కంట్రోల్ రూమ్ (Control Room)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                // ఇక్కడ మీ మెయిన్ స్టూడియో స్క్రీన్‌కి నావిగేట్ అవుతుంది
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.green[800],
              ),
              icon: const Icon(Icons.cast, size: 28),
              label: const Text(
                'స్ట్రీమింగ్ అవుట్‌పుట్ (Streamer Output)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                // ఇక్కడ స్ట్రీమింగ్ అవుట్‌పుట్ స్క్రీన్‌కి వెళ్తుంది
              },
            ),
          ],
        ),
      ),
    );
  }
}
