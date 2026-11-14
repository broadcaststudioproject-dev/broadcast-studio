# మార్పుల వివరాలు (KINGJVR)

1. **టిక్కర్ రంగు టైమర్**: ప్రతి 2 సెకన్లకు మొత్తం స్క్రీన్ రీబిల్డ్ కాకుండా, టిక్కర్ బార్ మాత్రమే రీబిల్డ్ అవుతుంది (`ValueNotifier`).
2. **API కీలు**: Gemini, D-ID కీలు కోడ్‌లో లేవు. బిల్డ్ సమయంలో ఇవ్వాలి:
   `flutter build apk --release --dart-define=GEMINI_API_KEY=కీ --dart-define=DID_API_KEY=కీ`
   Gemini మోడల్ పేరు `--dart-define=GEMINI_MODEL=...` తో మార్చవచ్చు (డిఫాల్ట్: gemini-2.5-flash).
   GitHub Actions కోసం repo Settings → Secrets లో `GEMINI_API_KEY`, `DID_API_KEY` జోడించండి.
3. **APK సైనింగ్**: `android/key.properties` ఉంటే సొంత keystore తో సైన్ అవుతుంది (ఫార్మాట్ కింద). లేకపోతే పాత debug కీ.
   ```
   storePassword=...
   keyPassword=...
   keyAlias=...
   storeFile=/path/to/keystore.jks
   ```
4. **వెర్షన్**: Gradle ఇప్పుడు `pubspec.yaml` లోని version (1.0.0+4) ని వాడుతుంది.
5. **RSS డూప్లికేట్ చెక్**: మొత్తం వార్తలకు బదులు టైటిల్స్ మాత్రమే లోడ్ అవుతాయి.
6. **ఎర్రర్ లాగ్**: బ్రేకింగ్ న్యూస్, RSS ఫెచ్ విఫలమైతే కారణం లాగ్‌లో కనిపిస్తుంది.
7. **శుభ్రత**: phase/test ఫోల్డర్లు, బ్యాకప్‌లు, నకలు ఫైల్, స్ట్రే ఫైల్ `x` తొలగించాను (24MB → ~1MB). `.gitignore` నవీకరించాను.
