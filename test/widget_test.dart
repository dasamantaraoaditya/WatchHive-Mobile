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
    expect(find.text('WatchHive'), findsOneWidget);
  });
}
