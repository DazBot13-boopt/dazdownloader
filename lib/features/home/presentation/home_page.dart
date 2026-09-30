import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            'Collez un lien YouTube, TikTok, Instagram, Snapchat, X ou Facebook.',
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
            final columns = constraints.maxWidth >= 760
                ? 3
                : constraints.maxWidth >= 480
                ? 2
                : 1;

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
                        'Nouveau téléchargement',
                        style: theme.textTheme.headlineSmall?.copyWith(
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
                        subtitle: 'Six univers, une même expérience.',
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
                          childAspectRatio: columns == 1 ? 3.4 : 2.3,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(38),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const BrandMark(size: 52),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAZDOWNLOADER',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ton contenu. Ton appareil. Tes règles.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withAlpha(220),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

  IconData get _icon => switch (platform) {
    MediaPlatform.youtube => Icons.play_circle_outline,
    MediaPlatform.tiktok => Icons.music_note,
    MediaPlatform.instagram => Icons.photo_camera_outlined,
    MediaPlatform.snapchat => Icons.chat_bubble_outline,
    MediaPlatform.x => Icons.close,
    MediaPlatform.facebook => Icons.public,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  platform.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
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
