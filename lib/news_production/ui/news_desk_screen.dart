// Copyright (c) 2026 Vinod Kumar Jannampally. All commercial and software rights reserved.
// Package: com.kingjvk.pocket_pcr

import 'package:flutter/material.dart';
import '../models/news_item.dart';
import '../database/news_database_helper.dart';
import '../modules/news_gathering/rss_service.dart';
import '../modules/ai_script_writer/ai_script_writer_screen.dart';
import '../modules/virtual_anchor/virtual_anchor_screen.dart';

class NewsDeskScreen extends StatefulWidget {
  const NewsDeskScreen({Key? key}) : super(key: key);

  @override
  _NewsDeskScreenState createState() => _NewsDeskScreenState();
}

class _NewsDeskScreenState extends State<NewsDeskScreen> {
  final NewsDatabaseHelper _dbHelper = NewsDatabaseHelper();
  List<NewsItem> _newsList = [];
  bool _isLoading = true;
  bool _isFetchingNews = false;

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

  // ఆటోమేటిక్‌గా ఇంటర్నెట్ నుండి తాజా వార్తలను లాగడం
  Future<void> _fetchAutoNews() async {
    setState(() => _isFetchingNews = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('వార్తలను సేకరిస్తోంది... దయచేసి వేచి ఉండండి.'), duration: Duration(seconds: 2)),
    );

    final service = RssService();
    int newCount = await service.fetchAndSaveNews();

    setState(() => _isFetchingNews = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newCount > 0 ? '$newCount కొత్త వార్తలు సేకరించబడ్డాయి!' : 'కొత్త వార్తలు ఏమీ లేవు.'),
        backgroundColor: newCount > 0 ? Colors.green : Colors.orange,
      ),
    );

    _loadNews(); // జాబితాను అప్‌డేట్ చేయడం
  }

  // వార్త స్థితిని మార్చే డైలాగ్ (Verification Process)
  Future<void> _showStatusDialog(NewsItem item) async {
    String? newStatus = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('వార్తను నిర్ధారించండి (Verify)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
      _loadNews();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SS YATRA TV - News Desk'),
        backgroundColor: Colors.red[800],
        actions: [
          IconButton(
            icon: _isFetchingNews 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync),
            tooltip: 'తాజా వార్తలను సేకరించండి',
            onPressed: _isFetchingNews ? null : _fetchAutoNews,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _newsList.isEmpty
              ? const Center(child: Text('ప్రస్తుతం డెస్క్‌లో ఎలాంటి వార్తలు లేవు.'))
              : ListView.builder(
                  itemCount: _newsList.length,
                  itemBuilder: (context, index) {
                    final item = _newsList[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      elevation: 2,
                      child: ListTile(
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text('వర్గం: ${item.category}', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Chip(
                                  label: Text(
                                    item.status,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: _getStatusColor(item.status),
                                  padding: EdgeInsets.zero,
                                ),
                                const Spacer(),
                                
                                // ఎడిట్/వెరిఫై బటన్
                                IconButton(
                                  icon: const Icon(Icons.edit_document, color: Colors.blue, size: 20),
                                  onPressed: () => _showStatusDialog(item),
                                ),
                                
                                // వార్త 'Verified' అయితేనే AI స్క్రిప్ట్ బటన్ చూపిస్తుంది
                                if (item.status == 'Verified')
                                  IconButton(
                                    icon: const Icon(Icons.auto_awesome, color: Colors.purple, size: 24),
                                    tooltip: 'AI తో స్క్రిప్ట్ రాయించండి',
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => AiScriptWriterScreen(newsItem: item)),
                                      );
                                      if (result == true) {
                                        _loadNews(); // సేవ్ చేశాక జాబితా అప్‌డేట్ అవుతుంది
                                      }
                                    },
                                  ),

                                // వార్తకు స్క్రిప్ట్ రెడీ అయ్యాక 'వర్చువల్ యాంకర్' బటన్ చూపిస్తుంది
                                if (item.status == 'Ready for Production')
                                IconButton(
                                icon: const Icon(Icons.smart_display, color: Colors.indigo, size: 26),
                                tooltip: 'AI వర్చువల్ యాంకర్ వీడియో క్రియేట్ చేయండి',
                                onPressed: () async {
                                final result = await Navigator.push(
                                context,
                                 MaterialPageRoute(builder: (context) => VirtualAnchorScreen(newsItem: item)),
                                 );
                                 _loadNews(); // స్టేటస్ అప్‌డేట్ కోసం రీఫ్రెష్
                                 },
                                ),
                                // డిలీట్ బటన్
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () async {
                                    if (item.id != null) {
                                      await _dbHelper.deleteNewsItem(item.id!);
                                      _loadNews();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  // స్థితిని బట్టి రంగును సెట్ చేయడం
  Color _getStatusColor(String status) {
    switch (status) {
      case 'New': return Colors.orange;
      case 'Verified': return Colors.green;
      case 'Rejected': return Colors.red;
      case 'Ready for Production': return Colors.purple;
      default: return Colors.grey;
    }
  }
}
