import 'package:flutter/material.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:provider/provider.dart';

import '../services/glasses_service.dart';
import '../services/secure_storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _loading = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final storage = context.read<SecureStorageService>();
    final key = await storage.getApiKey();
    if (!mounted) return;
    setState(() {
      _apiKeyController.text = key ?? '';
      _loading = false;
    });
  }

  Future<void> _saveApiKey() async {
    final storage = context.read<SecureStorageService>();
    await storage.setApiKey(_apiKeyController.text.trim());
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('API key saved')));
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _unpair(GlassesService glasses) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair glasses?'),
        content: const Text(
          'This unregisters the app from your glasses. Any session in '
          'progress is stopped, and you will need to reconnect through '
          'Meta AI before the next use.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await glasses.unpair();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Glasses unpaired')));
    } on DatError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String _registrationLabel(RegistrationState state) {
    switch (state) {
      case RegistrationState.unavailable:
        return 'Meta AI not available (install it and enable Developer Mode)';
      case RegistrationState.available:
        return 'Not connected';
      case RegistrationState.registering:
        return 'Connecting…';
      case RegistrationState.registered:
        return 'Connected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final glasses = context.watch<GlassesService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Anthropic API key',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'sk-ant-...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _saved = false),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saved ? null : _saveApiKey,
                  child: Text(_saved ? 'Saved' : 'Save'),
                ),
                const Divider(height: 48),
                const Text(
                  'Glasses connection',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_registrationLabel(glasses.registrationState)),
                const SizedBox(height: 8),
                Text(
                  'Camera permission: '
                  '${glasses.cameraPermissionGranted ? "granted" : "not granted"}',
                ),
                const SizedBox(height: 16),
                if (glasses.registrationState == RegistrationState.registered)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => _unpair(glasses),
                    child: const Text('Unpair glasses'),
                  ),
              ],
            ),
    );
  }
}
