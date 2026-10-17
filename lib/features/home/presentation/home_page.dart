import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../download/domain/media_models.dart';
import '../../download/domain/media_url_parser.dart';
import '../../../core/widgets/brand_mark.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Collez un lien YouTube, TikTok, Instagram, Snapchat, X, Facebook, Pinterest ou Threads.',
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

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720 ? 40.0 : 20.0;
            final columns = 3;

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
                          hintText: 'https://www.youtube.com/watch?v=…',
                          labelText: 'URL de la vidéo ou des photos TikTok',
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
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.35,
                        ),
                        itemBuilder: (context, index) {
                          final platform = MediaPlatform.values[index];
                          return _PlatformCard(
                            platform: platform,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Collez un lien ${platform.label} dans le champ ci-dessus.',
                                  ),
                                ),
                              );
                              _urlController.clear();
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 34),
                      _SectionTitle(
                        title: 'Derniers téléchargements',
                        subtitle: 'Votre historique local apparaîtra ici.',
                      ),
                      const SizedBox(height: 14),
                      const _EmptyHistoryCard(),
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
  const _PlatformCard({required this.platform, required this.onTap});

  final MediaPlatform platform;
  final VoidCallback onTap;

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

  Color get _color => switch (platform) {
    MediaPlatform.youtube => const Color(0xFFFF375F),
    MediaPlatform.tiktok => const Color(0xFF00C7BE),
    MediaPlatform.instagram => const Color(0xFFE1306C),
    MediaPlatform.snapchat => const Color(0xFFFFCC00),
    MediaPlatform.x => const Color(0xFF71717A),
    MediaPlatform.facebook => const Color(0xFF1877F2),
    MediaPlatform.pinterest => const Color(0xFFE60023),
    MediaPlatform.threads => const Color(0xFF101010),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11151D) : Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isDark
              ? scheme.outlineVariant.withAlpha(55)
              : scheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
            child: Row(
              children: [
                FaIcon(_icon, color: _color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    platform.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
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
            'Vos fichiers resteront sur cet appareil.',
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
