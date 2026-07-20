import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/watch_screen.dart';
import 'services/claude_translation_service.dart';
import 'services/glasses_service.dart';
import 'services/google_translation_service.dart';
import 'services/session_history_service.dart';
import 'services/translation_settings_service.dart';

void main() {
  runApp(const FinnishSubtitlesApp());
}

class FinnishSubtitlesApp extends StatelessWidget {
  const FinnishSubtitlesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GlassesService()..init()),
        ChangeNotifierProvider(create: (_) => SessionHistoryService()..init()),
        ChangeNotifierProvider(
          create: (_) => TranslationSettingsService()..init(),
        ),
        Provider(create: (_) => ClaudeTranslationService()),
        Provider(create: (_) => GoogleTranslationService()),
      ],
      child: MaterialApp(
        title: 'Finnish Subtitles',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
        home: const WatchScreen(),
      ),
    );
  }
}
