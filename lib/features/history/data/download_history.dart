import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DownloadHistory {
  static const channel = MethodChannel('dazdownloader/media');

  Future<List<DownloadHistoryItem>> load() async {
    final result = await channel.invokeMethod<List<dynamic>>('history');
    return (result ?? const [])
        .whereType<Map>()
        .map(DownloadHistoryItem.fromMap)
        .whereType<DownloadHistoryItem>()
        .toList(growable: false);
  }

  Future<void> open(DownloadHistoryItem item) async {
    await channel.invokeMethod<void>('open', {
      'uri': item.uri,
      'mimeType': item.mimeType,
    });
  }

  IconData iconFor(String mime) {
    if (mime.startsWith('video/')) return Icons.movie_outlined;
    if (mime.startsWith('audio/')) return Icons.music_note_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

class DownloadHistoryItem {
  const DownloadHistoryItem({
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

  static DownloadHistoryItem? fromMap(Map item) {
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
    return DownloadHistoryItem(
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
