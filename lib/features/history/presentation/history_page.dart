import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/download_history.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _history = DownloadHistory();
  List<DownloadHistoryItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _history.load();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PlatformException
              ? error.message ?? 'Historique indisponible.'
              : 'L’historique est disponible dans l’application Android.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(DownloadHistoryItem item) async {
    try {
      await _history.open(item);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’ouvrir le fichier : $error')),
      );
    }
  }

  /// Deleting removes the file itself, so the two choices must both look like
  /// buttons and the destructive one must stand out: cancel on the left,
  /// delete in the error colour on the right.
  Future<bool> _confirmDeletion({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
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
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _delete(DownloadHistoryItem item) async {
    final confirmed = await _confirmDeletion(
      title: 'Supprimer de l’appareil ?',
      message: '« ${item.name} » sera supprimé de l’appareil.',
      confirmLabel: 'Supprimer',
    );
    if (!confirmed) return;
    try {
      final deleted = await DownloadHistory.channel.invokeMethod<bool>(
        'deleteHistoryItem',
        {'uri': item.uri},
      );
      await _load();
      if (deleted != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ce fichier n’a pas pu être supprimé. Il a peut-être été déplacé '
              'ou créé par une autre application.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suppression impossible : $error')),
        );
      }
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await _confirmDeletion(
      title: 'Tout supprimer de l’appareil ?',
      message:
          'Tous les fichiers téléchargés par Loady seront supprimés de l’appareil.',
      confirmLabel: 'Tout supprimer',
    );
    if (!confirmed) return;
    try {
      final total = _items.length;
      final deleted =
          await DownloadHistory.channel.invokeMethod<int>('deleteAllHistory') ??
          0;
      await _load();
      if (deleted < total && mounted) {
        final remaining = total - deleted;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remaining == 1
                  ? '1 fichier n’a pas pu être supprimé.'
                  : '$remaining fichiers n’ont pas pu être supprimés.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suppression impossible : $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
          // Two bare icons side by side gave no way to tell them apart, and
          // the destructive one sat next to a harmless refresh. The menu
          // spells out what it does before it is tapped.
          if (_items.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Plus d’options',
              onSelected: (value) {
                if (value == 'delete-all') _deleteAll();
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'delete-all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined),
                      SizedBox(width: 12),
                      Text('Supprimer tout l’historique'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _MessageState(
              icon: Icons.error_outline,
              title: _error!,
              onPressed: _load,
            )
          : _items.isEmpty
          ? _MessageState(
              icon: Icons.folder_open_outlined,
              title: 'Aucun téléchargement',
              subtitle:
                  'Les fichiers téléchargés par Loady apparaîtront ici.',
              onPressed: () => context.go('/'),
              buttonLabel: 'Analyser un lien',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Card(
                    child: ListTile(
                      onTap: () => _open(item),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withAlpha(
                          24,
                        ),
                        child: Icon(
                          _history.iconFor(item.mimeType),
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${item.sizeLabel} · ${item.dateLabel}'),
                      trailing: IconButton(
                        onPressed: () => _delete(item),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Supprimer',
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onPressed,
    this.buttonLabel = 'Réessayer',
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onPressed;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 58, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, textAlign: TextAlign.center),
          ],
          if (onPressed != null) ...[
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh),
              label: Text(buttonLabel),
            ),
          ],
        ],
      ),
    ),
  );
}
