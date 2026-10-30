// Copyright (c) 2026 Vinod Kumar Jannampally. All commercial and software rights reserved.
// Package: com.kingjvk.pocket_pcr

import 'package:flutter/material.dart';
import '../models/news_item.dart';
import '../database/news_database_helper.dart';

class NewsDeskScreen extends StatefulWidget {
  const NewsDeskScreen({Key? key}) : super(key: key);

  @override
  _NewsDeskScreenState createState() => _NewsDeskScreenState();
}

class _NewsDeskScreenState extends State<NewsDeskScreen> {
  final NewsDatabaseHelper _dbHelper = NewsDatabaseHelper();
  List<NewsItem> _newsList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  // డేటాబేస్ నుండి వార్తలను లోడ్ చేయడం
  Future<void> _loadNews() async {
    setState(() => _isLoading = true);
    final news = await _dbHelper.getNewsItems();
    setState(() {
      _newsList = news;
      _isLoading = false;
    });
  }

  // వార్త స్థితిని మార్చే డైలాగ్ (Verification Process)
  Future<void> _showStatusDialog(NewsItem item) async {
    String? newStatus = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('వార్తను నిర్ధారించండి (Verify)'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'Verified'),
              child: const Text('✅ Verified (నిర్ధారించబడింది)'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'Rejected'),
              child: const Text('❌ Rejected (తిరస్కరించబడింది)'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'Ready for Production'),
              child: const Text('📺 Ready for Production'),
            ),
          ],
        );
      },
    );

    if (newStatus != null && item.id != null) {
      await _dbHelper.updateNewsStatus(item.id!, newStatus);
      _loadNews(); // మార్పు తర్వాత జాబితాను అప్‌డేట్ చేయడం
    }
  }

  // టెస్టింగ్ కోసం ఒక డెమో వార్తను జోడించడం
  Future<void> _addDummyNews() async {
    final newItem = NewsItem(
      title: 'కొత్తకోటలో ఘనంగా సావిత్రిబాయి ఫూలే జయంతి వేడుకలు',
      content: 'సత్యశోధక్ సమాజ్ ఫౌండేషన్ ఆధ్వర్యంలో ఈ కార్యక్రమం జరిగింది.',
      source: 'SS Yatra TV Reporter',
      category: 'Telangana News',
      status: 'New',
      date: DateTime.now().toString(),
    );
    await _dbHelper.insertNewsItem(newItem);
    _loadNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SS YATRA TV - News Desk'),
        backgroundColor: Colors.red[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _newsList.isEmpty
              ? const Center(child: Text('ప్రస్తుతం ఎలాంటి వార్తలు లేవు.'))
              : ListView.builder(
                  itemCount: _newsList.length,
                  itemBuilder: (context, index) {
                    final item = _newsList[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      elevation: 3,
                      child: ListTile(
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text('వర్గం: ${item.category} | తేదీ: ${item.date.split(' ')[0]}'),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Text('స్థితి: '),
                                Chip(
                                  label: Text(
                                    item.status,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  backgroundColor: _getStatusColor(item.status),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_document, color: Colors.blue),
                          onPressed: () => _showStatusDialog(item),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDummyNews,
        backgroundColor: Colors.red[800],
        child: const Icon(Icons.add),
        tooltip: 'టెస్ట్ వార్తను జోడించండి',
      ),
    );
  }

  // స్థితిని బట్టి రంగును సెట్ చేయడం
  Color _getStatusColor(String status) {
    switch (status) {
      case 'New':
        return Colors.orange;
      case 'Verified':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Ready for Production':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
