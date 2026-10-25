import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../download/domain/media_url_parser.dart';
import '../../download/presentation/download_controller.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _share = MethodChannel('dazdownloader/share');
  static const _shareEvents = EventChannel('dazdownloader/share/events');
  StreamSubscription<Object?>? _subscription;
  String? _lastLink;

  @override
  void initState() {
    super.initState();
    _subscription = _shareEvents.receiveBroadcastStream().listen(
      _openSharedText,
    );
    unawaited(_readPending());
  }

  Future<void> _readPending() async {
    try {
      final text = await _share.invokeMethod<String>('pending');
      if (text != null) {
        _openSharedText(text);
      }
    } on MissingPluginException {
      // Sharing is an Android capability; web simply ignores it.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _openSharedText(Object? value) {
    if (!mounted || value is! String) return;
    final raw = value.trim();
    final match = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    ).firstMatch(raw);
    final candidate = match?.group(0)?.replaceAll(RegExp(r'[),.!?]+$'), '');
    final uri = MediaUrlParser.parse(candidate ?? raw);
    if (uri == null || uri.toString() == _lastLink) return;
    _lastLink = uri.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.push('/download?url=${Uri.encodeComponent(uri.toString())}');
      }
    });
  }

  int get _selectedIndex {
    if (widget.location.startsWith('/download')) {
      return 1;
    }
    if (widget.location.startsWith('/history')) {
      return 2;
    }
    if (widget.location.startsWith('/settings')) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final analysis = ref.watch(downloadControllerProvider);
    ref.listen(downloadControllerProvider, (previous, next) {
      if (!next.restored ||
          next.url == null ||
          widget.location == '/download') {
        return;
      }
      ref.read(downloadControllerProvider.notifier).consumeRestoreNavigation();
      // Restoring only reopens the screen on the state already in memory. The
      // marker keeps the page from relaunching an analysis the user never
      // asked for again, which is the whole point of restoring it.
      context.push(
        '/download?url=${Uri.encodeComponent(next.url.toString())}&restored=1',
      );
    });
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 1:
              context.go('/download');
            case 2:
              context.go('/history');
            case 3:
              context.go('/settings');
            default:
              context.go('/');
          }
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: analysis.isBusy
                ? const Badge(smallSize: 8, child: Icon(Icons.manage_search))
                : const Icon(Icons.manage_search),
            selectedIcon: analysis.isBusy
                ? const Badge(smallSize: 8, child: Icon(Icons.manage_search))
                : const Icon(Icons.manage_search),
            label: 'Analyse',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historique',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Réglages',
          ),
        ],
      ),
    );
  }
}
