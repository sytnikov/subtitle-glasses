import 'package:flutter/material.dart';

import '../models/subtitle_pair.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.pairs,
    this.showNewSessionButton = true,
  });

  final List<SubtitlePair> pairs;

  /// Hidden when viewing a past session from history.
  final bool showNewSessionButton;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);

    return Scaffold(
      appBar: AppBar(title: const Text('Session results')),
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
