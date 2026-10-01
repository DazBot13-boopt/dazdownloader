import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dazdownloader/app.dart';

void main() {
  testWidgets('renders the home experience', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DazDownloaderApp()));
    await tester.pumpAndSettle();

    expect(find.text('Loady'), findsOneWidget);
    expect(find.text('Analyser le lien'), findsOneWidget);
    expect(find.text('Plateformes prises en charge'), findsOneWidget);
  });
}
