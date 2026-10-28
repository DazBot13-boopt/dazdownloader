import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/settings/theme_mode_controller.dart';
import '../../../core/update/update_checker.dart';
import '../../../core/widgets/brand_mark.dart';

// Every About link points at the Loady site. Anchors for now: the site is
// a single page, and a /path would 404 until it gains real pages.
const _teamUrl = 'https://loady-site.vercel.app/#equipe';
const _privacyPolicyUrl = 'https://loady-site.vercel.app/#confidentialite';

final _appVersionProvider = FutureProvider<String>((ref) async {
  // Only the version name: the build number Android reports differs per APK
  // architecture (2037 for arm64), which means nothing to the user.
  return (await PackageInfo.fromPlatform()).version;
});

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const _channel = MethodChannel('dazdownloader/media');
  String _locationName = 'Downloads/Loady';
  bool _customLocation = false;
  bool _checkingUpdate = false;

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
        _locationName = location['name'] ?? 'Downloads/Loady';
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
        _locationName = 'Downloads/Loady';
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

  Future<void> _openTeamPage(BuildContext context) async {
    final uri = Uri.parse(_teamUrl);
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

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    final result = await ref.read(updateCheckerProvider).check(force: true);
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      switch (result.outcome) {
        UpdateCheckOutcome.available => SnackBar(
          content: Text('Loady ${result.version} est disponible.'),
          action: SnackBarAction(
            label: 'Télécharger',
            onPressed: _downloadUpdate,
          ),
        ),
        UpdateCheckOutcome.upToDate => const SnackBar(
          content: Text('Loady est à jour.'),
        ),
        UpdateCheckOutcome.failed => const SnackBar(
          content: Text(
            'Vérification impossible. Vérifiez votre connexion et réessayez.',
          ),
        ),
        UpdateCheckOutcome.unsupported => const SnackBar(
          content: Text('Disponible dans l’application Android.'),
        ),
      },
    );
  }

  Future<void> _downloadUpdate() async {
    final launched = await launchUrl(
      updateDownloadUri(),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le lien.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.palette_outlined),
                          const SizedBox(width: 16),
                          Text('Thème', style: theme.textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // A switch could only say on or off. "Système" is the
                      // choice the old subtitle described and the app never
                      // offered.
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        // Equal segments across the whole card width.
                        expandedInsets: EdgeInsets.zero,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('Clair'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('Sombre'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_outlined),
                            label: Text('Système'),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (selection) => ref
                            .read(themeModeProvider.notifier)
                            .setMode(selection.first),
                      ),
                    ],
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
                  leading: const BrandMark(size: 30),
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
                  leading: const Icon(Icons.system_update_outlined),
                  title: const Text('Rechercher une mise à jour'),
                  trailing: _checkingUpdate
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _checkForUpdate,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Politique de confidentialité'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: _openPrivacyPolicy,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.work_outline_rounded),
                  title: const Text('L’équipe Loady'),
                  subtitle: const Text(
                    'Découvrir qui développe l’application.',
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _openTeamPage(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
