import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:provider/provider.dart';

import '../models/session_record.dart';
import '../services/claude_translation_service.dart';
import '../services/glasses_service.dart';
import '../services/secure_storage_service.dart';
import '../services/session_history_service.dart';
import 'history_screen.dart';
import 'results_screen.dart';
import 'settings_screen.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  bool _busy = false;
  StreamSubscription<String>? _streamErrorSub;

  @override
  void initState() {
    super.initState();
    // Surface SDK-initiated stream deaths (glasses folded, overheated,
    // disconnected) — otherwise the camera just goes dark silently.
    _streamErrorSub = context.read<GlassesService>().streamErrors.listen(
      _showError,
    );
  }

  @override
  void dispose() {
    _streamErrorSub?.cancel();
    super.dispose();
  }

  Future<void> _runGuarded(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on DatError catch (e) {
      _showError(_friendlyDatError(e));
    } on ClaudeTranslationException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyDatError(DatError e) {
    if (e is DeviceSessionError) {
      if (e.isNoEligibleDevice) {
        return 'Glasses not ready. Make sure they are unfolded, connected, '
            'and on your face, then try again.';
      }
      if (e.isSessionAlreadyExists) {
        return 'A previous session was still open and has been cleaned up. '
            'Please try again.';
      }
    }
    return e.message;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _connect() => _runGuarded(() {
    return context.read<GlassesService>().connect();
  });

  Future<void> _grantCameraPermission() => _runGuarded(() {
    return context.read<GlassesService>().ensureCameraPermission();
  });

  Future<void> _startSession() => _runGuarded(() {
    return context.read<GlassesService>().startSession();
  });

  Future<void> _resumeSession() => _runGuarded(() {
    return context.read<GlassesService>().resumeSession();
  });

  Future<void> _capture() => _runGuarded(() {
    return context.read<GlassesService>().capture();
  });

  Future<void> _stopAndTranslate() => _runGuarded(() async {
    final glasses = context.read<GlassesService>();
    final storage = context.read<SecureStorageService>();
    final translator = context.read<ClaudeTranslationService>();
    final history = context.read<SessionHistoryService>();

    final apiKey = await storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      await glasses.stopSession();
      _showError('Set your Anthropic API key in Settings first.');
      return;
    }

    final images = await glasses.stopSession();
    final pairs = await translator.translateSession(
      apiKey: apiKey,
      images: images,
    );

    // Translation succeeded — release the captures so the watch screen
    // offers a fresh "Start session" instead of "Session interrupted".
    // (On failure they're kept, so translating can be retried.)
    glasses.clearCaptures();

    if (pairs.isNotEmpty) {
      await history.add(
        SessionRecord(capturedAt: DateTime.now(), pairs: pairs),
      );
    }

    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ResultsScreen(pairs: pairs)));
  });

  @override
  Widget build(BuildContext context) {
    final glasses = context.watch<GlassesService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finnish Subtitles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Center(child: _buildBody(glasses)),
    );
  }

  Widget _buildBody(GlassesService glasses) {
    if (_busy) {
      return const CircularProgressIndicator();
    }

    switch (glasses.registrationState) {
      case RegistrationState.unavailable:
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Meta AI app not found, or Developer Mode is disabled. '
            'Install Meta AI and enable Developer Mode in its settings, '
            'then reopen this app.',
            textAlign: TextAlign.center,
          ),
        );
      case RegistrationState.available:
        return FilledButton(
          onPressed: _connect,
          child: const Text('Connect to Meta AI'),
        );
      case RegistrationState.registering:
        return const Text('Connecting…');
      case RegistrationState.registered:
        return _buildConnectedBody(glasses);
    }
  }

  Widget _buildConnectedBody(GlassesService glasses) {
    if (!glasses.cameraPermissionGranted) {
      return FilledButton(
        onPressed: _grantCameraPermission,
        child: const Text('Grant camera permission'),
      );
    }

    if (glasses.sessionInterrupted) {
      // The SDK stopped the stream mid-session but captures are still in
      // hand — let the user pick up where they left off or cash out.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Session interrupted',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text('${glasses.capturedImages.length} captures kept'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _resumeSession,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume capturing'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _stopAndTranslate,
            child: const Text('Translate what I have'),
          ),
        ],
      );
    }

    if (!glasses.sessionActive) {
      return FilledButton(
        onPressed: _startSession,
        child: const Text('Start session'),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Captured: ${glasses.capturedImages.length}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _capture,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Capture subtitle'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: glasses.capturedImages.isEmpty ? null : _stopAndTranslate,
          child: const Text('Stop & translate'),
        ),
      ],
    );
  }
}
