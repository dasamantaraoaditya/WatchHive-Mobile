import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/app.dart';

void main() {
  testWidgets('WatchHive App Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: WatchHiveApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.byType(WatchHiveApp), findsOneWidget);
  });
}
