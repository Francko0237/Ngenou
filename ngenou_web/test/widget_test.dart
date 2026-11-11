import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngenou_web/main.dart';

void main() {
  testWidgets('NgenouWebApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NgenouWebApp(),
      ),
    );

    // Vérifie que l'arbre de widgets démarre sans exception
    expect(find.byType(NgenouWebApp), findsOneWidget);
  });
}
