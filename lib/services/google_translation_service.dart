import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/subtitle_pair.dart';
import 'subtitle_translator.dart';

/// Sends captured frames to the project's own Cloud Function
/// (backend/google_function), which runs them through Vertex AI Gemini.
///
/// Configured at build time (locally via --dart-define-from-file=.env,
/// in CI from GitHub secrets):
///   GOOGLE_BACKEND_URL      the deployed function's HTTPS URL
///   GOOGLE_BACKEND_API_KEY  must match the function's BACKEND_API_KEY
class GoogleTranslationService implements SubtitleTranslator {
  static const _backendUrl = String.fromEnvironment('GOOGLE_BACKEND_URL');
  static const _apiKey = String.fromEnvironment('GOOGLE_BACKEND_API_KEY');

  /// Smaller than Claude's cap: Cloud Functions requests are limited to
  /// 32 MB, and glasses stills run a few MB each once base64-encoded.
  static const _maxImagesPerRequest = 10;

  @override
  Future<List<SubtitlePair>> translateSession(List<Uint8List> images) async {
    if (_backendUrl.isEmpty || _apiKey.isEmpty) {
      throw TranslationException(
        'This build has no Google backend configured. For local runs, set '
        'GOOGLE_BACKEND_URL and GOOGLE_BACKEND_API_KEY in .env and pass '
        '--dart-define-from-file=.env',
      );
    }
    if (images.isEmpty) return [];

    final results = <SubtitlePair>[];
    for (var i = 0; i < images.length; i += _maxImagesPerRequest) {
      final chunk = images.sublist(
        i,
        (i + _maxImagesPerRequest > images.length)
            ? images.length
            : i + _maxImagesPerRequest,
      );
      results.addAll(await _translateChunk(chunk));
    }
    return results;
  }

  Future<List<SubtitlePair>> _translateChunk(List<Uint8List> images) async {
    final response = await http.post(
      Uri.parse(_backendUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
      },
      body: jsonEncode({
        'images': [for (final image in images) base64Encode(image)],
      }),
    );

    if (response.statusCode != 200) {
      throw TranslationException(
        'Google backend error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final pairs = decoded['pairs'] as List<dynamic>? ?? [];
    return pairs
        .whereType<Map<String, dynamic>>()
        .map(SubtitlePair.fromJson)
        .toList();
  }
}
