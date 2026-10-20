import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/settings/theme_mode_controller.dart';

const _devPortfolioUrl = 'https://togbedji-daziano.vercel.app/';
const _privacyPolicyUrl = 'https://loady-site.vercel.app/#confidentialite';

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const _channel = MethodChannel('dazdownloader/media');
  String _locationName = 'Downloads/DAZDOWNLOADER';
  bool _customLocation = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final location = await _channel.invokeMapMethod<String, String>(
        'getDownloadLocation',
      );
      if (!mounted || location == null) return;
      setState(() {
        _locationName = location['name'] ?? 'Downloads/DAZDOWNLOADER';
        _customLocation = (location['uri'] ?? '').isNotEmpty;
      });
    } catch (_) {
      // The default destination remains available on older app installations.
    }
  }

  Future<void> _chooseLocation() async {
    try {
      final location = await _channel.invokeMapMethod<String, String>(
        'chooseDownloadLocation',
      );
      if (!mounted || location == null) return;
      setState(() {
        _locationName = location['name'] ?? 'Dossier choisi';
        _customLocation = (location['uri'] ?? '').isNotEmpty;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Sélection impossible.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélection de dossier indisponible.')),
      );
    }
  }

  Future<void> _resetLocation() async {
    try {
      await _channel.invokeMethod<Map>('resetDownloadLocation');
      if (!mounted) return;
      setState(() {
        _locationName = 'Downloads/DAZDOWNLOADER';
        _customLocation = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Modification impossible.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modification de dossier indisponible.')),
      );
    }
  }

  Future<void> _openDevPortfolio(BuildContext context) async {
    final uri = Uri.parse(_devPortfolioUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le lien.')),
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final launched = await launchUrl(
      Uri.parse(_privacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir la politique.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Emplacement de téléchargement'),
                  subtitle: Text(_locationName),
                  onTap: _chooseLocation,
                  trailing: _customLocation
                      ? IconButton(
                          tooltip: 'Rétablir le dossier Loady',
                          onPressed: _resetLocation,
                          icon: const Icon(Icons.settings_backup_restore),
                        )
                      : const Icon(Icons.chevron_right),
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
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Politique de confidentialité'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: _openPrivacyPolicy,
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
