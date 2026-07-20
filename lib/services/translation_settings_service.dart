import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TranslationProvider {
  claude('Claude'),
  google('Google');

  const TranslationProvider(this.label);

  final String label;
}

/// Which translation backend the user picked in Settings.
class TranslationSettingsService extends ChangeNotifier {
  static const _providerKey = 'translation_provider';

  TranslationProvider provider = TranslationProvider.claude;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_providerKey);
    provider = TranslationProvider.values.firstWhere(
      (p) => p.name == stored,
      orElse: () => TranslationProvider.claude,
    );
    notifyListeners();
  }

  Future<void> setProvider(TranslationProvider newProvider) async {
    provider = newProvider;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, newProvider.name);
  }
}
