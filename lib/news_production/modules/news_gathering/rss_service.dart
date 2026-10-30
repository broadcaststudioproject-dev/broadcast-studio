// Copyright (c) 2026 Vinod Kumar Jannampally. All commercial and software rights reserved.
// Package: com.kingjvk.pocket_pcr

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../../models/news_item.dart';
import '../../database/news_database_helper.dart';

class RssService {
  final NewsDatabaseHelper _db = NewsDatabaseHelper();

  // వివిధ వార్తా వర్గాల RSS ఫీడ్ లింక్స్ (తెలుగులో)
  final List<String> rssFeeds = [
    'https://news.google.com/rss?hl=te&gl=IN&ceid=IN:te', // తాజా జాతీయ/అంతర్జాతీయ వార్తలు
    'https://news.google.com/rss/search?q=telangana&hl=te&gl=IN&ceid=IN:te', // తెలంగాణ వార్తలు
    'https://news.google.com/rss/search?q=andhra+pradesh&hl=te&gl=IN&ceid=IN:te', // ఆంధ్రప్రదేశ్ వార్తలు
  ];

  // ఇంటర్నెట్ నుండి వార్తలను లాగి డేటాబేస్‌లో సేవ్ చేసే ఫంక్షన్
  Future<int> fetchAndSaveNews() async {
    int addedCount = 0;
    final existingNews = await _db.getNewsItems();
    
    // పాత వార్తలు మళ్లీ రాకుండా అడ్డుకోవడానికి టైటిల్స్ మాత్రమే ఒక లిస్ట్‌లో ఉంచుతున్నాం
    final existingTitles = existingNews.map((e) => e.title).toSet();

    for (String url in rssFeeds) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final document = XmlDocument.parse(response.body);
          final items = document.findAllElements('item');

          for (var item in items) {
            final title = item.findElements('title').isNotEmpty ? item.findElements('title').first.innerText : '';
            final link = item.findElements('link').isNotEmpty ? item.findElements('link').first.innerText : '';
            final pubDate = item.findElements('pubDate').isNotEmpty ? item.findElements('pubDate').first.innerText : DateTime.now().toString();

            // టైటిల్‌లో ఉన్న అనవసరమైన టెక్స్ట్ తీసేయడం
            String cleanTitle = title.replaceAll(RegExp(r'^[0-9]+[smh]\sTrend:\s', caseSensitive: false), '');

            // ఈ వార్త ఇప్పటికే మన డెస్క్‌లో లేకపోతేనే సేవ్ చేయాలి
            if (cleanTitle.isNotEmpty && !existingTitles.contains(cleanTitle)) {
              final newsItem = NewsItem(
                title: cleanTitle,
                content: "మూలం: $link\n\nవివరాలు: (తర్వాతి దశలో AI ద్వారా స్క్రిప్ట్ రాయబడుతుంది)",
                source: "SS Yatra RSS",
                category: _determineCategory(cleanTitle),
                status: "New", // కొత్తగా వచ్చిన వార్త
                date: pubDate,
                mediaUrl: link,
              );
              
              await _db.insertNewsItem(newsItem);
              existingTitles.add(cleanTitle);
              addedCount++;
            }
          }
        }
      } catch (e) {
        // నెట్‌వర్క్ ఎర్రర్ వస్తే స్కిప్ చేయబడుతుంది
      }
    }
    return addedCount; // కొత్తగా ఎన్ని వార్తలు యాడ్ అయ్యాయో రిటర్న్ చేస్తుంది
  }

  // వార్త శీర్షికను బట్టి ఆటోమేటిక్‌గా వర్గాన్ని (Category) నిర్ణయించే AI లాజిక్
  String _determineCategory(String title) {
    if (title.contains("తెలంగాణ") || title.contains("హైదరాబాద్") || title.contains("కేసీఆర్") || title.contains("రేవంత్")) {
      return "Telangana News";
    }
    if (title.contains("ఆంధ్ర") || title.contains("ఏపీ") || title.contains("చంద్రబాబు") || title.contains("జగన్") || title.contains("పవన్")) {
      return "Andhra Pradesh News";
    }
    if (title.contains("క్రైమ్") || title.contains("హత్య") || title.contains("అరెస్ట్") || title.contains("దొంగతనం") || title.contains("పోలీసు")) {
      return "Crime News";
    }
    if (title.contains("క్రికెట్") || title.contains("ఐపీఎల్") || title.contains("క్రీడలు") || title.contains("మ్యాచ్")) {
      return "Sports News";
    }
    return "National / Politics";
  }
}
