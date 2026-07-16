import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_record.dart';

/// Persists the most recent sessions on the device.
class SessionHistoryService extends ChangeNotifier {
  static const _storageKey = 'session_history';
  static const _maxSessions = 10;

  /// Newest first.
  final List<SessionRecord> sessions = [];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      sessions
        ..clear()
        ..addAll(
          decoded
              .whereType<Map<String, dynamic>>()
              .map(SessionRecord.fromJson),
        );
      notifyListeners();
    } on FormatException {
      // Corrupt history is not worth crashing over — start fresh.
      await prefs.remove(_storageKey);
    }
  }

  Future<void> add(SessionRecord record) async {
    sessions.insert(0, record);
    if (sessions.length > _maxSessions) {
      sessions.removeRange(_maxSessions, sessions.length);
    }
    notifyListeners();
    await _save();
  }

  Future<void> removeAt(int index) async {
    sessions.removeAt(index);
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode([for (final record in sessions) record.toJson()]),
    );
  }
}
