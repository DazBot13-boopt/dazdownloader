import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/update/update_checker.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../download/domain/media_models.dart';
import '../../download/domain/media_url_parser.dart';
import '../../download/presentation/download_controller.dart';
import '../../history/data/download_history.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final TextEditingController _urlController;
  final _history = DownloadHistory();
  List<DownloadHistoryItem> _recentDownloads = const [];
  bool _historyLoading = true;
  String? _availableUpdate;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _loadRecentDownloads();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final result = await ref.read(updateCheckerProvider).check();
    if (mounted && result.outcome == UpdateCheckOutcome.available) {
      setState(() => _availableUpdate = result.version);
    }
  }

  Future<void> _openDownloadPage() async {
    final launched = await launchUrl(
      Uri.parse(loadyDownloadPageUrl),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le lien.')),
      );
    }
  }

  void _dismissUpdate(String version) {
    ref.read(updateCheckerProvider).dismiss(version);
    setState(() => _availableUpdate = null);
  }

  Future<void> _loadRecentDownloads() async {
    try {
      final items = await _history.load();
      if (mounted) setState(() => _recentDownloads = items.take(3).toList());
    } catch (_) {
      // Keep the home screen usable when the native history is unavailable.
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _submit() {
    final rawUrl = _urlController.text.trim();
    final uri = MediaUrlParser.parse(rawUrl);
    if (uri == null) {
      // Replace the visible notification instead of queueing another one:
      // tapping the button repeatedly used to stack identical messages.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              rawUrl.isEmpty
                  ? 'Collez d’abord un lien à analyser.'
                  : 'Lien non reconnu. Utilisez un lien YouTube, TikTok, '
                        'Instagram, Snapchat, X, Facebook, Pinterest ou Threads.',
            ),
          ),
        );
      return;
    }

    context.push('/download?url=${Uri.encodeComponent(rawUrl)}');
  }

  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted || text == null || text.isEmpty) {
      return;
    }
    _urlController.text = text;
    _urlController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.listen(downloadControllerProvider, (previous, next) {
      if (next.status == DownloadStatus.completed &&
          previous?.status != DownloadStatus.completed) {
        _loadRecentDownloads();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720 ? 40.0 : 20.0;
            final columns = constraints.maxWidth >= 720 ? 6 : 4;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroHeader(theme: theme),
                      if (_availableUpdate case final version?) ...[
                        const SizedBox(height: 20),
                        _UpdateCard(
                          version: version,
                          onDownload: _openDownloadPage,
                          onLater: () => _dismissUpdate(version),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'Garder ce que vous aimez',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Détectez la plateforme, choisissez une qualité et téléchargez localement.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: 'https://…',
                          labelText: 'Lien à analyser',
                          prefixIcon: const Icon(Icons.link),
                          suffixIcon: IconButton(
                            onPressed: _pasteUrl,
                            tooltip: 'Coller le lien',
                            icon: const Icon(Icons.content_paste),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Analyser le lien'),
                      ),
                      const SizedBox(height: 34),
                      _SectionTitle(
                        title: 'Plateformes prises en charge',
                        subtitle: 'Huit univers, une même expérience.',
                      ),
                      const SizedBox(height: 14),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: MediaPlatform.values.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final platform = MediaPlatform.values[index];
                          return _PlatformCard(platform: platform);
                        },
                      ),
                      const SizedBox(height: 34),
                      _SectionTitle(
                        title: 'Derniers téléchargements',
                        subtitle: 'Les fichiers les plus récents.',
                      ),
                      const SizedBox(height: 14),
                      if (_historyLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_recentDownloads.isEmpty)
                        const _EmptyHistoryCard()
                      else ...[
                        for (final item in _recentDownloads)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              child: ListTile(
                                onTap: () => _history.open(item),
                                leading: Icon(_history.iconFor(item.mimeType)),
                                title: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${item.sizeLabel} · ${item.dateLabel}',
                                ),
                                trailing: const Icon(Icons.open_in_new_rounded),
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => context.go('/history'),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Tout l’historique'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const BrandMark(size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Loady',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Ton contenu. Ton appareil. Tes règles.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  _HeroPill(icon: Icons.lock_outline, label: 'LOCAL'),
                  SizedBox(width: 6),
                  _HeroPill(icon: Icons.bolt_outlined, label: 'RAPIDE'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.version,
    required this.onDownload,
    required this.onLater,
  });

  final String version;
  final VoidCallback onDownload;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.system_update_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Loady $version est disponible',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                'Téléchargez la nouvelle version depuis le site Loady.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  TextButton(onPressed: onLater, child: const Text('Plus tard')),
                  TextButton(
                    onPressed: onDownload,
                    child: const Text('Télécharger'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withAlpha(18),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withAlpha(45),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .7,
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.platform});

  final MediaPlatform platform;

  FaIconData get _icon => switch (platform) {
    MediaPlatform.youtube => FontAwesomeIcons.youtube,
    MediaPlatform.tiktok => FontAwesomeIcons.tiktok,
    MediaPlatform.instagram => FontAwesomeIcons.instagram,
    MediaPlatform.snapchat => FontAwesomeIcons.snapchat,
    MediaPlatform.x => FontAwesomeIcons.xTwitter,
    MediaPlatform.facebook => FontAwesomeIcons.facebookF,
    MediaPlatform.pinterest => FontAwesomeIcons.pinterest,
    MediaPlatform.threads => FontAwesomeIcons.threads,
  };

  Color _color(bool isDark) => switch (platform) {
    MediaPlatform.youtube => const Color(0xFFFF375F),
    MediaPlatform.tiktok => isDark ? Colors.white : const Color(0xFF010101),
    MediaPlatform.instagram => const Color(0xFFE1306C),
    MediaPlatform.snapchat => const Color(0xFFFFCC00),
    MediaPlatform.x => const Color(0xFF71717A),
    MediaPlatform.facebook => const Color(0xFF1877F2),
    MediaPlatform.pinterest => const Color(0xFFE60023),
    MediaPlatform.threads => isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF101010),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11151D) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? scheme.outlineVariant.withAlpha(55)
              : scheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              platform == MediaPlatform.tiktok
                  ? _TiktokMark(size: 20, isDark: isDark)
                  : FaIcon(_icon, color: _color(isDark), size: 20),
            const SizedBox(height: 6),
            // Flexible keeps the tile free of overflow stripes on the
            // narrowest phones, where a square cell leaves very little room.
            Flexible(
              child: Text(
                platform.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TikTok's mark is not one colour: the glyph is echoed in cyan and magenta
/// behind a solid copy. Stacking three icons reproduces it at any size,
/// without shipping a bitmap that would need its own dark-theme variant.
class _TiktokMark extends StatelessWidget {
  const _TiktokMark({required this.size, required this.isDark});

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final shift = size * .085;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        // The echoes sit just outside the box; clipping them would cut the
        // very effect they create.
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(-shift, -shift),
            child: FaIcon(
              FontAwesomeIcons.tiktok,
              size: size,
              color: const Color(0xFF25F4EE),
            ),
          ),
          Transform.translate(
            offset: Offset(shift, shift),
            child: FaIcon(
              FontAwesomeIcons.tiktok,
              size: size,
              color: const Color(0xFFFE2C55),
            ),
          ),
          FaIcon(
            FontAwesomeIcons.tiktok,
            size: size,
            color: isDark ? Colors.white : const Color(0xFF010101),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 34, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            'Aucun téléchargement pour le moment',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Vos fichiers enregistrés apparaîtront ici.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
