import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/media_models.dart';
import 'download_controller.dart';

class DownloadPage extends ConsumerStatefulWidget {
  const DownloadPage({super.key, this.url});

  final String? url;

  @override
  ConsumerState<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends ConsumerState<DownloadPage> {
  @override
  void initState() {
    super.initState();
    final url = widget.url;
    if (url != null) {
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
        title: const Text('Téléchargement'),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _DownloadError(
          message: error.toString(),
          onRetry: widget.url == null
              ? null
              : () => ref
                  .read(downloadControllerProvider.notifier)
                  .resolve(widget.url!),
        ),
        data: (preview) {
          if (preview == null) {
            return const _NoUrlState();
          }
          return _PreviewContent(preview: preview);
        },
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

class _DownloadError extends StatelessWidget {
  const _DownloadError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 54, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Impossible d’analyser le lien',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewContent extends StatefulWidget {
  const _PreviewContent({required this.preview});

  final MediaPreview preview;

  @override
  State<_PreviewContent> createState() => _PreviewContentState();
}

class _PreviewContentState extends State<_PreviewContent> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = widget.preview;
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
                  '${formats[index].quality.label} · ${formats[index].format.label}',
                ),
                selected: index == _selectedIndex,
                onSelected: (_) => setState(() => _selectedIndex = index),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('Format sélectionné : ${selected.format.label}'),
            subtitle: Text(
              selected.sizeLabel.isEmpty
                  ? 'La taille sera calculée avant le téléchargement.'
                  : 'Taille estimée : ${selected.sizeLabel}',
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Le moteur natif sera branché à la prochaine étape.'),
              ),
            );
          },
          icon: const Icon(Icons.download),
          label: const Text('Télécharger'),
        ),
        const SizedBox(height: 10),
        Text(
          'Le téléchargement sera enregistré dans l’espace de l’appareil.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
