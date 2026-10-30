// Copyright (c) 2026 Vinod Kumar Jannampally. All commercial and software rights reserved.
// Package: com.kingjvk.pocket_pcr

import 'package:flutter/material.dart';
import '../../models/news_item.dart';
import '../../database/news_database_helper.dart';
import 'ai_script_service.dart';

class AiScriptWriterScreen extends StatefulWidget {
  final NewsItem newsItem;

  const AiScriptWriterScreen({Key? key, required this.newsItem}) : super(key: key);

  @override
  _AiScriptWriterScreenState createState() => _AiScriptWriterScreenState();
}

class _AiScriptWriterScreenState extends State<AiScriptWriterScreen> {
  final NewsDatabaseHelper _dbHelper = NewsDatabaseHelper();
  TextEditingController _scriptController = TextEditingController();
  
  String _selectedFormat = 'Anchor Introduction';
  bool _isGenerating = false;

  final List<String> _formats = [
    'Anchor Introduction',
    'Detailed News Report',
    'Short News',
    'Breaking News Script',
    'Special Report'
  ];

  @override
  void initState() {
    super.initState();
    _scriptController.text = widget.newsItem.content;
  }

  Future<void> _generateScript() async {
    setState(() => _isGenerating = true);
    
    String generatedText = await AiScriptService.generateTeluguScript(
      widget.newsItem.title, 
      widget.newsItem.content, 
      _selectedFormat
    );

    setState(() {
      _scriptController.text = generatedText;
      _isGenerating = false;
    });
  }

  Future<void> _saveScriptAndApprove() async {
    widget.newsItem.content = _scriptController.text;
    widget.newsItem.status = 'Ready for Production'; // స్క్రిప్ట్ పూర్తయ్యాక ప్రొడక్షన్‌కి పంపుతాం
    
    await _dbHelper.insertNewsItem(widget.newsItem); // Update చేస్తుంది
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('స్క్రిప్ట్ విజయవంతంగా సేవ్ అయ్యింది!'), backgroundColor: Colors.green),
    );
    Navigator.pop(context, true); // వెనక్కి వెళ్తుంది
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Script Writer'),
        backgroundColor: Colors.purple[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.newsItem.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const Divider(),
            Row(
              children: [
                const Text("ఫార్మాట్: ", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _selectedFormat,
                  items: _formats.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedFormat = newValue!;
                    });
                  },
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateScript,
                  icon: _isGenerating 
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.auto_awesome, color: Colors.white),
                  label: const Text("AI తో రాయించు", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                )
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: _scriptController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: "ఇక్కడ స్క్రిప్ట్ వస్తుంది... మీరు దీన్ని ఎడిట్ కూడా చేసుకోవచ్చు.",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveScriptAndApprove,
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text("SAVE & APPROVE FOR PRODUCTION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
              ),
            )
          ],
        ),
      ),
    );
  }
}
