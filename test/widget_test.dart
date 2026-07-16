import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:finnish_subtitles/models/session_record.dart';
import 'package:finnish_subtitles/models/subtitle_pair.dart';

void main() {
  test('SubtitlePair.fromJson parses finnish/russian fields', () {
    final pair = SubtitlePair.fromJson({
      'finnish': 'Hyvää huomenta',
      'russian': 'Доброе утро',
    });

    expect(pair.finnish, 'Hyvää huomenta');
    expect(pair.russian, 'Доброе утро');
  });

  test('SubtitlePair.fromJson defaults missing fields to empty strings', () {
    final pair = SubtitlePair.fromJson({});

    expect(pair.finnish, '');
    expect(pair.russian, '');
  });

  test('SessionRecord survives a JSON round-trip', () {
    final record = SessionRecord(
      capturedAt: DateTime.parse('2026-07-15T14:56:00'),
      pairs: const [
        SubtitlePair(finnish: 'Ehkä mun alter ego on poliisi.', russian: 'Может, моё альтер эго — полицейский.'),
        SubtitlePair(finnish: 'No, nousiko sen pisteet?', russian: 'Ну что, поднялись его баллы?'),
      ],
    );

    final restored = SessionRecord.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
    );

    expect(restored.capturedAt, record.capturedAt);
    expect(restored.pairs.length, 2);
    expect(restored.pairs.first.finnish, record.pairs.first.finnish);
    expect(restored.pairs.last.russian, record.pairs.last.russian);
  });

  test('SessionRecord.fromJson tolerates malformed input', () {
    final record = SessionRecord.fromJson({'capturedAt': 'garbage'});

    expect(record.pairs, isEmpty);
    // Falls back to "now" rather than throwing.
    expect(record.capturedAt.difference(DateTime.now()).inSeconds.abs() < 5, isTrue);
  });
}
