// Copyright (c) 2026 Vinod Kumar Jannampally. All commercial and software rights reserved.
// Package: com.kingjvk.pocket_pcr

import 'dart:convert';
import 'package:http/http.dart' as http;

class VirtualAnchorService {
  // గమనిక: మీ D-ID లేదా Vidnoz API Key ఇక్కడ సెట్ చేయండి.
  static const String _apiKey = 'ఇక్కడ_మీ_D-ID_లేదా_VIDNOZ_API_KEY_పెట్టండి';

  // AI అవతార్ కోసం ఇమేజ్ URL లు (మీ ఛానల్ యాంకర్ల ఫోటోలు ఇక్కడ మార్చుకోవచ్చు)
  static const String maleAvatarUrl = "https://raw.githubusercontent.com/kingjvk/assets/main/male_anchor.jpg";
  static const String femaleAvatarUrl = "https://raw.githubusercontent.com/kingjvk/assets/main/female_anchor.jpg";

  static Future<String?> generateAnchorVideo(String script, String gender) async {
    // API కీ పెట్టనంత వరకు, టెస్టింగ్ కోసం ఒక డెమో వీడియో లింక్ ఇస్తుంది.
    if (_apiKey.isEmpty || _apiKey == 'ఇక్కడ_మీ_D-ID_లేదా_VIDNOZ_API_KEY_పెట్టండి') {
      await Future.delayed(const Duration(seconds: 4)); // వీడియో తయారవుతున్న ఫీలింగ్ కోసం
      return "https://www.w3schools.com/html/mov_bbb.mp4"; // డెమో MP4 వీడియో URL
    }

    try {
      // ఇక్కడ D-ID Talks API కాలింగ్ జరుగుతుంది
      final String sourceUrl = (gender == 'Male') ? maleAvatarUrl : femaleAvatarUrl;
      final String voiceId = (gender == 'Male') ? 'te-IN-MohanNeural' : 'te-IN-ShrutiNeural'; // తెలుగు వాయిస్

      final response = await http.post(
        Uri.parse('https://api.d-id.com/talks'),
        headers: {
          'Authorization': 'Basic $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "source_url": sourceUrl,
          "script": {
            "type": "text",
            "subtitles": "false",
            "provider": {
              "type": "microsoft",
              "voice_id": voiceId
            },
            "input": script
          },
          "config": {
            "fluent": "false",
            "pad_audio": "0.0"
          }
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final String id = data['id'];
        
        // వీడియో జనరేట్ అవ్వడానికి సమయం పడుతుంది కాబట్టి కొద్దిసేపు ఆగి రిజల్ట్ అడగాలి
        await Future.delayed(const Duration(seconds: 15));
        
        final resultResponse = await http.get(
          Uri.parse('https://api.d-id.com/talks/$id'),
          headers: {'Authorization': 'Basic $_apiKey'},
        );

        if (resultResponse.statusCode == 200) {
          final resultData = jsonDecode(resultResponse.body);
          if (resultData['result_url'] != null) {
            return resultData['result_url']; // జనరేట్ అయిన వీడియో MP4 లింక్
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
