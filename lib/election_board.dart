import 'package:flutter/material.dart';

class ElectionBoardScreen extends StatefulWidget {
  const ElectionBoardScreen({Key? key}) : super(key: key);

  @override
  State<ElectionBoardScreen> createState() => _ElectionBoardScreenState();
}

class _ElectionBoardScreenState extends State<ElectionBoardScreen> {
  // ఎలక్షన్ రకాలు
  final List<String> _electionTypes = [
    'పార్లమెంట్ ఎన్నికలు (MP)',
    'అసెంబ్లీ ఎన్నికలు (MLA)',
    'మున్సిపల్ / కార్పొరేషన్',
    'జడ్పీటీసీ (ZPTC)',
    'ఎంపీటీసీ (MPTC)',
    'సర్పంచ్ / పంచాయతీ',
    'వార్డు మెంబర్',
    'బై-ఎలక్షన్ (ఉప ఎన్నిక)'
  ];
  String _selectedElection = 'అసెంబ్లీ ఎన్నికలు (MLA)';
  String _regionName = '';

  // పార్టీల డేటా (డిఫాల్ట్‌గా కొన్ని పార్టీలు, మీరు యాడ్ చేసుకోవచ్చు)
  List<Map<String, dynamic>> _partiesList = [
    {'name': 'CONG', 'leading': 0, 'won': 0, 'color': Colors.blue.shade700},
    {'name': 'BRS', 'leading': 0, 'won': 0, 'color': Colors.pink.shade600},
    {'name': 'BJP', 'leading': 0, 'won': 0, 'color': Colors.orange.shade700},
    {'name': 'TDP', 'leading': 0, 'won': 0, 'color': Colors.yellow.shade700},
    {'name': 'YSRCP', 'leading': 0, 'won': 0, 'color': Colors.green.shade800},
    {'name': 'OTHERS', 'leading': 0, 'won': 0, 'color': Colors.grey.shade600},
  ];

  // లైవ్‌కి పంపే లాజిక్
  void _sendToLivePCR() {
    // భవిష్యత్తులో ఈ డేటాని main.dart లోని టిక్కర్‌కి పంపే లాజిక్ ఇక్కడ రాస్తాం
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ఎలక్షన్ రిజల్ట్స్ లైవ్ టిక్కర్‌కి విజయవంతంగా పంపబడ్డాయి! 🔴 LIVE', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
      ),
    );
  }

  // పార్టీ స్కోర్ పెంచడం / తగ్గించడం
  void _updateScore(int index, String type, int change) {
    setState(() {
      _partiesList[index][type] += change;
      if (_partiesList[index][type] < 0) _partiesList[index][type] = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Dark studio theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3460),
        title: const Text("PCR ELECTION BOARD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ఎలక్షన్ సెటప్ సెక్షన్
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedElection,
                      dropdownColor: Colors.grey.shade900,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'ఎలక్షన్ రకం',
                        labelStyle: TextStyle(color: Colors.amber),
                        border: OutlineInputBorder(),
                      ),
                      items: _electionTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (val) => setState(() => _selectedElection = val!),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'ప్రాంతం / నియోజకవర్గం పేరు',
                        labelStyle: TextStyle(color: Colors.amber),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => _regionName = val,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            const Text("పార్టీల వారీగా ఫలితాలు (Manual Entry)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white24),
            
            // 2. పార్టీల రిజల్ట్స్ ఎంట్రీ సెక్షన్
            Expanded(
              child: ListView.builder(
                itemCount: _partiesList.length,
                itemBuilder: (context, index) {
                  final party = _partiesList[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: party['color'].withOpacity(0.2),
                      border: Border.all(color: party['color'], width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // పార్టీ పేరు
                        Container(
                          width: 80,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: party['color'], borderRadius: BorderRadius.circular(5)),
                          child: Text(party['name'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        
                        // లీడింగ్ కంట్రోల్స్
                        Column(
                          children: [
                            const Text("LEADING (లీడింగ్)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Row(
                              children: [
                                IconButton(icon: const Icon(Icons.remove_circle, color: Colors.redAccent), onPressed: () => _updateScore(index, 'leading', -1)),
                                Text("${party['leading']}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: () => _updateScore(index, 'leading', 1)),
                              ],
                            )
                          ],
                        ),

                        // గెలిచినవి (WON) కంట్రోల్స్
                        Column(
                          children: [
                            const Text("WON (గెలుపు)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Row(
                              children: [
                                IconButton(icon: const Icon(Icons.remove_circle, color: Colors.redAccent), onPressed: () => _updateScore(index, 'won', -1)),
                                Text("${party['won']}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: () => _updateScore(index, 'won', 1)),
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 3. లైవ్ కి పంపే బటన్
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                onPressed: _sendToLivePCR,
                icon: const Icon(Icons.live_tv, color: Colors.white),
                label: const Text("SEND TO LIVE (లైవ్ స్క్రీన్‌కి పంపు)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
