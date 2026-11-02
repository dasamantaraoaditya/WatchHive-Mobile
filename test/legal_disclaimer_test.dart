import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/profile/widgets/legal_disclaimer_dialog.dart';

void main() {
  group('LegalDisclaimerDialog Tests', () {
    testWidgets('renders all disclaimer sections and TMDb attribution correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => LegalDisclaimerDialog.show(context),
                child: const Text('Show Disclaimer'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Disclaimer'));
      await tester.pumpAndSettle();

      // Verify title & subtitle
      expect(find.text('Legal & Non-Commercial Disclaimer'), findsOneWidget);
      expect(find.text('Licenses, TMDb attribution & copyright notice'), findsOneWidget);

      // Verify key legal sections
      expect(find.text('1. Strict Non-Commercial Purpose'), findsOneWidget);
      expect(find.text('2. TMDb API Attribution'), findsOneWidget);
      expect(find.text('3. Intellectual Property & Copyright (IPR)'), findsOneWidget);
      expect(find.text('4. Copyright Inquiries & Takedown Policy'), findsOneWidget);

      // Verify TMDb attribution statement
      expect(
        find.textContaining('This product uses the TMDB API but is not endorsed or certified by TMDB.'),
        findsOneWidget,
      );

      // Verify Non-commercial statement
      expect(
        find.textContaining('WatchersHive does NOT generate any revenue'),
        findsOneWidget,
      );

      // Tap 'I Understand' button
      final btnFinder = find.text('I Understand');
      await tester.scrollUntilVisible(btnFinder, 200);
      expect(btnFinder, findsOneWidget);
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.text('Legal & Non-Commercial Disclaimer'), findsNothing);
    });
  });
}
