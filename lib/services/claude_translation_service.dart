import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/subtitle_pair.dart';

class ClaudeTranslationException implements Exception {
  ClaudeTranslationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sends a batch of captured subtitle frames to Claude in as few requests
/// as possible and returns the extracted Finnish -> Russian phrase table.
class ClaudeTranslationService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-5';
  static const _anthropicVersion = '2023-06-01';

  /// Soft cap on images per request; larger sessions are chunked.
  static const _maxImagesPerRequest = 20;

  static const _prompt = '''
These images are consecutive frames captured from a Finnish TV show, each with a burned-in subtitle. For each frame:
- Extract the Finnish subtitle text exactly as shown.
- Skip frames with no readable subtitle.
- Merge duplicate or near-duplicate consecutive subtitles into a single entry.
- Translate each into Russian.

Respond with ONLY a JSON array, no markdown fences, no commentary, in this exact shape:
[{"finnish": "...", "russian": "..."}, ...]
in capture order. If no subtitles are found at all, respond with [].''';

  Future<List<SubtitlePair>> translateSession({
    required String apiKey,
    required List<Uint8List> images,
  }) async {
    if (images.isEmpty) return [];

    final results = <SubtitlePair>[];
    for (var i = 0; i < images.length; i += _maxImagesPerRequest) {
      final chunk = images.sublist(
        i,
        (i + _maxImagesPerRequest > images.length)
            ? images.length
            : i + _maxImagesPerRequest,
      );
      results.addAll(await _translateChunk(apiKey: apiKey, images: chunk));
    }
    return results;
  }

  Future<List<SubtitlePair>> _translateChunk({
    required String apiKey,
    required List<Uint8List> images,
  }) async {
    final content = [
      for (final image in images)
        {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': 'image/jpeg',
            'data': base64Encode(image),
          },
        },
      {'type': 'text', 'text': _prompt},
    ];

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _anthropicVersion,
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 4096,
        'thinking': {'type': 'disabled'},
        'messages': [
          {'role': 'user', 'content': content},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw ClaudeTranslationException(
        'Claude API error (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final blocks = decoded['content'] as List<dynamic>? ?? [];
    final text = blocks
        .whereType<Map<String, dynamic>>()
        .firstWhere(
          (b) => b['type'] == 'text',
          orElse: () => const {},
        )['text'] as String?;

    if (text == null) {
      throw ClaudeTranslationException('Claude returned no text content.');
    }

    return _parsePairs(text);
  }

  List<SubtitlePair> _parsePairs(String text) {
    final jsonText = _stripMarkdownFences(text).trim();
    late final List<dynamic> parsed;
    try {
      parsed = jsonDecode(jsonText) as List<dynamic>;
    } on FormatException catch (e) {
      throw ClaudeTranslationException(
        'Could not parse Claude\'s response as JSON: $e',
      );
    }
    return parsed
        .whereType<Map<String, dynamic>>()
        .map(SubtitlePair.fromJson)
        .toList();
  }

  String _stripMarkdownFences(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('```')) return trimmed;
    final withoutOpening = trimmed.replaceFirst(
      RegExp(r'^```[a-zA-Z]*\n?'),
      '',
    );
    return withoutOpening.replaceFirst(RegExp(r'```$'), '');
  }
}
