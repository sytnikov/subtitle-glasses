import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session_history_service.dart';
import 'results_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<SessionHistoryService>();

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.sessions.isEmpty
          ? const Center(child: Text('No saved sessions yet.'))
          : ListView.builder(
              itemCount: history.sessions.length,
              itemBuilder: (context, index) {
                final record = history.sessions[index];
                return Dismissible(
                  key: ObjectKey(record),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete),
                  ),
                  onDismissed: (_) =>
                      context.read<SessionHistoryService>().removeAt(index),
                  child: ListTile(
                    title: Text(_formatDate(record.capturedAt)),
                    subtitle: Text(
                      '${record.pairs.length} '
                      'phrase${record.pairs.length == 1 ? '' : 's'}'
                      '${record.provider == null ? '' : ' · ${record.provider}'}'
                      '${record.elapsed == null ? '' : ' · ${(record.elapsed!.inMilliseconds / 1000).toStringAsFixed(1)}s'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ResultsScreen(
                          pairs: record.pairs,
                          showNewSessionButton: false,
                          provider: record.provider,
                          elapsed: record.elapsed,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
