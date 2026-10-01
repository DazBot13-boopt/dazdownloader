import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _channel = MethodChannel('dazdownloader/media');
  List<_HistoryItem> _items = const [];
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
      final result = await _channel.invokeMethod<List<dynamic>>('history');
      final items = (result ?? const [])
          .whereType<Map>()
          .map(_HistoryItem.fromMap)
          .whereType<_HistoryItem>()
          .toList(growable: false);
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

  Future<void> _open(_HistoryItem item) async {
    try {
      await _channel.invokeMethod<void>('open', {
        'uri': item.uri,
        'mimeType': item.mimeType,
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Impossible d’ouvrir le fichier.'),
        ),
      );
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
                  'Les fichiers de Downloads/DAZDOWNLOADER apparaîtront ici.',
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
                          _iconFor(item.mimeType),
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${item.sizeLabel} · ${item.dateLabel}'),
                      trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                    ),
                  );
                },
              ),
            ),
    );
  }

  IconData _iconFor(String mime) {
    if (mime.startsWith('video/')) return Icons.movie_outlined;
    if (mime.startsWith('audio/')) return Icons.music_note_outlined;
    return Icons.image_outlined;
  }
}

class _HistoryItem {
  const _HistoryItem({
    required this.uri,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.dateAdded,
  });

  final String uri;
  final String name;
  final String mimeType;
  final int sizeBytes;
  final DateTime dateAdded;

  static _HistoryItem? fromMap(Map item) {
    final uri = item['uri'];
    final name = item['name'];
    final mime = item['mimeType'];
    final size = item['sizeBytes'];
    final date = item['dateAdded'];
    if (uri is! String ||
        name is! String ||
        mime is! String ||
        size is! num ||
        date is! num) {
      return null;
    }
    return _HistoryItem(
      uri: uri,
      name: name,
      mimeType: mime,
      sizeBytes: size.toInt(),
      dateAdded: DateTime.fromMillisecondsSinceEpoch(date.toInt()),
    );
  }

  String get sizeLabel {
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} Mo';
  }

  String get dateLabel {
    final days = DateTime.now().difference(dateAdded).inDays;
    if (days == 0) return 'Aujourd’hui';
    if (days == 1) return 'Hier';
    return '${dateAdded.day.toString().padLeft(2, '0')}/${dateAdded.month.toString().padLeft(2, '0')}/${dateAdded.year}';
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
