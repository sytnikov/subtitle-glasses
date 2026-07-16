import 'subtitle_pair.dart';

/// One completed watching session: when it ended and what was translated.
class SessionRecord {
  const SessionRecord({required this.capturedAt, required this.pairs});

  final DateTime capturedAt;
  final List<SubtitlePair> pairs;

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      capturedAt:
          DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
          DateTime.now(),
      pairs: (json['pairs'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SubtitlePair.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'capturedAt': capturedAt.toIso8601String(),
    'pairs': [for (final pair in pairs) pair.toJson()],
  };
}
