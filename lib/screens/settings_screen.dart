import 'package:flutter/material.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';
import 'package:provider/provider.dart';

import '../services/glasses_service.dart';
import '../services/translation_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
    final translationSettings = context.watch<TranslationSettingsService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Translation model',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          RadioGroup<TranslationProvider>(
            groupValue: translationSettings.provider,
            onChanged: (selected) {
              if (selected != null) {
                translationSettings.setProvider(selected);
              }
            },
            child: Column(
              children: [
                for (final provider in TranslationProvider.values)
                  RadioListTile<TranslationProvider>(
                    title: Text(provider.label),
                    value: provider,
                  ),
              ],
            ),
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
