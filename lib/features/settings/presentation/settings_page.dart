import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/theme_mode_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    ref.watch(themeModeProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Préférences',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Mode sombre'),
                  subtitle: const Text(
                    'Adapter l’interface à votre environnement.',
                  ),
                  trailing: Switch(
                    value: isDark,
                    onChanged: (value) =>
                        ref.read(themeModeProvider.notifier).setDarkMode(value),
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('Emplacement'),
                  subtitle: Text('Downloads · Android'),
                  trailing: Icon(Icons.chevron_right),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.high_quality_outlined),
                  title: Text('Qualité par défaut'),
                  subtitle: Text('1080p'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'À propos',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Loady'),
              subtitle: Text('Version 1.5.0 · Android'),
            ),
          ),
        ],
      ),
    );
  }
}
