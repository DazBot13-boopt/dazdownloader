import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/media_models.dart';
import 'download_controller.dart';

class DownloadPage extends ConsumerStatefulWidget {
  const DownloadPage({super.key, this.url, this.restored = false});

  final String? url;

  /// True when the screen was reopened from a saved session instead of a link
  /// the user just submitted. The restored state is shown as it is, with a
  /// manual retry, so returning to the app never restarts the engine.
  final bool restored;

  @override
  ConsumerState<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends ConsumerState<DownloadPage> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant DownloadPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) _resolve();
  }

  void _resolve() {
    final url = widget.url;
    if (url != null && !widget.restored) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(downloadControllerProvider.notifier).resolve(url);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(downloadControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restored ? 'Dernière analyse' : 'Analyse'),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: state.preview != null
          ? _PreviewContent(key: ValueKey(state.preview), state: state)
          : state.status == DownloadStatus.idle
          ? const _NoUrlState()
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _TransferStatus(state: state),
                if (!state.isBusy && state.url != null)
                  OutlinedButton.icon(
                    onPressed: () => ref
                        .read(downloadControllerProvider.notifier)
                        .resolve(state.url.toString(), force: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer l’analyse'),
                  ),
              ],
            ),
    );
  }
}

class _NoUrlState extends StatelessWidget {
  const _NoUrlState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link_off,
              size: 54,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun lien à analyser',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Revenez à l’accueil pour coller une URL.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Retour à l’accueil'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewContent extends ConsumerStatefulWidget {
  const _PreviewContent({super.key, required this.state});
  final DownloadState state;

  @override
  ConsumerState<_PreviewContent> createState() => _PreviewContentState();
}

class _PreviewContentState extends ConsumerState<_PreviewContent> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final preview = state.preview!;
    final formats = preview.formats;
    if (formats.isEmpty) {
      return const _NoUrlState();
    }
    final selected = formats[_selectedIndex.clamp(0, formats.length - 1)];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _PreviewArtwork(thumbnailUrl: preview.thumbnailUrl),
        const SizedBox(height: 18),
        Text(
          preview.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${preview.platform.label} · ${preview.author} · ${_formatDuration(preview.duration)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          preview.sourceUrl.toString(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 26),
        Text(
          'Choisir la qualité',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < formats.length; index++)
              ChoiceChip(
                label: Text(
                  '${formats[index].qualityLabel} · ${formats[index].format.label}',
                ),
                selected: index == _selectedIndex,
                onSelected: state.isBusy
                    ? null
                    : (_) => setState(() => _selectedIndex = index),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _TransferStatus(state: state),
        FilledButton.icon(
          onPressed: state.isBusy
              ? null
              : () => _download(selected, again: state.result != null),
          icon: const Icon(Icons.download),
          label: Text(
            state.result != null ? 'Télécharger à nouveau' : 'Télécharger',
          ),
        ),
      ],
    );
  }

  /// Warns before saving a video already among the downloads in this format.
  /// Skipped for "Télécharger à nouveau": the user just saw it finish.
  Future<void> _download(MediaFormatOption format, {required bool again}) async {
    final controller = ref.read(downloadControllerProvider.notifier);
    if (!again && await controller.isAlreadyDownloaded(format)) {
      if (!mounted || !await _confirmDownloadAgain(format)) return;
    }
    await controller.download(format);
  }

  Future<bool> _confirmDownloadAgain(MediaFormatOption format) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déjà téléchargé'),
        content: Text(
          '« ${widget.state.preview?.title ?? 'Cette vidéo'} » est déjà dans vos téléchargements en '
          '${format.format.label}. Le télécharger à nouveau ?',
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Télécharger'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return 'Durée inconnue';
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _TransferStatus extends ConsumerWidget {
  const _TransferStatus({required this.state});
  final DownloadState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(downloadControllerProvider.notifier);
    final label = switch (state.status) {
      DownloadStatus.resolving => 'Analyse du lien et des formats disponibles…',
      DownloadStatus.updating => 'Redémarrage du moteur…',
      DownloadStatus.downloading => 'Téléchargement du flux…',
      DownloadStatus.processing => 'Assemblage ou conversion du média…',
      DownloadStatus.saving => 'Enregistrement du fichier…',
      DownloadStatus.cancelling => 'Annulation en cours…',
      DownloadStatus.cancelled => 'Téléchargement annulé.',
      DownloadStatus.completed => 'Téléchargement terminé',
      DownloadStatus.failed => 'Opération impossible',
      _ => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    final percent = state.status == DownloadStatus.downloading
        ? state.progress?.percent
        : null;
    final eta = state.progress?.etaSeconds;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
            semanticsLabel: label,
          ),
          if (state.isBusy) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percent == null ? null : percent / 100,
            ),
            if (percent != null)
              Text(
                '${percent.toStringAsFixed(0)} % du flux'
                '${eta != null && eta > 0 ? ' · environ ${eta}s restantes' : ''}',
              ),
            if (state.status != DownloadStatus.updating)
              TextButton.icon(
                onPressed: state.status == DownloadStatus.cancelling
                    ? null
                    : controller.cancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Annuler'),
              ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (state.diagnostic case final diagnostic?) ...[
              const SizedBox(height: 8),
              SelectableText(diagnostic),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: diagnostic));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Diagnostic copié (sans lien ni cookie).',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copier le diagnostic'),
              ),
            ],
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
              TextButton.icon(
                onPressed: controller.updateEngine,
                icon: const Icon(Icons.system_update_alt),
                label: const Text('Redémarrer le moteur et réessayer'),
              ),
          ],
          if (state.engineVersion != null)
            Text('Moteur vérifié : ${state.engineVersion}'),
          if (state.result case final result?) ...[
            Text(result.name),
            Text(
              '${(result.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} Mo'
              '${result.folder != null ? ' · ${result.folder}' : ''}',
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
                onPressed: () async {
                  try {
                    await controller.openResult();
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Ouvrir le fichier'),
              ),
          ],
        ],
      ),
    );
  }
}

class _PreviewArtwork extends StatelessWidget {
  const _PreviewArtwork({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: thumbnailUrl == null
            ? DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primary, scheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 72,
                ),
              )
            : Image.network(
                thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => DecoratedBox(
                  decoration: BoxDecoration(color: scheme.primary),
                  child: const Icon(Icons.movie_outlined, size: 64),
                ),
              ),
      ),
    );
  }
}
