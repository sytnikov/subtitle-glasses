import 'package:flutter/material.dart';

import '../models/subtitle_pair.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.pairs,
    this.showNewSessionButton = true,
    this.provider,
    this.elapsed,
  });

  final List<SubtitlePair> pairs;

  /// Hidden when viewing a past session from history.
  final bool showNewSessionButton;

  /// Which backend produced this translation, and how long it took —
  /// shown as a caption when available (older history entries won't have
  /// this, since it was added after the fact).
  final String? provider;
  final Duration? elapsed;

  String? get _timingCaption {
    if (provider == null && elapsed == null) return null;
    final parts = <String>[
      ?provider,
      if (elapsed != null) '${(elapsed!.inMilliseconds / 1000).toStringAsFixed(1)}s',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);
    final caption = _timingCaption;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session results'),
        bottom: caption == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    caption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
      ),
      body: pairs.isEmpty
          ? const Center(child: Text('No subtitles were recognized.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(child: Text('Finnish', style: headerStyle)),
                      const SizedBox(width: 16),
                      Expanded(child: Text('Russian', style: headerStyle)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: pairs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final pair = pairs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(pair.finnish)),
                            const SizedBox(width: 16),
                            Expanded(child: Text(pair.russian)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: showNewSessionButton
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('New session'),
                ),
              ),
            )
          : null,
    );
  }
}
