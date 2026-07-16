/// One extracted Finnish subtitle phrase and its translation.
class SubtitlePair {
  const SubtitlePair({required this.finnish, required this.russian});

  final String finnish;
  final String russian;

  factory SubtitlePair.fromJson(Map<String, dynamic> json) {
    return SubtitlePair(
      finnish: json['finnish'] as String? ?? '',
      russian: json['russian'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'finnish': finnish, 'russian': russian};
}
