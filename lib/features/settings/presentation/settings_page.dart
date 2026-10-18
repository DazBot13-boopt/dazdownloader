import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/settings/theme_mode_controller.dart';

const _devPortfolioUrl = 'https://togbedji-daziano.vercel.app/';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _openDevPortfolio(BuildContext context) async {
    final uri = Uri.parse(_devPortfolioUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le lien.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    ref.watch(themeModeProvider);
    final isDark = theme.brightness == Brightness.dark;
    final appVersion = ref.watch(_appVersionProvider);

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
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Loady'),
                  subtitle: Text(
                    appVersion.when(
                      data: (v) => 'Version $v · Android',
                      loading: () => 'Chargement…',
                      error: (_, _) => 'Version inconnue · Android',
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('Contacter les dev'),
                  subtitle: const Text(
                    'Voir le portfolio et proposer un projet.',
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openDevPortfolio(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
