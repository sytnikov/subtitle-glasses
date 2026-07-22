import 'subtitle_pair.dart';

/// One completed watching session: when it ended and what was translated.
class SessionRecord {
  const SessionRecord({
    required this.capturedAt,
    required this.pairs,
    this.provider,
    this.elapsed,
  });

  final DateTime capturedAt;
  final List<SubtitlePair> pairs;

  /// Which translation backend produced this ("Claude" / "Google").
  /// Nullable so history saved before this field existed still loads.
  final String? provider;

  /// Wall-clock time the translation call took. Same nullability reason.
  final Duration? elapsed;

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    final elapsedMs = json['elapsedMs'] as int?;
    return SessionRecord(
      capturedAt:
          DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
          DateTime.now(),
      pairs: (json['pairs'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SubtitlePair.fromJson)
          .toList(),
      provider: json['provider'] as String?,
      elapsed: elapsedMs == null ? null : Duration(milliseconds: elapsedMs),
    );
  }

  Map<String, dynamic> toJson() => {
    'capturedAt': capturedAt.toIso8601String(),
    'pairs': [for (final pair in pairs) pair.toJson()],
    if (provider != null) 'provider': provider,
    if (elapsed != null) 'elapsedMs': elapsed!.inMilliseconds,
  };
}
