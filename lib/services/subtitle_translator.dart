import 'dart:typed_data';

import '../models/subtitle_pair.dart';

class TranslationException implements Exception {
  TranslationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A backend that turns a session's captured frames into a phrase table.
abstract interface class SubtitleTranslator {
  Future<List<SubtitlePair>> translateSession(List<Uint8List> images);
}
