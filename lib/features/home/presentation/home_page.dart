import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/brand_mark.dart';
import '../../download/domain/media_models.dart';
import '../../download/domain/media_url_parser.dart';

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
    if (!mounted || text == null || text.isEmpty) return;
    _urlController.text = text;
    _urlController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= 900 ? 40.0 : width >= 600 ? 28.0 : 18.0;
    final columns = width >= 900 ? 3 : 2;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 18, horizontalPadding, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BrandHeader(theme: theme),
                  const SizedBox(height: 26),
                  _DownloadHero(
                    controller: _urlController,
                    onPaste: _pasteUrl,
                    onSubmit: _submit,
                  ),
                  const SizedBox(height: 30),
                  _SectionHeading(
                    eyebrow: 'TOUT AU MÊME ENDROIT',
                    title: 'Vos plateformes préférées',
                    subtitle: 'Un lien suffit. Loady s’occupe du reste.',
                    trailing: '06',
                  ),
                  const SizedBox(height: 15),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: MediaPlatform.values.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 11,
                      mainAxisSpacing: 11,
                      mainAxisExtent: 66,
                    ),
                    itemBuilder: (context, index) {
                      final platform = MediaPlatform.values[index];
                      return _PlatformCard(
                        platform: platform,
                        onTap: () {
                          _urlController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Collez un lien ${platform.label} dans le champ ci-dessus.',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  _SectionHeading(
                    eyebrow: 'VOTRE ESPACE',
                    title: 'Récemment téléchargés',
                    subtitle: 'Vos fichiers restent sur cet appareil.',
                    trailing: null,
                  ),
                  const SizedBox(height: 15),
                  const _EmptyHistoryCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        const BrandMark(size: 42),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LOADY',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.15,
              ),
            ),
            Text(
              'VOTRE MÉDIA, VOTRE ESPACE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(110)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'PRIVÉ',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DownloadHero extends StatelessWidget {
  const _DownloadHero({
    required this.controller,
    required this.onPaste,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onPaste;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFF6F8FF) : const Color(0xFF111827);
    final subInk = isDark ? const Color(0xFFC5D2ED) : const Color(0xFF56657D);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1A2744), Color(0xFF101827), Color(0xFF111722)]
              : const [Color(0xFFEAF1FF), Color(0xFFF4F7FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withAlpha(isDark ? 65 : 36)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withAlpha(isDark ? 18 : 16),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primary.withAlpha(isDark ? 38 : 22),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 13, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  'SIMPLE · RAPIDE · LOCAL',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .85,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Gardez ce que\nvous aimez.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: ink,
              height: 1.02,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Collez un lien public et enregistrez votre média directement sur cet appareil.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: subInk,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1421) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant.withAlpha(125)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 20 : 8),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: 'Collez l’URL de votre média…',
                hintStyle: TextStyle(color: subInk.withAlpha(180)),
                prefixIcon: Icon(Icons.link_rounded, color: scheme.primary),
                suffixIcon: IconButton(
                  onPressed: onPaste,
                  tooltip: 'Coller le lien',
                  icon: Icon(Icons.content_paste_rounded, color: subInk),
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 17),
              ),
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.arrow_forward_rounded, size: 19),
              label: const Text('Analyser le lien'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: scheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: subInk),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Aucun compte. Aucun cloud. Vos fichiers restent chez vous.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: subInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.45,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              trailing!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
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
  };

  Color get _color => switch (platform) {
    MediaPlatform.youtube => const Color(0xFFFF375F),
    MediaPlatform.tiktok => const Color(0xFF00B8A9),
    MediaPlatform.instagram => const Color(0xFFE1306C),
    MediaPlatform.snapchat => const Color(0xFFF0B900),
    MediaPlatform.x => const Color(0xFF71717A),
    MediaPlatform.facebook => const Color(0xFF1877F2),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _color.withAlpha(20),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: FaIcon(_icon, color: _color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  platform.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_outward_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(175),
              ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(100)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(18),
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.history_rounded, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Votre bibliothèque commence ici',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vos derniers fichiers apparaîtront dans cet espace.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
