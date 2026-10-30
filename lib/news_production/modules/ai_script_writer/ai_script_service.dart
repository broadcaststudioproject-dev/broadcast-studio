// Copyright (c) 2026 Vinod Kumar Jannampally. All commercial and software rights reserved.
// Package: com.kingjvk.pocket_pcr

import 'package:google_generative_ai/google_generative_ai.dart';

class AiScriptService {
  // గమనిక: ఇక్కడ మీ నిజమైన Gemini API Key ని పెట్టాలి.
  static const String _apiKey = 'ఇక్కడ_మీ_GEMINI_API_KEY_పెట్టండి'; 

  static Future<String> generateTeluguScript(String title, String content, String format) async {
    if (_apiKey == 'ఇక్కడ_మీ_GEMINI_API_KEY_పెట్టండి' || _apiKey.isEmpty) {
      return "దయచేసి ai_script_service.dart ఫైల్‌లో మీ Gemini API Key ని సెట్ చేయండి.";
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      String prompt = '''
        మీరు 'SS YATRA TV' అనే ప్రముఖ తెలుగు న్యూస్ ఛానల్ కోసం పనిచేస్తున్న ఒక ప్రొఫెషనల్ న్యూస్ స్క్రిప్ట్ రైటర్.
        
        కింద ఇచ్చిన వార్తా సమాచారం ఆధారంగా "$format" ఫార్మాట్‌లో ఒక స్పష్టమైన, అక్షర దోషాలు లేని తెలుగు న్యూస్ స్క్రిప్ట్ రాయండి.
        
        నియమాలు:
        1. మూలంలో లేని విషయాలను సొంతంగా కల్పించవద్దు. ఆరోపణలను వాస్తవాలుగా రాయకూడదు.
        2. వార్త చదివే యాంకర్‌కు అనుకూలంగా, ఆకర్షణీయమైన వాక్య నిర్మాణం ఉండాలి.
        3. బులెటిన్/వార్త ప్రారంభంలో "ఎస్ఎస్ యాత్ర టీవీ ప్రేక్షకులకు నమస్కారం" అని ఉండేలా చూడండి (అవసరమైన ఫార్మాట్లకు).
        4. కేవలం స్క్రిప్ట్ మాత్రమే ఇవ్వండి, ఎలాంటి ఇతర వివరణలు వద్దు.
        
        వార్త శీర్షిక: $title
        సమాచారం: $content
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "స్క్రిప్ట్ జనరేట్ కాలేదు. మళ్లీ ప్రయత్నించండి.";
    } catch (e) {
      return "AI ఎర్రర్: $e";
    }
  }
}
