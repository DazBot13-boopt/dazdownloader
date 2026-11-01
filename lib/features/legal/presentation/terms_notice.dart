import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/links/site_links.dart';
import '../../../core/notifications/in_app_message.dart';
import '../../../core/settings/terms_notice_controller.dart';

/// Covers the app until the copyright notice is accepted.
///
/// It sits above the router rather than in a dialog route, so a link shared
/// to Loady on first launch cannot open a page on top of it.
class TermsNoticeGate extends ConsumerWidget {
  const TermsNoticeGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accepted = ref.watch(termsNoticeProvider);
    if (accepted) return child;
    return Stack(
      children: [
        ExcludeSemantics(child: child),
        const ModalBarrier(dismissible: false, color: Colors.black54),
        const TermsNoticeDialog(),
      ],
    );
  }
}

class TermsNoticeDialog extends ConsumerWidget {
  const TermsNoticeDialog({super.key});

  static const _rules = [
    'télécharge uniquement des contenus que tu as créés, qui sont libres de '
        'droits, ou que leur auteur t’autorise à enregistrer ;',
    'respecte les conditions d’utilisation de chaque plateforme ;',
    'n’utilise pas les fichiers pour les republier ou les vendre sans '
        'autorisation.',
  ];

  Future<void> _openTerms() async {
    final launched = await launchUrl(
      Uri.parse(termsOfUseUrl),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!launched) {
      appMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir les conditions.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Avant de commencer'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Loady te permet d’enregistrer des vidéos sur ton téléphone. '
            'Tu restes responsable de ce que tu télécharges :',
          ),
          const SizedBox(height: 12),
          for (final rule in _rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(rule)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Loady n’est lié à aucune des plateformes citées.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _openTerms,
          child: const Text('Lire les conditions'),
        ),
        FilledButton(
          onPressed: () => ref.read(termsNoticeProvider.notifier).accept(),
          child: const Text('J’ai compris'),
        ),
      ],
    );
  }
}
