import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/support/screens/support_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    SupportCategory initialCategory = SupportCategory.bug,
    String? prefillSubject,
    String? prefillMessage,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: SupportScreen(
          initialCategory: initialCategory,
          prefillSubject: prefillSubject,
          prefillMessage: prefillMessage,
        ),
      ),
    );
  }

  group('SupportScreen Widget Tests', () {
    testWidgets('renders all essential elements (header, email, categories, inputs, FAQ)', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Header title & email badge
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('We are here to help!'), findsOneWidget);
      expect(find.text(SupportScreen.supportEmail), findsWidgets);

      // Category chips
      expect(find.text('Bug / Glitch'), findsOneWidget);
      expect(find.text('Movie / Data Issue'), findsOneWidget);
      expect(find.text('Feature Request'), findsOneWidget);
      expect(find.text('Account & Login'), findsOneWidget);
      expect(find.text('General Feedback'), findsOneWidget);

      // Text fields
      expect(find.text('Subject'), findsOneWidget);
      expect(find.text('Description / Details'), findsOneWidget);
      expect(find.text('Your Contact Email'), findsOneWidget);

      // Buttons
      expect(find.text('Send via Email App ✉️'), findsOneWidget);
      expect(find.text('Copy Email'), findsOneWidget);
      expect(find.text('Copy Report'), findsOneWidget);

      // FAQ section
      expect(find.text('Frequently Asked Questions'), findsOneWidget);
      expect(find.text('Missing movie poster or incorrect title?'), findsOneWidget);
    });

    testWidgets('switching categories updates the selected category and placeholder', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap 'Feature Request' chip
      await tester.tap(find.text('Feature Request'));
      await tester.pumpAndSettle();

      // Check placeholder text in the description field
      expect(
        find.text(SupportCategory.feature.placeholder),
        findsOneWidget,
      );

      // Tap 'Movie / Data Issue' chip
      await tester.tap(find.text('Movie / Data Issue'));
      await tester.pumpAndSettle();

      expect(
        find.text(SupportCategory.movieData.placeholder),
        findsOneWidget,
      );
    });

    testWidgets('prefills subject and message when provided', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(
        initialCategory: SupportCategory.movieData,
        prefillSubject: 'Oppenheimer year wrong',
        prefillMessage: 'The release year shows 2024 instead of 2023',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Oppenheimer year wrong'), findsOneWidget);
      expect(find.text('The release year shows 2024 instead of 2023'), findsOneWidget);
    });

    testWidgets('taps Copy Email and copies watchershive@gmail.com to clipboard', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? copiedString;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedString = (methodCall.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Email'));
      await tester.pumpAndSettle();

      expect(copiedString, equals('watchershive@gmail.com'));
    });

    testWidgets('taps Copy Report and copies full report with diagnostics', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? copiedString;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedString = (methodCall.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(buildTestWidget(
        prefillSubject: 'Test Issue',
        prefillMessage: 'Something broke here',
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Report'));
      await tester.pumpAndSettle();

      expect(copiedString, isNotNull);
      expect(copiedString, contains('Subject: [WatchersHive] [Bug / Glitch] Test Issue'));
      expect(copiedString, contains('Something broke here'));
      expect(copiedString, contains('App Diagnostics:'));
    });

    testWidgets('FAQ ExpansionTile expands and displays answer', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially answer is not visible
      expect(find.textContaining('WatchersHive syncs movie & TV metadata with TMDB'), findsNothing);

      // Tap first FAQ
      final faqFinder = find.text('Missing movie poster or incorrect title?');
      await tester.tap(faqFinder);
      await tester.pumpAndSettle();

      // Now answer is revealed
      expect(find.textContaining('WatchersHive syncs movie & TV metadata with TMDB'), findsOneWidget);
    });
  });
}
